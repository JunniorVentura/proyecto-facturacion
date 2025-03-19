import React, { useRef, useEffect, useState } from "react";
import axios from "axios";
import "./style.css";

const BASE_URL = "http://localhost:9090";

function App() {
    const [usuarios, setUsuarios] = useState([]);
    const [productosDisponibles, setProductosDisponibles] = useState([]);
    const [codigoUsuario, setCodigoUsuario] = useState("");
    const [usuarioSeleccionado, setUsuarioSeleccionado] = useState(null);
    const [codigoPedido, setCodigoPedido] = useState("");
    const [productos, setProductos] = useState([]);
    const [productoSeleccionado, setProductoSeleccionado] = useState(null);
    const [cantidad, setCantidad] = useState(1);
    const [boucher, setBoucher] = useState(null);
    const [loading, setLoading] = useState(false);
    const [totalPedido, setTotalPedido] = useState(0);
    const [usuarioCodigoSearch, setUsuarioCodigoSearch] = useState("");
    const [usuarioDniSearch, setUsuarioDniSearch] = useState("");
    const [usuarioRucSearch, setUsuarioRucSearch] = useState("");
    const [productoCodigoSearch, setProductoCodigoSearch] = useState("");
    const [productoNombreSearch, setProductoNombreSearch] = useState("");
    const selectRef = useRef(null);
    const selectRefUser = useRef(null);
    const [metodoPago, setMetodoPago] = useState("");
    const [boucherUrl, setBoucherUrl] = useState(null);

    useEffect(() => {
        const cargarDatos = async () => {
            try {
                const [usuariosRes, productosRes, codigoRes] = await Promise.all([
                    axios.get(`${BASE_URL}/producer.php?usuarios`),
                    axios.get(`${BASE_URL}/producer.php?productos`),
                    axios.get(`${BASE_URL}/producer.php?ultimo_codigo_pedido`)
                ]);

                setUsuarios(Array.isArray(usuariosRes.data) ? usuariosRes.data : []);
                setProductosDisponibles(Array.isArray(productosRes.data) ? productosRes.data : []);
                setCodigoPedido(
                    codigoRes.data?.ultimo_codigo ? codigoRes.data.ultimo_codigo : "PED0001"
                );       
            } catch (error) {
                console.error("Error cargando datos:", error);
                alert("Error al cargar los datos.");
                setUsuarios([]);
                setProductosDisponibles([]);
            }
        };

        cargarDatos();
    }, []);

    useEffect(() => {
        const nuevoTotal = productos.reduce((total, p) => total + p.precioTotal, 0);
        setTotalPedido(nuevoTotal);
    }, [productos]);

    const handleBoucherChange = (event) => {
        const file = event.target.files[0];
        if (file) {
            setBoucher(file);
            setBoucherUrl(URL.createObjectURL(file)); // Previsualización antes de subir
        }
    };

    const handleUsuarioChange = async (codigo) => {
        setCodigoUsuario(codigo);
    
        try {
            if (!codigo) {
                setUsuarioSeleccionado(null); // Si no hay selección, limpiar el estado
                return;
            }
    
            const res = await axios.get(`${BASE_URL}/producer.php?usuario_codigo_search=${codigo}`);
            
            console.log("Respuesta API:", res.data); // Ver qué devuelve la API
            
            if (Array.isArray(res.data)) {
                setUsuarioSeleccionado(res.data.length > 0 ? res.data[0] : null);
            } else {
                setUsuarioSeleccionado(res.data);
            }
        } catch (error) {
            console.error("Error obteniendo usuario:", error);
            setUsuarioSeleccionado(null);
        }
    };
    
    const handleProductoChange = async (codigo) => {
        try {
            if (!codigo) {
                setProductoSeleccionado(null); // Si no hay selección, limpiar el estado
                return;
            }
    
            const res = await axios.get(`${BASE_URL}/producer.php?producto_codigo_search=${codigo}`);
            
            console.log("Respuesta API:", res.data); // Ver qué devuelve la API
    
            if (Array.isArray(res.data)) {
                setProductoSeleccionado(res.data.length > 0 ? res.data[0] : null);
            } else {
                setProductoSeleccionado(res.data);
            }
        } catch (error) {
            console.error("Error obteniendo producto:", error);
            setProductoSeleccionado(null);
        }
    };
    
    const buscarUsuario = async (tipo, valor) => {
        if (!valor) {
            alert("Ingrese un valor de búsqueda");
            return;
        }
    
        let queryParam;
        switch (tipo) {
            case "codigo":
                queryParam = `usuario_codigo_search=${valor}`;
                setUsuarioDniSearch('');
                setUsuarioRucSearch('');
                break;
            case "dni":
                queryParam = `usuario_dni_search=${valor}`;
                setUsuarioCodigoSearch('');
                setUsuarioRucSearch('');
                break;
            case "ruc":
                queryParam = `usuario_ruc_search=${valor}`;
                setUsuarioCodigoSearch('');
                setUsuarioDniSearch('');
                break;
            default:
                alert("Tipo de búsqueda no válido");
                return;
        }
    
        try {
            const response = await fetch(`${BASE_URL}/producer.php?${queryParam}`);
            const data = await response.json();
    
            if (!data || data.length === 0) {
                alert("No se encontraron usuarios con ese criterio");
                setUsuarios([]);
                setUsuarioSeleccionado(null);
            } else {
                setUsuarios(data);
                if (data.length === 1) {
                    setUsuarioSeleccionado(data[0]); // Asignar el usuario encontrado
                    setCodigoUsuario(data[0].codigo); // Asegurar que el select lo tome
                }
            }
            // Desplegar automáticamente el select
            setTimeout(() => {
                if (selectRefUser.current) {
                    selectRefUser.current.focus(); // Enfocar el select
                }
            }, 0);
        } catch (error) {
            console.error("Error al buscar usuario:", error);
            alert("Hubo un error al buscar el usuario");
        }
    };
    
    
    const buscarProducto = async (tipo, valor) => {
        if (!valor) {
            alert("Ingrese un valor de búsqueda");
            return;
        }
    
        let queryParam;
        switch (tipo) {
            case "codigo":
                queryParam = `producto_codigo_search=${valor}`;
                setProductoNombreSearch('');
                break;
            case "nombre":
                queryParam = `producto_nombre_search=${valor}`;
                setProductoCodigoSearch('');
                break;
            default:
                alert("Tipo de búsqueda no válido");
                return;
        }
    
        try {
            const response = await fetch(`${BASE_URL}/producer.php?${queryParam}`);
            const data = await response.json();
    
            if (!data || data.length === 0) {
                alert("No se encontraron productos con ese criterio");
                setProductosDisponibles([]);
            } else {
                setProductosDisponibles(data);
            }
            // Desplegar automáticamente el select
            setTimeout(() => {
                if (selectRef.current) {
                    selectRef.current.focus(); // Enfocar el select
                }
            }, 0);
        } catch (error) {
            console.error("Error al buscar producto:", error);
            alert("Hubo un error al buscar el producto");
        }
    };
    

    const agregarProducto = () => {
        if (!productoSeleccionado || cantidad < 1) {
            alert("Seleccione un producto y una cantidad válida.");
            return;
        }
    
        // Verifica si `productoSeleccionado` es un array y extrae el primer elemento
        const producto = Array.isArray(productoSeleccionado) ? productoSeleccionado[0] : productoSeleccionado;
        
        if (producto.stock < cantidad) {
            alert(`No hay stock disponible.\nSolamente tenemos ${producto.stock} unidades en stock.`);
            return;
        }       

        if (productos.find(p => p.codigo === producto.codigo)) {
            alert("El producto ya está agregado.");
            return;
        }
    
        const precioNumerico = parseFloat(producto.precio); // Convertir a número
    
        if (isNaN(precioNumerico)) {
            alert("Error: El precio del producto no es válido.");
            console.error("Precio inválido:", producto.precio);
            return;
        }
    
        const nuevoProducto = {
            ...producto,
            cantidad,
            precioTotal: precioNumerico * cantidad
        };
    
        setProductos(productos => [...productos, nuevoProducto]);
        setProductoSeleccionado(null);
        setCantidad(1);
    };
    

    const eliminarProducto = (codigo) => {
        setProductos(productos.filter(p => p.codigo !== codigo));
    };

    const enviarPedido = async () => {
        if (!codigoUsuario || !codigoPedido || productos.length === 0 || !boucher) {
            alert("Debe completar todos los campos.");
            return;
        }

        setLoading(true);

        try {
            const formData = new FormData();
            formData.append("boucher", boucher);
            formData.append("codigo", codigoPedido);
            formData.forEach((value, key) => {
                console.log("Clave:", key, "Valor:", value);
            });
            
            if (!boucher || !(boucher instanceof File)) {
                console.error("El archivo boucher no es válido.");
                return;
            }        

            console.log("Enviando FormData a producer.php...");
            const boucherResponse = await axios.post(`${BASE_URL}/producer.php`, formData, {
                headers: { "Content-Type": "multipart/form-data" },
            });
            console.log("Respuesta del servidor:", boucherResponse.data);           

            if (!boucherResponse.data.boucher_path) {
                alert("Error al subir el boucher.");
                setLoading(false);
                return;
            }
            setBoucherUrl(`${BASE_URL}/${boucherResponse.data.boucher_path}`); // URL final del boucher

            const pedido = {
                codigo: codigoPedido,
                codigo_usuario: codigoUsuario,
                nombre_usuario: usuarioSeleccionado.nombre,
                email: usuarioSeleccionado.email,
                celular: usuarioSeleccionado.celular,
                precio_total: totalPedido,
                productos,
                boucher_path: boucherResponse.data.boucher_path,
                metodo_pago: metodoPago,
                direccion_entrega: usuarioSeleccionado.direccion,
                fecha_pedido: new Date().toISOString().split("T")[0],
                estado: "pendiente"
            };

            const pedidoResponse = await axios.post(`${BASE_URL}/producer.php`, pedido, {
                headers: { "Content-Type": "application/json" },
            });

            if (pedidoResponse.data.error) {
                alert("Error al enviar el pedido.");
            } else {
                alert("Pedido enviado correctamente.");
                setCodigoUsuario("");
                setUsuarioSeleccionado(null);
                setProductoSeleccionado(null);
                setProductos([]);
                setBoucher(null);
                setMetodoPago(null);
                setBoucherUrl(null);
                setCodigoPedido((codigoPedido) => {
                    const num = parseInt(codigoPedido.replace(/\D/g, ""), 10) || 1000;
                    return `PED${String(num + 1).padStart(4, "0")}`;
                });
                setUsuarioCodigoSearch('');
                setUsuarioDniSearch('');
                setUsuarioRucSearch('');
                setProductoCodigoSearch('');
                setProductoNombreSearch('');
            }
        } catch (error) {
            console.error("Error al enviar el pedido:", error);
            alert("Hubo un problema al procesar el pedido.");
        }

        setLoading(false);
    };


    return (
        <div className="container">
        <h1>Tienda</h1>
        <label>Código de Pedido:</label>
        <input disabled type="text" value={codigoPedido} onChange={(e) => setCodigoPedido(e.target.value)} />
        <div className="container-search-user">
            {/* Búsqueda de Usuarios */}
            <label>Buscar Usuario por:</label>
            <div className="item-search">
                <div className="data-search">
                    <input
                        type="text"
                        placeholder="Código"
                        value={usuarioCodigoSearch}
                        onChange={(e) => setUsuarioCodigoSearch(e.target.value)}
                    />
                </div>
                <div className="btn-search">
                    <button onClick={() => buscarUsuario('codigo', usuarioCodigoSearch)}>Buscar</button>
                </div>
            </div>
            <div className="item-search">
                <div className="data-search">
                    <input
                        type="text"
                        placeholder="DNI"
                        value={usuarioDniSearch}
                        onChange={(e) => setUsuarioDniSearch(e.target.value)}
                    />
                </div>
                <div className="btn-search">
                    <button onClick={() => buscarUsuario('dni', usuarioDniSearch)}>Buscar</button>
                </div>
            </div>
            <div className="item-search">
                <div className="data-search">
                    <input
                        type="text"
                        placeholder="RUC"
                        value={usuarioRucSearch}
                        onChange={(e) => setUsuarioRucSearch(e.target.value)}
                    />
                </div>
                <div className="btn-search">
                    <button onClick={() => buscarUsuario('ruc', usuarioRucSearch)}>Buscar</button>
                </div>
            </div>

            {/* Lista de Usuarios */}
            <label>Usuario:</label>
            <select ref={selectRefUser} value={codigoUsuario} onChange={(e) => handleUsuarioChange(e.target.value)}>
                <option value="">Seleccione un usuario</option>
                {usuarios.map((u) => (
                    <option key={u.codigo} value={u.codigo}>
                        {u.nombre} ({u.email} - {u.celular})
                    </option>
                ))}
            </select>
        </div>
        <div className="container-user-data">
            {/* Mostrar los datos del usuario seleccionado después de la búsqueda */}
            {usuarioSeleccionado && (
                <div>
                    <p><strong>Código:</strong> {usuarioSeleccionado.codigo}</p>
                    <p><strong>Nombre:</strong> {usuarioSeleccionado.nombre}</p>
                    <p><strong>Email:</strong> {usuarioSeleccionado.email}</p>
                    <p><strong>Celular:</strong> {usuarioSeleccionado.celular}</p>
                    <p><strong>DNI:</strong> {usuarioSeleccionado.dni}</p>
                    <p><strong>RUC:</strong> {usuarioSeleccionado.ruc}</p>
                    <p><strong>Dirección de Envío:</strong> {usuarioSeleccionado.direccion}</p>
                    <br></br>
                </div>
            )}
        </div>
        <div className="container-search-product">
            {/* Búsqueda de Productos */}
            <label>Buscar Producto por:</label>

            <div className="item-search">
                <div className="data-search">
                    <input
                        type="text"
                        placeholder="Código"
                        value={productoCodigoSearch}
                        onChange={(e) => setProductoCodigoSearch(e.target.value)}
                    />
                </div>
                <div className="btn-search">
                    <button onClick={() => buscarProducto('codigo', productoCodigoSearch)}>Buscar</button>
                </div>
            </div>

            <div className="item-search">
                <div className="data-search">
                    <input
                        type="text"
                        placeholder="Nombre"
                        value={productoNombreSearch}
                        onChange={(e) => setProductoNombreSearch(e.target.value)}
                    />
                </div>
                <div className="btn-search">
                    <button onClick={() => buscarProducto('nombre', productoNombreSearch)}>Buscar</button>
                </div>
            </div>
            <div className="item-data-select">
                {/* Lista de Productos */}
                <h2>Seleccionar Producto</h2>
                <select ref={selectRef} value={productoSeleccionado?.codigo || ""} onChange={(e) => handleProductoChange(e.target.value)}>
                    <option value="">Seleccione un producto</option>
                    {productosDisponibles.map((p) => (
                        <option key={p.codigo} value={p.codigo}>{p.nombre} - S/.{p.precio} - {p.stock} unidades</option>
                    ))}
                </select>
            
                <input 
                    type="number" 
                    min="1" 
                    value={cantidad} 
                    onChange={(e) => setCantidad(parseInt(e.target.value) || 1)} 
                    placeholder="Cantidad" 
                />
            </div>
        
            <button onClick={agregarProducto} disabled={!productoSeleccionado}>
                Agregar Producto
            </button>
        </div>
        <div className="container-pedido">
            <h2>Pedido</h2>
            {productos.length === 0 ? <p>No hay productos en el pedido.</p> : (
                <div className="list-pedido">
                    {productos.map((p, index) => (
                        <div className="item-pedido" key={p.codigo || index}>
                            <div className="product"><strong>Producto:</strong> {p.nombre}</div>
                            <div className="count"><strong>Cantidad:</strong> {p.cantidad}</div>
                            <div className="price"><strong>Precio Unitario:</strong> S/.{p.precio}</div>
                            <div className="total"><strong>Precio Total:</strong> S/.{p.precioTotal}</div>
                            <div className="delete-item"><button onClick={() => eliminarProducto(p.codigo)}>Eliminar</button></div>
                        </div>
                    ))}
                </div>

            )}
        
            <h3>Total del Pedido: <strong>S/.{totalPedido.toFixed(2)}</strong></h3>
        </div>
        <div className="container-pay">
            <label>Método de Pago:</label>
            <select value={metodoPago || ""} onChange={(e) => setMetodoPago(e.target.value)}>
                <option value="">Seleccione un método de pago</option>
                <option value="deposito">Depósito</option>
                <option value="transferencia">Transferencia</option>
                <option value="yape">Yape</option>
                <option value="plin">Plin</option>
            </select>

            <label>Subir Foto del Pago:</label>
            <input type="file" accept="image/*" onChange={handleBoucherChange} />

            {boucherUrl && (
                <div>
                    <p>Boucher subido:</p>
                    <img src={boucherUrl} alt="Boucher" style={{ width: "200px", border: "1px solid #ddd", marginTop: "10px" }} />
                </div>
            )}
        </div>

        <button onClick={enviarPedido} disabled={loading || !boucher}>
            {loading ? "Enviando..." : "Enviar Pedido"}
        </button>
    </div>    
    );
}

export default App;
