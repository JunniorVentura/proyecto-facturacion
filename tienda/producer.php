<?php
// Habilitar CORS
header('Access-Control-Allow-Origin: *');
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');

require 'vendor/autoload.php';
use PhpAmqpLib\Connection\AMQPStreamConnection;
use PhpAmqpLib\Message\AMQPMessage;

$dsn = "pgsql:host=postgres_db;port=5432;dbname=tienda_db";
$user = "user";
$password = "password";

try {
    $pdo = new PDO($dsn, $user, $password, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} catch (PDOException $e) {
    die(json_encode(["error" => "Error de conexión a la base de datos", "detalle" => $e->getMessage()]));
}

// Obtener el último código de pedido
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['ultimo_codigo_pedido'])) {
    $stmt = $pdo->query("SELECT codigo FROM pedidos ORDER BY id DESC LIMIT 1");
    $ultimo_pedido = $stmt->fetch(PDO::FETCH_ASSOC);
    $ultimo_codigo = $ultimo_pedido ? (int) substr($ultimo_pedido['codigo'], 3) + 1 : 1;
    $nuevo_codigo = 'PED' . str_pad($ultimo_codigo, 4, '0', STR_PAD_LEFT);
    echo json_encode(["ultimo_codigo" => $nuevo_codigo]);
    exit;
}

// Obtener lista de usuarios
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['usuarios'])) {
    $stmt = $pdo->query("SELECT codigo, dni, ruc, nombre, email, celular, direccion FROM usuarios");
    $usuarios = $stmt->fetchAll(PDO::FETCH_ASSOC);
    if (!$usuarios) {
        echo json_encode([]); // Devuelve un array vacío en lugar de null o un error
    } else {
        echo json_encode($usuarios);
    }
    exit;
}

//Buscar Usuarios por codigo
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['usuario_codigo_search'])) {
    $stmt = $pdo->prepare("SELECT * FROM buscar_usuario_por_codigo(?)");
    $stmt->execute([$_GET['usuario_codigo_search']]); // Aquí debe ir un array
    $usuarios = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (!$usuarios) {
        echo json_encode([]); // Devuelve un array vacío en lugar de null o un error
    } else {
        echo json_encode($usuarios);
    }
    exit;
}
//Buscar Usuarios por dni
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['usuario_dni_search'])) {
    $stmt = $pdo->prepare("SELECT * FROM buscar_usuario_por_dni(?)");
    $stmt->execute([$_GET['usuario_dni_search']]); // Aquí debe ir un array
    $usuarios = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (!$usuarios) {
        echo json_encode([]); // Devuelve un array vacío en lugar de null o un error
    } else {
        echo json_encode($usuarios);
    }
    exit;
}
//Buscar Usuarios por ruc
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['usuario_ruc_search'])) {
    $stmt = $pdo->prepare("SELECT * FROM buscar_usuario_por_ruc(?)");
    $stmt->execute([$_GET['usuario_ruc_search']]);  // Aquí debe ir un array
    $usuarios = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (!$usuarios) {
        echo json_encode([]); // Devuelve un array vacío en lugar de null o un error
    } else {
        echo json_encode($usuarios);
    }
    exit;
}

// Obtener lista de productos con stock
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['productos'])) {
    $stmt = $pdo->prepare("SELECT * FROM buscar_productos_con_stock()");
    $stmt->execute(); // EJECUTAR LA CONSULTA ANTES DE FETCH
    $productos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    if (!$productos) {
        echo json_encode([]); // Devuelve un array vacío en lugar de null o un error
    } else {
        echo json_encode($productos);
    }
    exit;
}

//Buscar Producto por codigo
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['producto_codigo_search'])) {
    $stmt = $pdo->prepare("SELECT * FROM buscar_producto_por_codigo(?)");
    $stmt->execute([$_GET['producto_codigo_search']]);  // Aquí debe ir un array
    $productos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    if (!$productos) {
        echo json_encode([]); // Devuelve un array vacío en lugar de null o un error
    } else {
        echo json_encode($productos);
    }
    exit;
}
//Buscar Producto por nombre
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['producto_nombre_search'])) {
    $stmt = $pdo->prepare("SELECT * FROM buscar_producto_por_nombre(?)");
    $stmt->execute([$_GET['producto_nombre_search']]);  // Aquí debe ir un array
    $productos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    if (!$productos) {
        echo json_encode([]); // Devuelve un array vacío en lugar de null o un error
    } else {
        echo json_encode($productos);
    }
    exit;
}

// Carpeta de subida de bouchers
$uploadDir = __DIR__ . '/bouchers/';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0777, true);
}

// Verificar que la solicitud es POST y que los datos están presentes
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['boucher']) && isset($_POST['codigo_pedido'])) {
    header('Content-Type: application/json'); // Asegurar respuesta en JSON

    $codigoPedido = preg_replace('/[^a-zA-Z0-9]/', '_', $_POST['codigo_pedido']); // Sanitizar código
    $randomNumber = rand(1000, 9999); // Número aleatorio para evitar colisiones

    // Validar errores en la subida del archivo
    if ($_FILES['boucher']['error'] !== UPLOAD_ERR_OK) {
        echo json_encode(["error" => "Error en la subida del archivo"]);
        exit;
    }

    // Validar tamaño del archivo (máx. 5MB)
    if ($_FILES['boucher']['size'] > 5 * 1024 * 1024) {
        echo json_encode(["error" => "El archivo es demasiado grande (máx. 5MB)"]);
        exit;
    }

    // Validar tipo de archivo permitido
    $allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
    $extension = strtolower(pathinfo($_FILES['boucher']['name'], PATHINFO_EXTENSION));

    if (!in_array($extension, $allowedExtensions)) {
        echo json_encode(["error" => "Formato no permitido. Solo JPG, PNG o PDF"]);
        exit;
    }

    // Generar nombre único para el archivo
    $fileName = "image_{$codigoPedido}_{$randomNumber}.{$extension}"; 
    $filePath = $uploadDir . $fileName;

    // Mover archivo a la carpeta de subida
    if (move_uploaded_file($_FILES['boucher']['tmp_name'], $filePath)) {
        echo json_encode(["mensaje" => "Boucher subido correctamente", "boucher_path" => $fileName]);
    } else {
        echo json_encode(["error" => "Error al mover el archivo"]);
    }
    exit;
}

// Leer JSON del pedido
$data = json_decode(file_get_contents("php://input"), true);
echo json_encode("datos recibidos: "=>$data);
if (!$data || !isset($data['codigo_usuario'], $data['nombre_usuario'], $data['email'], $data['celular'], $data['codigo'], $data['precio_total'], $data['productos'], $data['boucher_path'], $data['metodo_pago'])) {
    echo json_encode(["error" => "Datos incompletos"]);
    exit;
}


$data['fecha_pedido'] = date("Y-m-d H:i:s");
$data['estado'] = "pendiente";

// Conectar a RabbitMQ
try {

    $pedido_data = [
        "codigo"            => $data['codigo'],
        "codigo_usuario"    => $data['codigo_usuario'],
        "nombre_usuario"    => $data['nombre_usuario'],
        "email"             => $data['email'],
        "celular"           => $data['celular'],
        "precio_total"      => $data['precio_total'],
        "productos"         => [],
        "metodo_pago"       => $data['metodo_pago'],
        "boucher_path"      => $data['boucher_path'],
        "direccion_entrega" => $data['direccion_entrega'],
        "fecha_pedido"      => $data['fecha_pedido'],
        "estado"            => $data['estado']
    ];

    foreach ($data['productos'] as $producto) {
        $stmt = $pdo->prepare("SELECT * FROM buscar_producto_por_codigo(?)");
        $stmt->execute([$producto['codigo']]);
        $producto_data = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$producto_data) {
            throw new Exception("Producto no encontrado: " . $producto['codigo']);
        }

        $pedido_data['productos'][] = [
            "codigo_producto" => $producto['codigo'],
            "cantidad"        => $producto['cantidad'],
            "precio_unitario" => $producto_data['precio'],
            "precio_total"    => $producto['cantidad'] * $producto_data['precio']
        ];
    }

    $connection = new AMQPStreamConnection('rabbitmq', 5672, 'guest', 'guest');
    $channel = $connection->channel();

    // Declarar exchange de tipo "direct"
    $exchange = 'pedido_exchange';
    $channel->exchange_declare($exchange, 'direct', false, true, false);

    // Declarar las colas con sus claves de enrutamiento
    $colas = [
        'pedidos'       => 'procesar_pedido',
        'alertas'       => 'enviar_alerta',
        'notificaciones'=> 'enviar_notificacion'
    ];
    
    foreach ($colas as $cola => $routing_key) {
        $channel->queue_declare($cola, false, true, false, false);
        $channel->queue_bind($cola, $exchange, $routing_key);
    }

    // Enviar mensaje a la cola de pedidos (facturación)
    $pedido_msg = new AMQPMessage(json_encode($pedido_data), ['delivery_mode' => AMQPMessage::DELIVERY_MODE_PERSISTENT]);
    $channel->basic_publish($pedido_msg, $exchange, 'procesar_pedido');

    // Definir el umbral de alerta (puede configurarse dinámicamente)
    $umbral_alerta = 1000;

    // Enviar alerta solo si el precio total supera el umbral
    if ($data['precio_total'] > $umbral_alerta) {
        $alerta_data = [
            "tipo_alerta"   => "Pedido de alto valor",
            "codigo"        => $data['codigo'],
            "precio_total"  => $data['precio_total'],
            "nombre_usuario"=> $data['nombre_usuario'],
            "fecha_pedido"  => $data['fecha_pedido']
        ];
        $alerta_msg = new AMQPMessage(json_encode($alerta_data), ['delivery_mode' => AMQPMessage::DELIVERY_MODE_PERSISTENT]);
        $channel->basic_publish($alerta_msg, $exchange, 'enviar_alerta');

        // (Opcional) Guardar alerta en un log local
        file_put_contents(__DIR__ . "/alertas.log", json_encode($alerta_data) . PHP_EOL, FILE_APPEND);
    }

    // Cerrar conexión
    $channel->close();
    $connection->close();
    
    echo json_encode([
        "mensaje" => "Pedido enviado correctamente a RabbitMQ",
        "pedido_enviado" => $pedido_data
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    echo json_encode(["error" => "Error en la conexión con RabbitMQ", "detalle" => $e->getMessage()]);
}
?>
