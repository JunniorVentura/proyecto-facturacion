require 'pdfkit'
require 'fileutils'
require 'json'
require 'sinatra'
require 'sinatra/cross_origin'
require 'bunny'
require 'pg'

# Configuración de Sinatra
set :public_folder, '/usr/src/app/reports'
set :bind, '0.0.0.0'
set :port, 7000

configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
end

options '*' do
  200
end

OUTPUT_DIR = '/usr/src/app/reports'
FileUtils.mkdir_p(OUTPUT_DIR)

def generate_filename(extension)
  timestamp = Time.now.strftime('%Y-%m-%d_%H-%M-%S')
  "#{OUTPUT_DIR}/reporte_#{timestamp}.#{extension}"
end

# Función para conectar a PostgreSQL
def connect_db
  PG.connect(
    host: 'postgres_db',
    port: 5432,
    dbname: 'tienda_db',
    user: 'user',
    password: 'password'
  )
end

get '/reports' do
  files = Dir.entries(OUTPUT_DIR).select { |f| f.end_with?('.pdf', '.xlsx') }
  files.to_json
end

get '/reports/:filename' do
  file_path = File.join(OUTPUT_DIR, params[:filename])
  if File.exist?(file_path)
    send_file file_path
  else
    status 404
    "Archivo no encontrado"
  end
end

def obtener_usuario(usuario_id)
  db = connect_db
  result = db.exec_params("SELECT nombre, email FROM usuarios WHERE id = $1 LIMIT 1", [usuario_id])
  db.close

  if result.ntuples > 0
    { "nombre" => result[0]["nombre"], "email" => result[0]["email"] }
  else
    { "nombre" => "Desconocido", "email" => "No disponible" }
  end
end

def generate_pdf(data)
  file_path = generate_filename('pdf')

  # Agregar datos de usuario a cada pedido
  data['pedidos'].each do |pedido|
    usuario_info = obtener_usuario(pedido['usuario_id'])
    pedido['nombre_usuario'] = usuario_info['nombre']
    pedido['email_usuario'] = usuario_info['email']
  end

  # Separar pedidos por estado
  pedidos_pendientes = data['pedidos'].select { |p| p['estado'] == 'pendiente' }
  pedidos_verificados = data['pedidos'].select { |p| p['estado'] == 'verificado' }
  pedidos_rechazados = data['pedidos'].select { |p| p['estado'] == 'rechazado' }

  # Agrupar productos más pedidos
  productos_agrupados = data['pedidos'].flat_map do |p|
    (p['productos'] || []).map { |prod| prod.merge('estado' => p['estado']) }
  end.group_by { |prod| prod['nombre'] }
    .map do |nombre, lista|
      {
        nombre: nombre,
        total: lista.sum { |p| p['cantidad'].to_i },
        pendiente: lista.count { |p| p['estado'] == 'pendiente' },
        verificado: lista.count { |p| p['estado'] == 'verificado' },
        rechazado: lista.count { |p| p['estado'] == 'rechazado' }
      }
    end

    def pedidos_html(pedidos, colspan)
      return "<tr><td colspan='#{colspan}'>No hay pedidos</td></tr>" if pedidos.empty?
    
      pedidos.map do |p|
        productos = "<ul>" + p['productos'].map do |prod|
          "<li>
            #{prod['nombre']}<br>
            Cantidad: #{prod['cantidad']}<br>
            Precio Unitario: S/ #{prod['precio_unitario']}<br>
            Total: S/ #{prod['precio_total']}
          </li>"
        end.join + "</ul>"
    
        # Verificar si el estado es "verificado" para agregar "tipo_comprobante"
        tipo_comprobante_td = p['estado'] == "verificado" ? "<td>#{p['tipo_comprobante']}</td>" : ""
    
        "<tr>
          <td>#{p['codigo']}</td>
          <td>#{p['nombre_usuario']}</td>
          <td>#{p['email_usuario']}</td>
          <td>S/ #{p['precio_total']}</td>
          <td>#{productos}</td>
          <td>#{p['estado']}</td>
          #{tipo_comprobante_td}
          <td>#{p.fetch('fecha_pedido', 'No disponible')}</td>
        </tr>"
      end.join
    end

  def resumen_html(datos)
    return "<tr><td colspan='5'>No hay datos</td></tr>" if datos.empty?

    datos.map do |d|
      "<tr>
        <td>#{d[:nombre]}</td>
        <td>#{d[:total]}</td>
        <td>#{d[:pendiente]}</td>
        <td>#{d[:verificado]}</td>
        <td>#{d[:rechazado]}</td>
      </tr>"
    end.join
  end

  contenido = <<~HTML
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; }
          h1 { color: #333; }
          table { width: 100%; border-collapse: collapse; margin-top: 10px; }
          th, td { border: 1px solid #000; padding: 8px; text-align: left; }
          th { background-color: #f2f2f2; }
        </style>
      </head>
      <body>
        <h1>Reporte General de Pedidos</h1>
        <p><strong>Fecha de Generación:</strong> #{data['fecha_generacion']}</p>
        <p><strong>Total de Pedidos:</strong> #{data['cantidad_pedidos']}</p>

        <h2>Pedidos Pendientes</h2>
        <table>
          <tr><th>Código Pedido</th><th>Usuario</th><th>Email</th><th>Precio Total</th><th>Productos</th><th>Estado</th><th>Fecha Pedido</th></tr>
          #{pedidos_html(pedidos_pendientes,7)}
        </table>

        <h2>Pedidos Verificados</h2>
        <table>
          <tr><th>Código Pedido</th><th>Usuario</th><th>Email</th><th>Precio Total</th><th>Productos</th><th>Estado</th><th>Comprobante</th><th>Fecha Pedido</th></tr>
          #{pedidos_html(pedidos_verificados,8)}
        </table>

        <h2>Pedidos Rechazados</h2>
        <table>
          <tr><th>Código Pedido</th><th>Usuario</th><th>Email</th><th>Precio Total</th><th>Productos</th><th>Estado</th><th>Fecha Pedido</th></tr>
          #{pedidos_html(pedidos_rechazados,7)}
        </table>

        <h2>Productos Más Pedidos</h2>
        <table>
          <tr><th>Producto</th><th>Total</th><th>Pendiente</th><th>Verificado/Facturado</th><th>Rechazado</th></tr>
          #{resumen_html(productos_agrupados)}
        </table>
      </body>
    </html>
  HTML

  PDFKit.new(contenido).to_file(file_path)
  puts "PDF generado: #{file_path}"
end

def start_rabbitmq_consumer
  loop do
    begin
      connection = Bunny.new(hostname: 'rabbitmq')
      connection.start
      channel = connection.create_channel
      queue = channel.queue('reportes', durable: true)

      puts "Esperando mensajes en la cola 'reportes'..."

      queue.subscribe(block: false, manual_ack: true) do |delivery_info, _properties, body|
        begin
          data = JSON.parse(body)
          puts "Mensaje recibido: #{data}"
          generate_pdf(data) if data['pedidos']&.any?
          channel.ack(delivery_info.delivery_tag)
        rescue JSON::ParserError
          puts "Error: Mensaje no es un JSON válido."
        rescue => e
          puts "Error procesando el mensaje: #{e.message}"
        end
      end

      sleep
    rescue => e
      puts "Error con RabbitMQ: #{e.message}. Reintentando en 5 segundos..."
      sleep 5
    end
  end
end

Thread.new { start_rabbitmq_consumer }

puts "Servidor corriendo en http://0.0.0.0:7000"
