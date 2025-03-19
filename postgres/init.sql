-- Crear tabla de usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(10) UNIQUE,
    dni VARCHAR(8) UNIQUE NOT NULL CHECK (LENGTH(dni) = 8),
    ruc VARCHAR(11) UNIQUE CHECK (ruc IS NULL OR LENGTH(ruc) = 11),
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    celular VARCHAR(20) NOT NULL,
    direccion TEXT NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger para generar código de usuario
CREATE OR REPLACE FUNCTION generar_codigo_usuario()
RETURNS TRIGGER AS $$
BEGIN
    NEW.codigo := 'U' || LPAD(NEW.id::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_codigo_usuario
BEFORE INSERT ON usuarios
FOR EACH ROW
EXECUTE FUNCTION generar_codigo_usuario();

-- Crear tabla de categorías
CREATE TABLE IF NOT EXISTS categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion TEXT
);

-- Crear tabla de productos 
CREATE TABLE IF NOT EXISTS productos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(10) UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL,
    categoria_id INT REFERENCES categorias(id) ON DELETE SET NULL
);

-- Trigger para generar código de producto
CREATE OR REPLACE FUNCTION generar_codigo_producto()
RETURNS TRIGGER AS $$
BEGIN
    NEW.codigo := 'P' || LPAD(NEW.id::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_codigo_producto
BEFORE INSERT ON productos
FOR EACH ROW
EXECUTE FUNCTION generar_codigo_producto();

-- Crear tabla de stock de productos
CREATE TABLE IF NOT EXISTS stock_productos (
    id SERIAL PRIMARY KEY,
    producto_id INT UNIQUE,
    stock INT NOT NULL CHECK (stock >= 0) DEFAULT 0,
    CONSTRAINT fk_producto FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE
);

-- Crear tabla de pedidos
CREATE TABLE IF NOT EXISTS pedidos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(10) UNIQUE,
    usuario_id INT REFERENCES usuarios(id) ON DELETE CASCADE,
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    precio_total DECIMAL(10,2) NOT NULL,
    estado VARCHAR(20) DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'verificado', 'rechazado')),
    metodo_pago VARCHAR(50) NOT NULL,
    tipo_comprobante VARCHAR(20) CHECK (tipo_comprobante IN ('boleta', 'factura')) NULL, -- Se permite NULL
    direccion_entrega TEXT NOT NULL,
    boucher_path VARCHAR(255)
);

-- Trigger para generar código de pedido
CREATE OR REPLACE FUNCTION generar_codigo_pedido()
RETURNS TRIGGER AS $$
BEGIN
    NEW.codigo := 'PED' || LPAD(NEW.id::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_codigo_pedido
BEFORE INSERT ON pedidos
FOR EACH ROW
EXECUTE FUNCTION generar_codigo_pedido();

-- Crear tabla de detalles de pedido
CREATE TABLE IF NOT EXISTS detalles_pedido (
    id SERIAL PRIMARY KEY,
    pedido_id INT REFERENCES pedidos(id) ON DELETE CASCADE,
    producto_id INT REFERENCES productos(id) ON DELETE CASCADE,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL,
    precio_total DECIMAL(10,2) NOT NULL
);

-- Crear tabla de facturas
CREATE TABLE IF NOT EXISTS facturas (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(10) UNIQUE,
    pedido_id INT UNIQUE, 
    fecha_factura TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10,2) NOT NULL,
    ruc VARCHAR(20) NOT NULL,
    CONSTRAINT fk_facturas_pedidos FOREIGN KEY (pedido_id) REFERENCES pedidos(id) ON DELETE CASCADE
);

-- Trigger para generar código de factura
CREATE OR REPLACE FUNCTION generar_codigo_factura()
RETURNS TRIGGER AS $$
BEGIN
    NEW.codigo := 'FAC' || LPAD(NEW.id::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_codigo_factura
BEFORE INSERT ON facturas
FOR EACH ROW
EXECUTE FUNCTION generar_codigo_factura();

-- Crear tabla de detalles de factura
CREATE TABLE IF NOT EXISTS detalles_factura (
    id SERIAL PRIMARY KEY,
    factura_id INT REFERENCES facturas(id) ON DELETE CASCADE,
    producto_id INT REFERENCES productos(id) ON DELETE CASCADE,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL,
    precio_total DECIMAL(10,2) NOT NULL
);

-- Crear tabla de boletas
CREATE TABLE IF NOT EXISTS boletas (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(10) UNIQUE,
    pedido_id INT UNIQUE, 
    fecha_boleta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_boletas_pedidos FOREIGN KEY (pedido_id) REFERENCES pedidos(id) ON DELETE CASCADE
);

-- Trigger para generar código de boleta
CREATE OR REPLACE FUNCTION generar_codigo_boleta()
RETURNS TRIGGER AS $$
BEGIN
    NEW.codigo := 'BOL' || LPAD(NEW.id::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_codigo_boleta
BEFORE INSERT ON boletas
FOR EACH ROW
EXECUTE FUNCTION generar_codigo_boleta();

-- Crear tabla de detalles de boleta
CREATE TABLE IF NOT EXISTS detalles_boleta (
    id SERIAL PRIMARY KEY,
    boleta_id INT REFERENCES boletas(id) ON DELETE CASCADE,
    producto_id INT REFERENCES productos(id) ON DELETE CASCADE,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL,
    precio_total DECIMAL(10,2) NOT NULL
);

-- Procedimientos almacenados para busqueda de Usuarios
-- Buscar usuario por DNI
CREATE OR REPLACE FUNCTION buscar_usuario_por_dni(p_dni VARCHAR(8))
RETURNS TABLE (id INT, codigo VARCHAR, dni VARCHAR, ruc VARCHAR, nombre VARCHAR, email VARCHAR, celular VARCHAR, direccion TEXT)
AS $$
BEGIN
    RETURN QUERY SELECT u.id, u.codigo, u.dni, u.ruc, u.nombre, u.email, u.celular, u.direccion
    FROM usuarios u WHERE u.dni = p_dni;
END;
$$ LANGUAGE plpgsql;

-- Buscar usuario por RUC
CREATE OR REPLACE FUNCTION buscar_usuario_por_ruc(p_ruc VARCHAR(11))
RETURNS TABLE (id INT, codigo VARCHAR, dni VARCHAR, ruc VARCHAR, nombre VARCHAR, email VARCHAR, celular VARCHAR, direccion TEXT)
AS $$
BEGIN
    RETURN QUERY SELECT u.id, u.codigo, u.dni, u.ruc, u.nombre, u.email, u.celular, u.direccion
    FROM usuarios u WHERE u.ruc = p_ruc;
END;
$$ LANGUAGE plpgsql;

-- Buscar usuario por código
CREATE OR REPLACE FUNCTION buscar_usuario_por_codigo(p_codigo VARCHAR(10))
RETURNS TABLE (id INT, codigo VARCHAR, dni VARCHAR, ruc VARCHAR, nombre VARCHAR, email VARCHAR, celular VARCHAR, direccion TEXT)
AS $$
BEGIN
    RETURN QUERY SELECT u.id, u.codigo, u.dni, u.ruc, u.nombre, u.email, u.celular, u.direccion
    FROM usuarios u WHERE u.codigo = p_codigo;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para buscar producto con  de stock
CREATE OR REPLACE FUNCTION buscar_productos_con_stock()
RETURNS TABLE (id INT, codigo VARCHAR, nombre VARCHAR, descripcion TEXT, precio DECIMAL, categoria_id INT, stock INT)
AS $$
BEGIN
    RETURN QUERY 
    SELECT p.id, p.codigo, p.nombre, p.descripcion, p.precio, p.categoria_id, s.stock
    FROM productos p
    JOIN stock_productos s ON p.id = s.producto_id
    WHERE s.stock > 0;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para buscar producto por código con verificación de stock
CREATE OR REPLACE FUNCTION buscar_producto_por_codigo(p_codigo VARCHAR(10))
RETURNS TABLE (id INT, codigo VARCHAR, nombre VARCHAR, descripcion TEXT, precio DECIMAL, categoria_id INT, stock INT)
AS $$
BEGIN
    RETURN QUERY 
    SELECT p.id, p.codigo, p.nombre, p.descripcion, p.precio, p.categoria_id, s.stock
    FROM productos p
    JOIN stock_productos s ON p.id = s.producto_id
    WHERE p.codigo = p_codigo AND s.stock > 0;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para buscar producto por nombre con verificación de stock
CREATE OR REPLACE FUNCTION buscar_producto_por_nombre(p_nombre VARCHAR)
RETURNS TABLE (id INT, codigo VARCHAR, nombre VARCHAR, descripcion TEXT, precio DECIMAL, categoria_id INT, stock INT)
AS $$
BEGIN
    RETURN QUERY 
    SELECT p.id, p.codigo, p.nombre, p.descripcion, p.precio, p.categoria_id, s.stock
    FROM productos p
    JOIN stock_productos s ON p.id = s.producto_id
    WHERE p.nombre ILIKE '%' || p_nombre || '%' AND s.stock > 0;
END;
$$ LANGUAGE plpgsql;

-- Función para descontar stock al verificar pedido
CREATE OR REPLACE FUNCTION descontar_stock_al_verificar()
RETURNS TRIGGER AS $$
BEGIN
    -- Verificar que todos los productos tengan suficiente stock
    IF NEW.estado = 'verificado' THEN
        IF EXISTS (
            SELECT 1 
            FROM detalles_pedido dp
            JOIN stock_productos sp ON dp.producto_id = sp.producto_id
            WHERE dp.pedido_id = NEW.id
            AND sp.stock < dp.cantidad
        ) THEN
            RAISE EXCEPTION 'No hay suficiente stock para procesar el pedido';
        END IF;
        
        -- Si hay stock suficiente, descontar
        UPDATE stock_productos sp
        SET stock = stock - dp.cantidad
        FROM detalles_pedido dp
        WHERE dp.pedido_id = NEW.id
        AND sp.producto_id = dp.producto_id;

    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento almacenado para insertar factura o boleta desde un pedido
CREATE OR REPLACE FUNCTION generar_comprobante(p_codigo_pedido VARCHAR(10))
RETURNS VOID AS $$
DECLARE
    v_pedido_id INT;
    v_precio_total DECIMAL(10,2);
    v_tipo_comprobante VARCHAR(20);
    v_ruc VARCHAR(11);
    v_factura_id INT;
    v_boleta_id INT;
BEGIN
    -- Buscar el ID del pedido y sus detalles
    SELECT id, precio_total, tipo_comprobante 
    INTO v_pedido_id, v_precio_total, v_tipo_comprobante
    FROM pedidos 
    WHERE codigo = p_codigo_pedido;

    -- Si el pedido no existe, lanzar un error
    IF v_pedido_id IS NULL THEN
        RAISE EXCEPTION 'El pedido con código % no existe', p_codigo_pedido;
    END IF;

    -- Si el pedido no está verificado, no se puede generar comprobante
    IF (SELECT estado FROM pedidos WHERE id = v_pedido_id) <> 'verificado' THEN
        RAISE EXCEPTION 'El pedido debe estar en estado "verificado" para generar comprobante';
    END IF;

    -- Verificar el tipo de comprobante
    IF v_tipo_comprobante = 'factura' THEN
        -- Obtener el RUC del usuario
        SELECT ruc INTO v_ruc FROM usuarios WHERE id = (SELECT usuario_id FROM pedidos WHERE id = v_pedido_id);
        
        -- Verificar si el usuario tiene RUC
        IF v_ruc IS NULL THEN
            RAISE EXCEPTION 'El usuario del pedido no tiene RUC registrado, no se puede emitir factura';
        END IF;

        -- Insertar en facturas
        INSERT INTO facturas (pedido_id, total, ruc)
        VALUES (v_pedido_id, v_precio_total, v_ruc)
        RETURNING id INTO v_factura_id;

        -- Insertar detalles de factura
        INSERT INTO detalles_factura (factura_id, producto_id, cantidad, precio_unitario, precio_total)
        SELECT v_factura_id, producto_id, cantidad, precio_unitario, precio_total
        FROM detalles_pedido WHERE pedido_id = v_pedido_id;

    ELSIF v_tipo_comprobante = 'boleta' THEN
        -- Insertar en boletas
        INSERT INTO boletas (pedido_id, total)
        VALUES (v_pedido_id, v_precio_total)
        RETURNING id INTO v_boleta_id;

        -- Insertar detalles de boleta
        INSERT INTO detalles_boleta (boleta_id, producto_id, cantidad, precio_unitario, precio_total)
        SELECT v_boleta_id, producto_id, cantidad, precio_unitario, precio_total
        FROM detalles_pedido WHERE pedido_id = v_pedido_id;

    ELSE
        RAISE EXCEPTION 'El tipo de comprobante % no es válido', v_tipo_comprobante;
    END IF;
    
END;
$$ LANGUAGE plpgsql;


-- Trigger que se activa cuando el pedido cambia a "verificado"
CREATE TRIGGER trg_descontar_stock
AFTER UPDATE ON pedidos
FOR EACH ROW
WHEN (OLD.estado <> 'verificado' AND NEW.estado = 'verificado')
EXECUTE FUNCTION descontar_stock_al_verificar();

-- Vistas para Reportes
-- Vista de Ventas por Mes
CREATE VIEW reporte_ventas_mensuales AS
SELECT 
    DATE_TRUNC('month', p.fecha_pedido) AS mes,
    SUM(p.precio_total) AS total_ventas,
    COUNT(p.id) AS total_pedidos
FROM pedidos p
WHERE p.estado = 'verificado'
GROUP BY mes
ORDER BY mes;

-- Vista de Productos Más Vendidos
CREATE VIEW productos_mas_vendidos AS
SELECT 
    dp.producto_id, 
    p.nombre AS producto,
    SUM(dp.cantidad) AS cantidad_vendida,
    SUM(dp.precio_total) AS ingresos
FROM detalles_pedido dp
JOIN productos p ON dp.producto_id = p.id
JOIN pedidos pe ON dp.pedido_id = pe.id
WHERE pe.estado = 'verificado'
GROUP BY dp.producto_id, p.nombre
ORDER BY cantidad_vendida DESC
LIMIT 10;

-- Vista de Clientes con Más Compras
CREATE VIEW clientes_top AS
SELECT 
    u.id AS usuario_id, 
    u.nombre, 
    u.email, 
    COUNT(p.id) AS cantidad_pedidos,
    SUM(p.precio_total) AS total_gastado
FROM pedidos p
JOIN usuarios u ON p.usuario_id = u.id
WHERE p.estado = 'verificado'
GROUP BY u.id, u.nombre, u.email
ORDER BY total_gastado DESC
LIMIT 10;

--Vista de Facturas Realizadas Durante el Mes
CREATE VIEW facturas_mensuales AS
SELECT 
    DATE_TRUNC('month', f.fecha_factura) AS mes,
    SUM(f.total) AS total_facturado,
    COUNT(f.id) AS total_facturas
FROM facturas f
JOIN pedidos p ON f.pedido_id = p.id
WHERE p.estado = 'verificado'
GROUP BY mes
ORDER BY mes;

--Vista de Boletas Realizadas Durante el Mes
CREATE VIEW boletas_mensuales AS
SELECT 
    DATE_TRUNC('month', b.fecha_boleta) AS mes,
    SUM(b.total) AS total_boletado,
    COUNT(b.id) AS total_boletas
FROM boletas b
JOIN pedidos p ON b.pedido_id = p.id
WHERE p.estado = 'facturado'
GROUP BY mes
ORDER BY mes;

-- Insertar usuarios
INSERT INTO usuarios (dni, ruc, nombre, email, celular, direccion) VALUES
('12345678', '20123456789', 'Juan Rodriguez', 'neocout02@gmail.com', '991160937', 'Av. Siempre Viva 123'),
('87654321', '20987654321', 'Maria López', 'neocout03@gmail.com', '921833850', 'Calle Falsa 456'),
('11223344', '20111223344', 'Carlos Mendoza', 'neocout02@gmail.com', '991160937', 'Jr. Amazonas 789'),
('55667788', '20556677889', 'Ana Castillo', 'neocout03@gmail.com', '921833850', 'Av. El Sol 321'),
('99887766', '20998877665', 'Pedro Rojas', 'neocout02@gmail.com', '991160937', 'Calle Central 654'),
('33445566', '20334455663', 'Lucía Fernández', 'neocout03@gmail.com', '921833850', 'Av. Las Palmas 789'),
('22334455', '20223344552', 'Hugo Ramírez', 'neocout02@gmail.com', '991160937', 'Jr. Independencia 456'),
('66778899', '20667788991', 'Gabriela Torres', 'neocout03@gmail.com', '921833850', 'Pasaje Los Olivos 222'),
('44556677', '20445566772', 'Fernando Guzmán', 'neocout02@gmail.com', '991160937', 'Jr. Tarapacá 987'),
('77889900', '20778899003', 'Rosa Vargas', 'neocout03@gmail.com', '921833850', 'Av. Arequipa 145'),
('99112233', '20991122331', 'Diego López', 'neocout02@gmail.com', '991160937', 'Calle Los Álamos 321'),
('33221100', '20332211004', 'Elena Morales', 'neocout03@gmail.com', '921833850', 'Av. Primavera 654'),
('55443322', '20554433225', 'Ricardo Flores', 'neocout02@gmail.com', '991160937', 'Jr. San Martín 888'),
('77665544', '20776655441', 'Andrea Salazar', 'neocout03@gmail.com', '921833850', 'Pasaje La Molina 963'),
('88990011', '20889900112', 'Luis Gutiérrez', 'neocout02@gmail.com', '991160937', 'Av. Javier Prado 741');

-- Insertar categorias
INSERT INTO categorias (nombre, descripcion) VALUES
('Laptops', 'Laptops de diversas marcas y modelos'),
('Smartphones', 'Celulares de última tecnología'),
('Accesorios', 'Accesorios para computadoras y celulares'),
('Audio y Video', 'Equipos de sonido, parlantes y televisores'),
('Electrodomésticos', 'Artículos electrónicos para el hogar');

--Insertar productos
INSERT INTO productos (nombre, descripcion, precio, categoria_id) VALUES
-- Laptops
('Laptop HP Pavilion', 'Laptop de 15 pulgadas, 16GB RAM, 512GB SSD', 3500.00, 1),
('Laptop Dell Inspiron', 'Laptop de 14 pulgadas, 8GB RAM, 256GB SSD', 2800.00, 1),
('MacBook Air M1', 'Laptop Apple con chip M1, 13 pulgadas', 4500.00, 1),
('Laptop Lenovo ThinkPad', 'Portátil empresarial con 16GB RAM', 3200.00, 1),
('Laptop Asus ROG', 'Laptop gaming con RTX 3060', 5800.00, 1),

-- Smartphones
('iPhone 13', 'Smartphone Apple con 128GB', 4200.00, 2),
('Samsung Galaxy S23', 'Teléfono con pantalla AMOLED y 256GB', 3800.00, 2),
('Xiaomi Redmi Note 12', 'Teléfono con 6GB RAM y 128GB almacenamiento', 1200.00, 2),
('Google Pixel 7', 'Teléfono con Android puro y excelente cámara', 3400.00, 2),
('OnePlus 11', 'Teléfono con Snapdragon 8 Gen 2', 3600.00, 2),

-- Accesorios
('Mouse Logitech', 'Mouse inalámbrico ergonómico', 150.00, 3),
('Teclado Mecánico Redragon', 'Teclado con retroiluminación RGB', 280.00, 3),
('Auriculares Sony', 'Auriculares Bluetooth con cancelación de ruido', 750.00, 3),
('Cargador USB-C', 'Cargador rápido de 65W', 200.00, 3),
('Monitor LG 24"', 'Monitor Full HD de 24 pulgadas', 1100.00, 3),

-- Audio y Video
('Televisor Samsung 55"', 'Smart TV 4K UHD', 3200.00, 4),
('Barra de sonido Bose', 'Barra de sonido con subwoofer inalámbrico', 2500.00, 4),
('Proyector Epson', 'Proyector Full HD con 3000 lúmenes', 2800.00, 4),
('Audífonos JBL', 'Auriculares deportivos Bluetooth', 500.00, 4),
('Parlante Bluetooth Sony', 'Parlante portátil con sonido envolvente', 600.00, 4),

-- Electrodomésticos
('Refrigeradora LG', 'Refrigeradora de 400L con tecnología Inverter', 2800.00, 5),
('Lavadora Samsung', 'Lavadora automática 14kg', 2100.00, 5),
('Horno Microondas Panasonic', 'Horno microondas con grill', 850.00, 5),
('Aspiradora Xiaomi', 'Aspiradora robot con mapeo inteligente', 3200.00, 5),
('Cafetera Nespresso', 'Cafetera automática con cápsulas', 1300.00, 5);

--Insertar stock de los productos
INSERT INTO stock_productos (producto_id, stock) VALUES
(1, 15), (2, 12), (3, 10), (4, 8), (5, 6),
(6, 20), (7, 18), (8, 30), (9, 10), (10, 15),
(11, 40), (12, 25), (13, 22), (14, 30), (15, 12),
(16, 8), (17, 6), (18, 5), (19, 20), (20, 18),
(21, 7), (22, 9), (23, 14), (24, 12), (25, 10);

/*--Uso de las funciones almacenadas
--Buscar un usuario por DNI
SELECT * FROM buscar_usuario_por_dni('12345678');
--Buscar un productos con stock
SELECT * FROM buscar_productos_con_stock();
--Buscar un producto por código
SELECT * FROM buscar_producto_por_codigo('P0003');
--Buscar productos por nombre
SELECT * FROM buscar_producto_por_nombre('iPhone');
--Ejemplo de Uso del Trigger
--Insertar Pedido
INSERT INTO pedidos (usuario_id, precio_total, metodo_pago, direccion_entrega) 
VALUES (1, 8000.00, 'deposito', 'Av. Principal 123');
--Insertar Detalle del Pedido
INSERT INTO detalles_pedido (pedido_id, producto_id, cantidad, precio_unitario, precio_total) 
VALUES (1, 1, 2, 3500.00, 7000.00),
       (1, 6, 1, 4200.00, 4200.00);
--Verificar el Pedido (Activa el Trigger)
UPDATE pedidos 
SET estado = 'verificado' 
WHERE id = 1;

--Consultas sobre Vistas
--Ventas por mes
SELECT * FROM reporte_ventas_mensuales;
--Productos más vendidos
SELECT * FROM productos_mas_vendidos;
--Clientes con más compras
SELECT * FROM clientes_top;
--Facturas realizadas durante el mes
SELECT * FROM facturas_mensuales;
--Boletas realizadas durante el mes
SELECT * FROM boletas_mensuales;*/
