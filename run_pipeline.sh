#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "============================================================"
echo "  Pipeline ETL - Dashboard Turismo Chile"
echo "============================================================"
echo ""

echo "=== EXTRACT (Python) ==="
echo "Descargando datos desde URLs configuradas en config.yml..."
python extract/main.py

echo ""
echo "=== TRANSFORM (R) ==="
echo "Procesando datos: STL, ARIMA, SARIMAX, unificacion..."
Rscript transform/main.R

echo ""
echo "============================================================"
echo "  Pipeline completado exitosamente."
echo "  Para ejecutar el dashboard:"
echo "    cd dashboard && Rscript -e \"shiny::runApp('.')\""
echo "============================================================"
