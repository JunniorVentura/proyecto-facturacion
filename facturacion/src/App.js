import React, { useEffect, useState } from "react";
import axios from "axios";
import "./style.css";

const BASE_URL = "http://localhost:5000";
const BASE_URL_IMAGE = "http://localhost:9090";

function App() {
    const [pedidos, setPedidos] = useState([]);
    const [productosPorPedido, setProductosPorPedido] = useState({});
    const [error, setError] = useState(null);
    const [estados, setEstados] = useState({});
    const [tipoComprobantes, setTipoComprobantes] = useState({});

    const fetchPedidos = async () => {
        try {
            const response = await axios.get(`${BASE_URL}/pedidos`);
            if (Array.isArray(response.data)) {
                const pedidosData = response.data;
                
                const productosPromises = pedidosData.map(pedido =>
                    axios.get(`${BASE_URL}/detalles_pedido/${pedido.codigo}`)
                        .then(res => ({ codigo: pedido.codigo, productos: res.data }))
                        .catch(() => ({ codigo: pedido.codigo, productos: [] }))
                );

                const productosResultados = await Promise.all(productosPromises);
                const productosMap = productosResultados.reduce((acc, item) => ({
                    ...acc, [item.codigo]: item.productos
                }), {});
                setPedidos(pedidosData);
                setProductosPorPedido(productosMap);
                setEstados(pedidosData.reduce((acc, p) => ({
                    ...acc, [p.codigo]: p.estado || "pendiente"
                }), {}));
                setTipoComprobantes(pedidosData.reduce((acc, p) => ({
                    ...acc, [p.codigo]: p.tipo_comprobante || ""
                }), {}));

                setError(null);
            } else {
                throw new Error("Datos incorrectos recibidos");
            }
        } catch (error) {
            console.error("Error al obtener pedidos:", error);
            setError("No se pudieron cargar los pedidos.");
        }
    };
    
    useEffect(() => {
        fetchPedidos();
    }, []);

    const cambiarEstadoPedido = async (codigoPedido) => {
        const nuevoEstado = estados[codigoPedido];
        const tipoComprobante = tipoComprobantes[codigoPedido];

        if (nuevoEstado === "verificado" && (!tipoComprobante || tipoComprobante === "")) {
            alert("Debe seleccionar un tipo de comprobante antes de verificar el pedido.");
            return;
        }

        try {
            const response = await axios.put(
                `${BASE_URL}/pedidos/${codigoPedido}`,
                JSON.stringify({ estado: nuevoEstado, tipo_comprobante: tipoComprobantes[codigoPedido] }),
                { headers: { 'Content-Type': 'application/json' } }
            );      

            if (response.status === 200) {
                alert("Estado actualizado correctamente.");
                fetchPedidos();
            } else {
                alert("Error al actualizar el estado.");
            }
        } catch (error) {
            alert("Error al cambiar el estado.");
        }
    };

    const generarReporte = async () => {
        try {
            const response = await fetch(`${BASE_URL}/generar_reporte`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
            });
    
            const data = await response.json();
            if (!response.ok) throw new Error(data.error || "Error desconocido");
            
            alert(data.mensaje);
        } catch (error) {
            console.error("Error generando el reporte:", error);
            alert(`Error: ${error.message}`);
        }
    };
    
    return (
        <div className="container">
            <h1>Facturación</h1>
            {error && <p style={{ color: 'red' }}>{error}</p>}
            {pedidos.length === 0 ? (
                <div className="container-lista-pedidos">No hay pedidos.</div>
            ) : (
                <div className="container-lista-pedidos">
                    {pedidos.map((p, index) => (
                        <div key={index}  className="pedido-container">
                            <div className="item-pedido"><strong>Pedido:</strong> {p.codigo}</div>
                            <div className="item-pedido"><strong>Usuario ID:</strong> {p.usuario_id}</div>
                            <div className="item-pedido"><strong>Usuario Nombre:</strong> {p.nombre_usuario}</div>
                            <div className="item-pedido"><strong>Total:</strong> S/.{p.precio_total}</div>
                            <div className="item-pedido"><strong>Dirección de Envío:</strong> {p.direccion_entrega}</div>
                            <div className="item-pedido"><strong>Fecha del pedido:</strong> {p.fecha_pedido}</div>
                            <div className="item-pedido"><strong>Productos:</strong></div>
                            <div className="list-products">
                                {productosPorPedido[p.codigo]?.map((prod, idx) => (
                                    <div className="item-producto" key={idx}>
                                    <div className="product"><strong>Producto:</strong> {prod.nombre}</div>
                                    <div className="count"><strong>Cantidad:</strong> {prod.cantidad}</div>
                                    <div className="price"><strong>Precio Unitario:</strong> S/.{prod.precio}</div>
                                    <div className="total"><strong>Precio Total:</strong> S/.{prod.precio_total/prod.cantidad}</div>
                                    </div>
                                )) || <div>No hay productos</div>}
                            </div>
                            <div className="item-pedido"><strong>Método de Pago:</strong> {p.metodo_pago}</div>
                            {p.boucher_path && p.boucher_path !== "No disponible" ? (
                               <div className="item-pedido">
                                    <label>Foto del Pago:</label>
                                    <img src={`${BASE_URL_IMAGE}/bouchers/${p.boucher_path}`} alt="Boucher" width="200" />
                                </div> 
                            ) : <div className="item-pedido"><label>Foto del Pago:</label> <div>No disponible</div></div>}
                            
                            <div className="item-pedido">
                                <strong>Estado:</strong>
                                <div className={
                                    p.estado === "verificado" ? "status-verificado" :
                                    p.estado === "rechazado" ? "status-rechazado" :
                                    "status-pendiente"
                                }>
                                    {p.estado}
                                </div>
                            </div>

                            {p.tipo_comprobante ? (
                            <div className="item-pedido"><strong>Tipo de Comprobante:</strong> {p.tipo_comprobante}</div>
                            ) : null}
                            {p.estado === "pendiente" && (
                                <div className="container-comprobante">
                                    <div className="item-pedido">
                                        <label>Tipo de Comprobante: </label>
                                        <select 
                                            value={tipoComprobantes[p.codigo] || ""} 
                                            onChange={(e) => setTipoComprobantes({
                                                ...tipoComprobantes,
                                                [p.codigo]: e.target.value
                                            })}
                                        >
                                            <option value="">Seleccionar</option>
                                            <option value="boleta">Boleta</option>
                                            <option value="factura">Factura</option>
                                        </select>
                                    </div> 
                                    <div className="item-pedido">
                                    <label>Estado: </label>
                                        <select 
                                            value={estados[p.codigo]} 
                                            onChange={(e) => setEstados({
                                                ...estados,
                                                [p.codigo]: e.target.value
                                            })}
                                        >
                                            <option value="pendiente">Pendiente</option>
                                            <option value="verificado">Verificado</option>
                                            <option value="rechazado">Rechazado</option>
                                        </select>
                                    </div> 
                                    <button onClick={() => cambiarEstadoPedido(p.codigo)}>Actualizar</button>
                                </div>
                            )}
                        </div>
                    ))}
                    <div className="reporte-container"><button onClick={generarReporte}>Generar Reporte</button></div>
                </div>
            )}
        </div>
    );
}

export default App;
