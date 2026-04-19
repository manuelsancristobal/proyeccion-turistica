# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

## [1.0.0] - 2025

### Added
- Pipeline ETL completo: Extract (Python) + Transform (R)
- Dashboard interactivo con R Shiny (3 módulos: Analítica, Llegadas, Salidas)
- Modelos de pronóstico ARIMA y SARIMAX con variable dummy pandémica
- Descomposición STL de series temporales
- Exportación de gráficos estáticos para portafolio (`export_charts.R`)
- Deploy automatizado a shinyapps.io (`deploy.R`)
- Deploy a portafolio Jekyll (`scripts/deploy_jekyll.py`)
- Tests para capa Extract con pytest
- CI con GitHub Actions
- Pre-commit hooks (ruff, hooks estándar)
