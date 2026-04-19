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

## Dashboard Interactivo

Explora las proyecciones de turismo emisivo y receptivo de Chile con filtros dinámicos, descomposición de series temporales y modelos de pronóstico.

{::nomarkdown}
<div style="position: relative; width: 100%; padding-bottom: 75%; overflow: hidden;">
  <iframe
    src="https://manuel-san-cristobal-opazo.shinyapps.io/dashboard/"
    style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none;"
    loading="lazy"
    title="Dashboard de Proyección Turística Chile">
  </iframe>
</div>
<p style="font-size: 12px; color: #999; margin-top: 8px; text-align: center;">
  Si el dashboard no carga, puede que las horas gratuitas del mes se hayan agotado. Los gráficos estáticos a continuación resumen los hallazgos principales.
</p>
{:/nomarkdown}

## Análisis Complementario

### Salidas de residentes chilenos al extranjero

El gráfico muestra la serie histórica mensual de salidas de residentes, la tendencia extraída mediante descomposición STL y las proyecciones generadas por modelos ARIMA y SARIMAX. El modelo SARIMAX incorpora una variable dummy para el periodo pandémico, mejorando la estimación post-COVID.

![Salidas de residentes con tendencia y proyecciones ARIMA/SARIMAX](./assets/charts/01_salidas_proyeccion.png)

Se observa un crecimiento sostenido en las salidas de residentes previo a 2020, seguido de una caída abrupta por la pandemia y una recuperación que ha superado los niveles pre-pandémicos. Las proyecciones de ambos modelos convergen, sugiriendo que la tendencia alcista se mantendrá en el horizonte de pronóstico.

---

### Llegadas de turistas extranjeros

El flujo de turistas internacionales hacia Chile se concentra en pocos mercados emisores. El gráfico muestra la evolución mensual de los 5 principales mercados por volumen de llegadas.

![Top 5 mercados emisores de turistas hacia Chile](./assets/charts/02_llegadas_nacionalidad.png)

Argentina domina ampliamente como mercado emisor, seguido a distancia por Brasil y otros países de la región. La recuperación post-pandémica muestra velocidades dispares entre mercados, revelando oportunidades para diversificar la base de visitantes.

---

### Frecuencia de vuelos internacionales

La oferta de conectividad aérea es un indicador adelantado de la demanda turística. El gráfico muestra el total de operaciones aéreas internacionales salientes por mes, con suavizado LOESS para visualizar la tendencia subyacente.

![Frecuencia de vuelos internacionales salientes con suavizado LOESS](./assets/charts/03_frecuencia_vuelos.png)

El número de operaciones refleja tanto la estacionalidad turística como cambios estructurales en la industria aérea. La entrada de operadores low-cost ha contribuido al aumento de frecuencias en años recientes.

---

### Factor de ocupación por aeropuerto

El load factor mide la relación entre pasajeros transportados y capacidad estimada. Valores superiores al 85% indican saturación operativa y potencial necesidad de ampliación de rutas o frecuencias.

![Factor de ocupación de los principales aeropuertos](./assets/charts/04_load_factor.png)

Los aeropuertos principales operan consistentemente con altos factores de ocupación, lo que sugiere una demanda robusta que presiona la capacidad disponible. Periodos con load factor cercano o superior al umbral del 85% señalan ventanas de oportunidad para nuevas rutas.

---

### Estacionalidad de salidas

El heatmap revela el patrón estacional de las salidas de residentes. Colores más intensos indican mayor flujo de viajeros.

![Heatmap de estacionalidad de salidas de residentes](./assets/charts/05_estacionalidad.png)

Se identifica un patrón recurrente con peaks en enero-febrero (verano austral) y julio (vacaciones de invierno). La amplitud estacional crece con el tiempo, reflejando un mercado en expansión. Los años 2020-2021 aparecen como franjas claras, evidenciando el impacto de las restricciones sanitarias.

---

## Metodología

Este proyecto implementa un pipeline ETL completo:

- **Extracción** (Python): Descarga automatizada de datos desde el portal de SERNATUR y la Junta Aeronáutica Civil.
- **Transformación** (R): Descomposición STL de series temporales, cálculo de tendencias, modelos de pronóstico ARIMA y SARIMAX con horizonte de 6 meses, cálculo de load factors y métricas de concentración de mercado (HHI).
- **Visualización** (R Shiny): Dashboard interactivo con tres módulos: Analítica de mercados, Llegadas de turistas y Salidas de residentes.
