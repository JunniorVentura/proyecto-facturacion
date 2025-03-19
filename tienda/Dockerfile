FROM php:8.1-apache

# Establecer el directorio de trabajo
WORKDIR /var/www/html

# Copiar los archivos de la aplicación antes de instalar dependencias
COPY . /var/www/html

# Instalar dependencias del sistema y PHP
RUN apt-get update && apt-get install -y \
    unzip \
    git \
    libpq-dev \
    && docker-php-ext-install sockets pdo pdo_pgsql \
    && rm -rf /var/lib/apt/lists/*

# Configurar ServerName 
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Instalar Composer globalmente
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer clear-cache

# Instalar dependencias de PHP (RabbitMQ)
RUN composer require php-amqplib/php-amqplib

# Crear la carpeta para los bouchers y dar permisos
RUN mkdir -p /var/www/html/bouchers && chmod -R 777 /var/www/html/bouchers

# Ajustar permisos para Apache
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Exponer el puerto 80
EXPOSE 80

# Ejecutar Apache en primer plano
CMD ["apache2-foreground"]
