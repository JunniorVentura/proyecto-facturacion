FROM postgres:latest

# Establece las variables de entorno para PostgreSQL
ENV POSTGRES_DB=tienda_db
ENV POSTGRES_USER=user
ENV POSTGRES_PASSWORD=password

# Copia el script de inicialización al contenedor
COPY init.sql /docker-entrypoint-initdb.d/

# Expone el puerto de PostgreSQL
EXPOSE 5432

