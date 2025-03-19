# Usa una imagen base de Python
FROM python:3.9-slim

# Instalar las dependencias necesarias
RUN pip install pika

# Copiar el archivo de código Python al contenedor
COPY alertas.py /app/alertas.py

# Establecer el directorio de trabajo
WORKDIR /app

# Exponer el puerto en el contenedor
EXPOSE 6000

# Modo sin buffer para que Docker muestre los logs en tiempo real
CMD ["python", "-u", "alertas.py"]
