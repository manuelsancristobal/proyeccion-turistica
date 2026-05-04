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

## Dashboard Interactivo: Dinámicas de Recuperación y Crecimiento

**La recuperación del flujo turístico en Chile ha superado los niveles previos a la pandemia, manteniendo una tendencia de crecimiento constante.** Como se aprecia en la visualización de proyecciones, tanto el flujo de residentes al extranjero como la llegada de turistas internacionales muestran una trayectoria alcista sólida para los próximos meses.

Puedes acceder al dashboard en pantalla completa [**en Shinyapps**](https://manuel-san-cristobal-opazo.shinyapps.io/dashboard/).

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
  Si la aplicación interactiva no carga, puede ser por límite de cuota.
</p>

## Análisis de Series Temporales

### Proyección de Salidas de Residentes
**Los modelos ARIMA y SARIMAX confirman la consolidación de la tendencia al alza tras el impacto sanitario.** Como se aprecia en el gráfico de proyecciones, el modelo SARIMAX mejora la precisión al integrar tanto el periodo pandémico (marzo 2020 y septiembre 2020), como el periodo de rehabilitación (octubre 2020 y septiembre 2022), como variables exógenas. La recuperación no solo es total, sino que marca nuevos récords de flujo.

![Salidas de residentes con tendencia y proyecciones ARIMA/SARIMAX](./assets/charts/01_salidas_proyeccion.png)

---

### Concentración de Mercados Emisores
**Argentina lidera con fuerza el volumen de llegadas, mientras otros mercados regionales muestran ritmos de recuperación dispares.** Como se observa a continuación, en la comparativa de nacionalidades, la base de visitantes hacia Chile posee una dependencia elevada del mercado regional (América del Sur), lo que plantea desafíos y oportunidades de diversificación.

![Top 5 mercados emisores de turistas hacia Chile](./assets/charts/02_llegadas_nacionalidad.png)

---

### Capacidad y Oferta Aérea

La reestructuración en la frecuencia de vuelos, acelerada por la entrada de operadores de bajo en 2012, refleja una consolidación de la oferta aérea internacional. Como se aprecia en la visualización de Frecuencia de vuelos internacionales salientes, las operaciones mensuales han descendido desde su máximo histórico de los años noventa para estabilizarse en torno a las 120 mensuales, mientras el volumen de pasajeros se ha cuadruplicado (pasando de ~440 pasajeros por operación en 1998 a más de 4.400 en 2025). Este fenómeno de consolidación operativa de las aerolíneas (menos vuelos pero con mayor capacidad por aeronave), también detallado en el análisis de concentración del [**Bar Chart Race: Movimiento Aéreo**](/proyectos/barchart-race/), redefine la estructura de los flujos aéreos y su impacto en los pronósticos de largo plazo.

![Frecuencia de vuelos internacionales salientes con suavizado LOESS](./assets/charts/03_frecuencia_vuelos.png)

---

### Saturación y Ocupación Aeroportuaria
**Los aeropuertos operan de forma constante con factores de ocupación superiores al 85%, indicando una presión sobre la capacidad actual.** Como se puede apreciar en el grafico a continuación, estos niveles críticos señalan ventanas de oportunidad para la apertura de nuevas rutas o el aumento de frecuencias en rutas estratégicas.

![Factor de ocupación de los principales aeropuertos](./assets/charts/04_load_factor.png)

---

### Patrones de Estacionalidad
**Enero, febrero y julio se consolidan como los periodos de mayor flujo de pasajeros salientes, con una amplitud estacional que crece año tras año.** Como se aprecia en el mapa de calor (heatmap), existe un patrón recurrente de peaks en el verano austral y las vacaciones de invierno. Los años de restricciones sanitarias destacan de forma visual como franjas de baja intensidad.

![Heatmap de estacionalidad de salidas de residentes](./assets/charts/05_estacionalidad.png)

---

## Metodología del Pipeline ETL

Este proyecto implementa un ciclo de datos completo:

- **Extracción** (Python): Descarga de forma automática desde SERNATUR y la Junta Aeronáutica Civil.
- **Transformación** (R): Descomposición STL, modelos de pronóstico a 6 meses y cálculo de métricas de concentración de mercado.
- **Visualización** (R Shiny): Interfaz con módulos para la analítica de mercados y flujos.

<div class="methodology-box" style="margin-top: 2rem; padding: 1.5rem; background: var(--bg-light); border-radius: 8px; border-left: 4px solid var(--secondary);">
    <p style="margin: 0; font-size: 0.95rem;">📌 <strong>Sobre este proyecto:</strong> Esta es la versión rediseñada como aplicación interactiva. Los notebooks originales de 2022 están disponibles en Google Colab: <a href="https://colab.research.google.com/drive/1Is_3GIrlJLED5RO1xru1mXwDfVh3MRJG" target="_blank" style="color: var(--secondary); font-weight: 600;">Proyección 1</a> y <a href="https://colab.research.google.com/drive/1mnK0N87kra2KKewGlCh-VOCaK0boHSaW" target="_blank" style="color: var(--secondary); font-weight: 600;">Proyección 2</a>.</p>
</div>
