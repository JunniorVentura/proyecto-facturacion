import pika
import json
import time

# Función para procesar el mensaje de alerta
def callback(ch, method, properties, body):
    print("[DEBUG] Mensaje recibido en el callback")  # Indicar que el callback fue llamado

    try:
        print(f"[DEBUG] Cuerpo del mensaje recibido: {body}")  # Mostrar el contenido del mensaje

        # Convertir el mensaje a JSON
        alerta_data = json.loads(body)

        # Validación de datos recibidos
        tipo_alerta = alerta_data.get("tipo_alerta", "Desconocida")
        codigo = alerta_data.get("codigo", "Sin código")
        precio_total = alerta_data.get("precio_total", 0.0)
        nombre_usuario = alerta_data.get("nombre_usuario", "No especificado")
        fecha_pedido = alerta_data.get("fecha_pedido", "Fecha desconocida")

        # Verificar si los datos esenciales están presentes
        if not tipo_alerta or not codigo or precio_total is None:
            print(f"[ERROR] Datos incompletos en el mensaje recibido: {alerta_data}")
            ch.basic_nack(delivery_tag=method.delivery_tag)  # No acknowledge si hay error
            return

        print("[DEBUG] Datos procesados correctamente")  # Confirmar que el JSON fue leído bien

        # Imprimir los detalles del mensaje recibido con formato claro
        print("\n [ALERTA RECIBIDA]")
        print(f"    Tipo: {tipo_alerta}")
        print(f"    Pedido: {codigo}")
        print(f"    Usuario: {nombre_usuario}")
        print(f"    Precio Total: S/{precio_total}")
        print(f"    Fecha: {fecha_pedido}\n")

        # Condición para pedidos de alto valor
        if precio_total > 1000:
            print(f" [ALERTA] Pedido {codigo} es prioritario, requiere revisión urgente.")

        # Confirmar que el mensaje fue recibido correctamente
        ch.basic_ack(delivery_tag=method.delivery_tag)

    except json.JSONDecodeError:
        print("[ERROR] No se pudo decodificar el mensaje como JSON.")
        ch.basic_nack(delivery_tag=method.delivery_tag)  # No acknowledge
    except Exception as e:
        print(f"[ERROR] Ocurrió un error al procesar la alerta: {e}")
        ch.basic_nack(delivery_tag=method.delivery_tag)  # No acknowledge

# Función para conectarse a RabbitMQ con reintento automático
def conectar_rabbitmq():
    while True:
        try:
            print("[DEBUG] Intentando conectar a RabbitMQ...")  # Indicar que se intenta conectar
            connection = pika.BlockingConnection(pika.ConnectionParameters(host='rabbitmq'))
            channel = connection.channel()
            print("[DEBUG] Conexión establecida con RabbitMQ")  # Confirmar que la conexión fue exitosa

            # Declarar la cola de alertas
            queue_name = 'alertas'
            channel.queue_declare(queue=queue_name, durable=True)
            print(f"[DEBUG] Cola '{queue_name}' declarada exitosamente")

            # Configurar el consumidor
            channel.basic_consume(queue=queue_name, on_message_callback=callback)

            print(f" [INFO] Esperando alertas en la cola '{queue_name}'...")
            channel.start_consuming()  # Iniciar consumo

        except pika.exceptions.AMQPConnectionError as e:
            print(f"[ERROR] No se pudo conectar a RabbitMQ: {e}. Reintentando en 5 segundos...")
            time.sleep(5)  # Esperar antes de reintentar

if __name__ == "__main__":
    conectar_rabbitmq()
