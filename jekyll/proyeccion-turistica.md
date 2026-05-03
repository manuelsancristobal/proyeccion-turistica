---
layout: project
title: "Proyección Turística Chile"
category: Estadística e Inferencia
description: Dashboard interactivo con modelado estadístico para proyectar flujos turísticos de Chile, integrando datos de SERNATUR y la Junta Aeronáutica Civil.
github_url: "https://github.com/manuelsancristobal/proyeccion-turistica"
tech_stack:
  - Python
  - R
  - R Shiny
  - ARIMA
  - SARIMAX
---

## Dinámicas de Recuperación y Crecimiento

**La recuperación del flujo turístico en Chile ha superado los niveles previos a la pandemia, manteniendo una tendencia de crecimiento constante.** Como se aprecia en la visualización de proyecciones, tanto el flujo de residentes al extranjero como la llegada de turistas internacionales muestran una trayectoria alcista sólida para los próximos meses.

## Dashboard Interactivo de Pronósticos

Explora las proyecciones de turismo emisivo y receptivo con filtros dinámicos y modelos estadísticos avanzados.

<div style="position: relative; width: 100%; padding-bottom: 75%; overflow: hidden; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
  <iframe
    src="https://manuel-san-cristobal-opazo.shinyapps.io/dashboard/"
    style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none;"
    loading="lazy"
    title="Dashboard de Proyección Turística Chile"
    allowfullscreen>
  </iframe>
</div>

<p style="font-size: 12px; color: #999; margin-top: 8px; text-align: center;">
  Si la aplicación interactiva no carga por límite de cuota, los gráficos estáticos de análisis resumen los hallazgos de modo directo.
</p>

## Análisis de Series Temporales

### Proyección de Salidas de Residentes
**Los modelos ARIMA y SARIMAX confirman la consolidación de la tendencia alcista tras el impacto sanitario.** Como se aprecia en el gráfico de proyecciones, el modelo SARIMAX mejora la precisión al integrar el periodo pandémico de forma específica. La recuperación no solo es total, sino que marca nuevos récords de flujo mes a mes.

![Salidas de residentes con tendencia y proyecciones ARIMA/SARIMAX](./assets/charts/01_salidas_proyeccion.png)

---

### Concentración de Mercados Emisores
**Argentina lidera con fuerza el volumen de llegadas, mientras otros mercados regionales muestran ritmos de recuperación dispares.** Como se observa en la comparativa de nacionalidades, la base de visitantes hacia Chile posee una dependencia elevada del mercado regional, lo que plantea desafíos y oportunidades de diversificación.

![Top 5 mercados emisores de turistas hacia Chile](./assets/charts/02_llegadas_nacionalidad.png)

---

### Capacidad y Oferta Aérea
El incremento en la frecuencia de vuelos, impulsado por operadores de bajo costo, actúa como motor de la demanda turística. Como se aprecia en la visualización con suavizado LOESS, el número de operaciones internacionales refleja un cambio de estructura en la industria. Este fenómeno de apertura competitiva, detallado en el análisis de concentración del [**Bar Chart Race: Movimiento Aéreo**](/proyectos/barchart-race/), facilita la estabilidad de los flujos y mejora la precisión de los pronósticos de largo plazo.

![Frecuencia de vuelos internacionales salientes con suavizado LOESS](./assets/charts/03_frecuencia_vuelos.png)

---

### Saturación y Ocupación Aeroportuaria
**Los aeropuertos operan de forma constante con factores de ocupación superiores al 85%, indicando una presión sobre la capacidad actual.** Como se vio en el gráfico de load factor, estos niveles críticos señalan ventanas de oportunidad para la apertura de nuevas rutas o el aumento de frecuencias en nodos estratégicos.

![Factor de ocupación de los principales aeropuertos](./assets/charts/04_load_factor.png)

---

### Patrones de Estacionalidad
**Enero, febrero y julio se consolidan como los periodos de mayor flujo, con una amplitud estacional que crece año tras año.** Como se aprecia en el mapa de calor (heatmap), existe un patrón recurrente de peaks en el verano austral y las vacaciones de invierno. Los años de restricciones sanitarias destacan de forma visual como franjas de baja intensidad.

![Heatmap de estacionalidad de salidas de residentes](./assets/charts/05_estacionalidad.png)

---

## Metodología del Pipeline ETL

Este proyecto implementa un ciclo de datos completo:

- **Extracción** (Python): Descarga de forma automática desde SERNATUR y la Junta Aeronáutica Civil.
- **Transformación** (R): Descomposición STL, modelos de pronóstico a 6 meses y cálculo de métricas de concentración de mercado.
- **Visualización** (R Shiny): Interfaz con módulos para la analítica de mercados y flujos.
