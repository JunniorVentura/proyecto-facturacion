# Usa una imagen base con Ruby 3.1
FROM ruby:3.1

# Instala dependencias necesarias para PostgreSQL, wkhtmltopdf y Sinatra
RUN apt-get update -qq && \
    apt-get install -y \
      nodejs \
      wkhtmltopdf \
      xfonts-base \
      xfonts-75dpi \
      libxrender1 \
      libxtst6 \
      libjpeg62-turbo \
      libpq-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Establecer la variable de entorno para wkhtmltopdf (PDFKit)
ENV WKHTMLTOPDF_PATH="/usr/bin/wkhtmltopdf"

# Instalar gemas necesarias para el proyecto
RUN gem install bunny pdfkit sinatra puma rackup sinatra-cross_origin write_xlsx pg

# Configurar el directorio de trabajo
WORKDIR /usr/src/app

# Copiar todos los archivos del proyecto al contenedor
COPY . .

# Crear la carpeta donde se guardarán los reportes y asignar permisos
RUN mkdir -p /usr/src/app/reports && chmod -R 777 /usr/src/app/reports

# Exponer el puerto 7000 para el servidor Sinatra
EXPOSE 7000

# Ejecutar el servidor con Puma
CMD ["ruby", "reportes.rb"]
