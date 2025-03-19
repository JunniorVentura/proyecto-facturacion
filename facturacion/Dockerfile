FROM ruby:3.1
WORKDIR /app

# Instalar dependencias del sistema para PostgreSQL y RabbitMQ
RUN apt-get update && apt-get install -y \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copiar los archivos al contenedor
COPY . /app

# Crear y configurar el Gemfile
RUN echo "source 'https://rubygems.org'" > Gemfile \
    && echo "gem 'sinatra'" >> Gemfile \
    && echo "gem 'sinatra-cross_origin'" >> Gemfile \
    && echo "gem 'bunny'" >> Gemfile \
    && echo "gem 'pg'" >> Gemfile \
    && echo "gem 'puma'" >> Gemfile \
    && echo "gem 'rackup'" >> Gemfile \
    && bundle install

# Exponer el puerto en el contenedor
EXPOSE 5000

# Ejecutar el servidor con Puma
CMD ["bundle", "exec", "ruby", "consumer.rb"]
