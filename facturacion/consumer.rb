require 'sinatra'
require 'sinatra/cross_origin'
require 'bunny'
require 'json'
require 'pg'
require 'thread'

set :bind, '0.0.0.0'
set :port, 5000  

# Habilitar CORS
configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
end

options '*' do
  200
end

mutex = Mutex.new

# Función para conectar a PostgreSQL
def connect_db
  begin
    PG.connect(
      host: 'postgres_db',
      port: 5432,
      dbname: 'tienda_db',
      user: 'user',
      password: 'password'
    )
  rescue PG::Error => e
    puts "[ERROR] No se pudo conectar a la base de datos: #{e.message}"
    nil
  end
end

# Función para conectar a RabbitMQ
def connect_to_rabbitmq
  loop do
    begin
      puts "[INFO] Conectando a RabbitMQ..."
      connection = Bunny.new(hostname: 'rabbitmq', automatically_recover: true)
      connection.start
      puts "[INFO] Conectado a RabbitMQ."
      return connection
    rescue Bunny::TCPConnectionFailed => e
      puts "[ERROR] Fallo de conexión a RabbitMQ: #{e.message}. Intentando reconectar en 5 segundos..."
      sleep 5
    end
  end
end

connection = connect_to_rabbitmq
channel = connection.create_channel

# Declarar la cola de pedidos
queue_pedidos = channel.queue('pedidos', durable: true)
exchange = channel.direct('pedido_exchange', durable: true)
queue_pedidos.bind(exchange, routing_key: 'procesar_pedido')

# Declarar el intercambio de notificaciones
exchange_notificaciones = channel.fanout('notificaciones', durable: true)

# Declarar el intercambio de reportes
exchange_reportes = channel.fanout('reportes_exchange', durable: true)
queue_reportes = channel.queue('reportes', durable: true)
queue_reportes.bind(exchange_reportes)

puts "[INFO] Esperando mensajes en la cola 'pedidos'..."
queue_pedidos.subscribe(block: false, manual_ack: true) do |delivery_info, properties, body|
  begin
    puts "[INFO] Mensaje recibido: #{body}"
    pedido = JSON.parse(body)
    puts "[INFO] Mensaje recibido:\n#{JSON.pretty_generate(pedido)}"

    # Métodos de pago permitidos
    METODOS_PAGO_VALIDOS = ["deposito", "transferencia", "yape", "plin"]

    # Validaciones de los campos obligatorios
    campos_obligatorios = %w[codigo codigo_usuario nombre_usuario email celular precio_total productos metodo_pago direccion_entrega fecha_pedido]
    if campos_obligatorios.any? { |campo| pedido[campo].to_s.strip.empty? } ||
       pedido['precio_total'].to_f <= 0 ||
       !pedido['productos'].is_a?(Array) || pedido['productos'].empty?

      raise "Error: Datos del pedido incompletos o inválidos"
    end

    # Validaciones adicionales
    raise "Error: El email ingresado no es válido" unless pedido['email'].match?(/\A[^@\s]+@[^@\s]+\z/)
    raise "Error: El número de celular debe tener al menos 9 dígitos" unless pedido['celular'].match?(/\A\d{9,}\z/)
    raise "Error: Método de pago inválido" unless METODOS_PAGO_VALIDOS.include?(pedido['metodo_pago'].to_s.downcase)

    # Valores predeterminados
    pedido['boucher_path'] = pedido['boucher_path'].to_s.strip.empty? ? 'No disponible' : pedido['boucher_path']
    pedido['estado'] = pedido['estado'].to_s.strip.empty? ? 'pendiente' : pedido['estado']

    puts "[INFO] Pedido validado correctamente: #{pedido.inspect}"

    mutex.synchronize do
      db = connect_db
      begin
        db.transaction do
          # Obtener usuario_id
          usuario_id_result = db.exec_params("SELECT id FROM usuarios WHERE codigo = $1", [pedido['codigo_usuario']]).first
          raise "Error: Usuario con código #{pedido['codigo_usuario']} no encontrado" if usuario_id_result.nil?

          usuario_id = usuario_id_result['id']

          # Insertar pedido en PostgreSQL
          result = db.exec_params(
            "INSERT INTO pedidos (codigo, usuario_id, fecha_pedido, precio_total, estado, metodo_pago, direccion_entrega, boucher_path) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8) 
             RETURNING id",
            [
              pedido['codigo'],
              usuario_id,
              pedido['fecha_pedido'],
              pedido['precio_total'],
              pedido['estado'],
              pedido['metodo_pago'],
              pedido['direccion_entrega'],
              pedido['boucher_path']
            ]
          )

          pedido_id = result[0]['id']
          raise "Error al obtener el ID del pedido" if pedido_id.nil?

          puts "[INFO] Pedido insertado con ID: #{pedido_id}"

          # Insertar detalles del pedido
          pedido['productos'].each do |producto|
            producto_id_result = db.exec_params("SELECT id FROM productos WHERE codigo = $1", [producto['codigo_producto']]).first
          
            if producto_id_result.nil?
              puts "[ERROR] Producto con código #{producto['codigo_producto']} no existe en la base de datos. Omitiendo."
              next
            end
          
            producto_id = producto_id_result['id']
          
            db.exec_params(
              "INSERT INTO detalles_pedido (pedido_id, producto_id, cantidad, precio_unitario, precio_total) 
               VALUES ($1, $2, $3, $4, $5)",
              [
                pedido_id,
                producto_id,
                producto['cantidad'].to_i,
                producto['precio_unitario'].to_f,
                producto['precio_total'].to_f
              ]
            )
          
            puts "[INFO] Insertado detalle de pedido: Pedido ID #{pedido_id}, Producto ID #{producto_id}, Cantidad #{producto['cantidad']}, Precio Unitario #{producto['precio_unitario']}, Precio Total #{producto['precio_total']}"
          end

          puts "[INFO] Detalles del pedido insertados correctamente"
        end # Fin de la transacción
      rescue PG::Error => e
        puts "[ERROR] Error en la base de datos: #{e.message}"
        channel.reject(delivery_info.delivery_tag, false)
      ensure
        db.close if db
      end
    end

    puts "[INFO] Pedido guardado en la base de datos con éxito."
    channel.ack(delivery_info.delivery_tag)

  rescue JSON::ParserError => e
    puts "[ERROR] No se pudo procesar el pedido: #{e.message}"
    channel.reject(delivery_info.delivery_tag, false)
  rescue => e
    puts "[ERROR] Error inesperado: #{e.message}"
    channel.reject(delivery_info.delivery_tag, false)
  end
end

# Endpoint para obtener todos los pedidos
get '/pedidos' do
  content_type :json
  begin
    db = connect_db
    pedidos = db.exec(<<-SQL).map { |row| row.transform_keys(&:to_sym) }
        SELECT p.*, 
              TO_CHAR(p.fecha_pedido, 'YYYY-MM-DD') AS fecha_pedido, 
              u.nombre AS nombre_usuario, 
              u.email AS email_usuario
        FROM pedidos p
        JOIN usuarios u ON p.usuario_id = u.id;
    SQL

    pedidos.to_json
  rescue PG::Error => e
    status 500
    { error: "Error al obtener los pedidos: #{e.message}" }.to_json
  ensure
    db.close if db
  end
end


# Endpoint para obtener los productos de un pedido
get '/detalles_pedido/:codigo' do
  content_type :json
  begin
    db = connect_db

    # Verificar si el pedido existe
    pedido_existente = db.exec_params("SELECT id FROM pedidos WHERE codigo = $1", [params[:codigo]]).first
    unless pedido_existente
      status 404
      return { error: "Pedido no encontrado" }.to_json
    end
    
    # Obtener los productos del pedido
    productos = db.exec_params("SELECT p.codigo, p.nombre, d.precio_unitario, d.cantidad, d.precio_total
                                FROM detalles_pedido d
                                JOIN productos p ON d.producto_id = p.id
                                WHERE d.pedido_id = $1", [pedido_existente['id']])

    productos_result = productos.map { |row| row.transform_keys(&:to_sym) }
    productos_result.to_json

  rescue PG::Error => e
    status 500
    { error: "Error al obtener los productos del pedido: #{e.message}" }.to_json
  ensure
    db.close if db
  end
end

# Valores permitidos para el estado del pedido
ESTADOS_VALIDOS = ['pendiente', 'verificado', 'rechazado'].freeze
# Valores permitidos para el tipo de comprobante
TIPOS_COMPROBANTE_VALIDOS = ['boleta', 'factura'].freeze

put '/pedidos/:codigo' do
  content_type :json

  begin
    request_body = request.body.read.strip  
    halt 400, { error: "El cuerpo de la solicitud no puede estar vacío" }.to_json if request_body.empty?

    request_payload = JSON.parse(request_body)
    nuevo_estado = request_payload['estado']&.to_s&.strip
    tipo_comprobante = request_payload['tipo_comprobante']&.to_s&.strip

    halt 400, { error: "El estado es requerido" }.to_json if nuevo_estado.nil? || nuevo_estado.empty?

    # Validar estado permitido
    unless ESTADOS_VALIDOS.include?(nuevo_estado)
      halt 400, { error: "Estado inválido. Valores permitidos: #{ESTADOS_VALIDOS.join(', ')}" }.to_json
    end

    # Validar tipo_comprobante solo si el estado es "verificado"
    if nuevo_estado == "verificado"
      halt 400, { error: "Debe proporcionar un tipo de comprobante válido (boleta o factura)" }.to_json if tipo_comprobante.empty?

      unless TIPOS_COMPROBANTE_VALIDOS.include?(tipo_comprobante)
        halt 400, { error: "Tipo de comprobante inválido. Valores permitidos: #{TIPOS_COMPROBANTE_VALIDOS.join(', ')}" }.to_json
      end
    end

    db = connect_db

    # Verificar existencia del pedido antes de intentar actualizarlo
    pedido_existente = db.exec_params("SELECT id FROM pedidos WHERE codigo = $1", [params[:codigo]]).ntuples > 0
    halt 404, { error: "Pedido no encontrado" }.to_json unless pedido_existente

    # Verificar stock antes de actualizar a "verificado"
    if nuevo_estado == "verificado"
      result = db.exec_params(<<-SQL, [params[:codigo]])
        SELECT p.id AS producto_id, dp.cantidad AS requerido, sp.stock AS disponible
        FROM detalles_pedido dp
        JOIN productos p ON dp.producto_id = p.id
        JOIN stock_productos sp ON p.id = sp.producto_id
        WHERE dp.pedido_id = (SELECT id FROM pedidos WHERE codigo = $1)
        AND dp.cantidad > sp.stock;
      SQL

      stock_insuficiente = result.ntuples > 0

      if stock_insuficiente
        mensaje = {
          error: "Pedido rechazado por falta de stock",
          productos: result.map { |row| { producto_id: row['producto_id'], requerido: row['requerido'], disponible: row['disponible'] } }
        }
        puts "[INFO] #{mensaje.to_json}"

        db.exec_params("UPDATE pedidos SET estado = 'rechazado' WHERE codigo = $1", [params[:codigo]])

        halt 400, mensaje.to_json
      end
    end


    # Construcción de la consulta SQL
    update_query, update_params = if nuevo_estado == "verificado"
      ["UPDATE pedidos SET estado = $1, tipo_comprobante = $2 WHERE codigo = $3 RETURNING *", [nuevo_estado, tipo_comprobante, params[:codigo]]]
    else
      ["UPDATE pedidos SET estado = $1 WHERE codigo = $2 RETURNING *", [nuevo_estado, params[:codigo]]]
    end

    puts "[DEBUG] SQL: #{update_query} | Parámetros: #{update_params.inspect}"

    result = db.exec_params(update_query, update_params)

    if result.ntuples > 0
      pedido_modificado = result[0]
      puts "[INFO] Pedido actualizado correctamente: #{pedido_modificado}"

      # Enviar notificación
      notificacion_data = {
        "codigo" => pedido_modificado['codigo'],
        "estado" => pedido_modificado['estado'],
        "tipo_comprobante" => pedido_modificado['tipo_comprobante'],
        "precio_total" => pedido_modificado['precio_total'],
        "fecha_pedido" => pedido_modificado['fecha_pedido'],
        "mensaje" => "El estado del pedido ha cambiado a '#{pedido_modificado['estado']}'"
      }

      if defined?(exchange_notificaciones) && exchange_notificaciones
        exchange_notificaciones.publish(notificacion_data.to_json)
        puts "[INFO] Notificación enviada correctamente"
      else
        puts "[WARNING] No se pudo enviar la notificación: exchange_notificaciones no está definido"
      end

      status 200
      pedido_modificado.to_json
    else
      halt 404, { error: "Pedido no encontrado o no se pudo actualizar" }.to_json
    end

  rescue JSON::ParserError
    halt 400, { error: "Formato JSON inválido" }.to_json
  rescue PG::Error => e
    puts "[ERROR] Error en la base de datos: #{e.message}"
    halt 500, { error: "Error en la base de datos: #{e.message}" }.to_json
  ensure
    db&.close
  end
end


# Endpoint para generar reportes con detalles de los pedidos
post '/generar_reporte' do
  content_type :json
  db = connect_db

  begin
    # Verificar si hay pedidos antes de ejecutar la consulta pesada
    count_query = "SELECT COUNT(*) FROM pedidos;"
    count_result = db.exec(count_query)
    if count_result[0]['count'].to_i.zero?
      puts "[ERROR] No hay pedidos disponibles para generar el reporte."
      return { error: "No hay pedidos para generar el reporte" }.to_json
    end

    # Obtener pedidos y productos en una sola consulta optimizada
    query = <<-SQL
      SELECT 
        p.codigo , p.usuario_id, p.precio_total, p.estado, 
        p.metodo_pago, p.direccion_entrega, COALESCE(p.boucher_path, 'No disponible') AS boucher_path,
        pr.codigo AS producto_codigo, pr.nombre AS producto_nombre, 
        d.cantidad, d.precio_total AS producto_precio_total
      FROM pedidos p
      LEFT JOIN detalles_pedido d ON p.id = d.pedido_id
      LEFT JOIN productos pr ON d.producto_id = pr.id
      ORDER BY p.codigo;
    SQL

    pedidos_data = db.exec(query)

    pedidos = {}
    pedidos_data.each do |row|
      codigo = row['codigo']

      pedidos[codigo] ||= {
        "codigo" => codigo,
        "usuario_id" => row['usuario_id'],
        "precio_total" => row['precio_total'],
        "estado" => row['estado'],
        "metodo_pago" => row['metodo_pago'],
        "direccion_entrega" => row['direccion_entrega'],
        "fecha_pedido" => row['fecha_pedido'],
        "tipo_comprobante" => row['tipo_comprobante'],
        "boucher_path" => row['boucher_path'],
        "productos" => []
      }

      if row['producto_codigo']
        pedidos[codigo]["productos"] << {
          "codigo" => row['producto_codigo'],
          "nombre" => row['producto_nombre'],
          "cantidad" => row['cantidad'],
          "precio_total" => row['producto_precio_total']
        }
      end
    end

    reporte_data = {
      "fecha_generacion" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      "cantidad_pedidos" => pedidos.length,
      "pedidos" => pedidos.values
    }

    puts "[DEBUG] Datos del reporte a enviar: #{JSON.pretty_generate(reporte_data)}"

    if defined?(exchange_reportes) && exchange_reportes
      exchange_reportes.publish(reporte_data.to_json)
      puts "[INFO] Reporte generado y enviado a la cola 'reportes'."
    else
      puts "[WARNING] No se pudo enviar el reporte: exchange_reportes no está definido"
    end

    { mensaje: "Reporte enviado correctamente", detalles: reporte_data }.to_json

  rescue PG::ConnectionBad => e
    puts "[ERROR] No se pudo conectar a la base de datos: #{e.message}"
    halt 500, { error: "Error de conexión a la base de datos" }.to_json
  rescue PG::Error => e
    puts "[ERROR] Error en la base de datos: #{e.message}"
    halt 500, { error: "Error al generar el reporte" }.to_json
  ensure
    db.close if db
  end
end


# Manejo de interrupción para salir limpiamente
Signal.trap("INT") do
  puts "[INFO] Terminando consumidor..."
  connection.close
  exit
end

# Mantener el servicio corriendo
Sinatra::Application.run!
