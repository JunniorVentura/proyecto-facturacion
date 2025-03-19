import React, { useState, useEffect } from 'react';

const API_URL = "http://localhost:7000";

function App() {
  const [reportesPdf, setReportesPdf] = useState([]);
  const [reportesExcel, setReportesExcel] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchReportes = async () => {
      try {
        const response = await fetch(`${API_URL}/reports`);
        if (!response.ok) throw new Error("Error al obtener reportes");

        const data = await response.json();
        setReportesPdf(data.filter(file => file.endsWith('.pdf')));
        setReportesExcel(data.filter(file => file.endsWith('.xlsx')));
      } catch (error) {
        console.error("Error:", error);
        setError("No se pudieron cargar los reportes.");
      }
    };

    fetchReportes();
    const interval = setInterval(fetchReportes, 10000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h1>Reportes Generados</h1>
      {error && <p style={{ color: 'red' }}>{error}</p>}

      <h2>Reportes PDF</h2>
      {reportesPdf.length === 0 && !error ? <p>No hay reportes en PDF.</p> : null}
      <ul>
        {reportesPdf.map((reporte, index) => (
          <li key={index}>
            <a href={`${API_URL}/reports/${reporte}`} target="_blank" rel="noopener noreferrer">
              Descargar {reporte}
            </a>
          </li>
        ))}
      </ul>

      <h2>Reportes Excel</h2>
      {reportesExcel.length === 0 && !error ? <p>No hay reportes en Excel.</p> : null}
      <ul>
        {reportesExcel.map((reporte, index) => (
          <li key={index}>
            <a href={`${API_URL}/reports/${reporte}`} target="_blank" rel="noopener noreferrer">
              Descargar {reporte}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default App;
