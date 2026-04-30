# Proyección Turística - Pipeline Predictivo de Demanda

[![CI](https://github.com/manuelsancristobal/proyeccion-turistica/actions/workflows/ci.yml/badge.svg)](https://github.com/manuelsancristobal/proyeccion-turistica/actions/workflows/ci.yml)

## Contexto
Este fue el primer proyecto que alguna vez desarrollé, empecé en 2022 jugando con Google Colab y con datos de la publicación de llegadas de turistas de Sernatur, haciendo *hard coding*, intentando buscar algún quiebre y así confirmar que los programas de promoción internacional tenían un efecto. Sin embargo, no alcancé a terminarlo para mi tesis de posgrado y tuve que conformarme con una revisión de la literatura. Con el tiempo, aprendí de métodos de descomposición como el STL, y métodos de pronóstico como ARIMA y SARIMAX.

## Impacto y Valor del Proyecto
Este proyecto implementa, a través de un pipeline de datos, un modelo de pronóstico para proyectar la demanda turística de Chile, integrando datos de tráfico aéreo, flujos fronterizos terrestres y microdatos de nacionalidad. Esto te permite anticipar cuellos de botella en pasos fronterizos y aeropuertos regionales con un horizonte de 12-24 meses. Es una herramienta para la priorización de obras públicas y la asignación de recursos en pasos fronterizos.

## Stack Tecnológico
- **Lenguajes**: Python 3.10+ (ETL/Orquestación), R 4.3+ (Modelamiento estadístico).
- **Librerías Clave**: `Pandas`, `PyYAML`, `forecast` (R), `prophet`.
- **Calidad de Código**: `Ruff`, `Pytest`.
- **Infraestructura**: Docker (Entorno híbrido), GitHub Actions.

## Arquitectura de Datos y Metodología
1. **Pipeline de Ingesta**: Extracción multifuente desde portales de datos abiertos de la JAC y Subturismo.
2. **Armonización**: Consolidación de series temporales con diferentes frecuencias y niveles de agregación geográfica.
3. **Modelamiento Híbrido**: Uso de modelos SARIMA y Exponential Smoothing en R para la detección de estacionalidad compleja.
4. **Validación**: Backtesting de proyecciones contra datos reales de los últimos 6 meses.
5. **Visualización**: Generación de reportes automáticos y exportación de proyecciones para dashboards BI.

## Quick Start (Reproducibilidad)
1. `git clone https://github.com/manuelsancristobal/proyeccion-turistica`
2. `make install` (Configura el entorno Python y descarga dependencias R)
3. `make test` (Valida los scripts de extracción y transformación)
4. `make run` (Ejecuta el pipeline completo: Extracción -> Modelo -> Reporte)

## Estructura del Proyecto
- `extract/`: Scripts de extracción y limpieza en Python.
- `transform/`: Lógica de transformación y preparación de variables.
- `scripts/`: Modelos de proyección en R y Python.
- `data/`: Estructura multinivel de datos (`raw/`, `processed/`, `external/`).

---
**Autor**: Manuel San Cristóbal Opazo 
**Licencia**: MIT
