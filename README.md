# Proyección Turística - Pipeline Predictivo de Demanda

## 🎯 Impacto y Valor del Proyecto
Este proyecto implementa un pipeline de datos robusto para proyectar la demanda turística de Chile, integrando datos de tráfico aéreo, flujos fronterizos terrestres y microdatos de nacionalidad. La solución permite anticipar cuellos de botella en pasos fronterizos y aeropuertos regionales con un horizonte de 12-24 meses. Es una herramienta crítica para la Subsecretaría de Turismo y el MOP en la priorización de obras públicas y la asignación de recursos consulares y de seguridad.

## 🛠️ Stack Tecnológico
- **Lenguajes**: Python 3.10+ (ETL/Orquestación), R 4.3+ (Modelamiento estadístico).
- **Librerías Clave**: `Pandas`, `PyYAML`, `forecast` (R), `prophet`.
- **Calidad de Código**: `Ruff`, `Pytest`.
- **Infraestructura**: Docker (Entorno híbrido), GitHub Actions.

## 📊 Arquitectura de Datos y Metodología
1. **Pipeline de Ingesta**: Extracción multifuente desde portales de datos abiertos de la JAC y Subturismo.
2. **Armonización**: Consolidación de series temporales con diferentes frecuencias y niveles de agregación geográfica.
3. **Modelamiento Híbrido**: Uso de modelos SARIMA y Exponential Smoothing en R para la detección de estacionalidad compleja.
4. **Validación**: Backtesting de proyecciones contra datos reales de los últimos 6 meses.
5. **Visualización**: Generación de reportes automáticos y exportación de proyecciones para dashboards BI.

## 🚀 Quick Start (Reproducibilidad)
1. `git clone https://github.com/manuelsancristobal/proyeccion-turistica`
2. `make install` (Configura el entorno Python y descarga dependencias R)
3. `make test` (Valida los scripts de extracción y transformación)
4. `make run` (Ejecuta el pipeline completo: Extracción -> Modelo -> Reporte)

## 📂 Estructura del Proyecto
- `extract/`: Scripts de extracción y limpieza en Python.
- `transform/`: Lógica de transformación y preparación de variables.
- `scripts/`: Modelos de proyección en R y Python.
- `data/`: Estructura multinivel de datos (`raw/`, `processed/`, `external/`).

---
**Autor**: Manuel San Cristóbal  
**Licencia**: MIT
