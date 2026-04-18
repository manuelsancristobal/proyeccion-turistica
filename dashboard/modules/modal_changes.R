# modules/modal_changes.R

get_changes_history <- function() {
  list(
    list(
      version = "2.1",
      fecha = "20/03/2026",
      cambios = c(
        "Rediseño total de la pestaña Analítica bajo estándares de Business Intelligence.",
        "Sincronización de controles: Selector Maestro para Ranking y Matriz de Decisión.",
        "Implementación de escala logarítmica inteligente para el análisis de mercados base.",
        "Nueva jerarquía visual: Diagnóstico Operativo (Volumen vs LF) y Riesgo (HHI).",
        "Localización completa al español en etiquetas temporales y notas metodológicas.",
        "Analítica establecida como vista principal de aterrizaje del dashboard."
      )
    ),
    list(
      version = "2.0",
      fecha = "15/03/2026",
      cambios = c(
        "Reestructuración completa como pipeline ETL (Python + R).",
        "Dashboard unificado: Llegadas + Salidas + Tráfico Aéreo.",
        "Scraping automatizado de datos desde subturismo.gob.cl.",
        "Modelado estadístico migrado a R (STL, ARIMA, SARIMAX)."
      )
    ),
    list(
      version = "1.4",
      fecha = "28/11/2024",
      cambios = c(
        "Se agregó análisis de estacionalidad.",
        "Se realizaron ajustes al manejo de archivos."
      )
    ),
    list(
      version = "1.3",
      fecha = "26/11/2024",
      cambios = c(
        "Se agregó vista por aeropuertos.",
        "Se agregó botón para alternar entre vistas de nacionalidad y aeropuertos."
      )
    ),
    list(
      version = "1.2",
      fecha = "20/11/2024",
      cambios = c(
        "Se agregó cálculo y visualización de tendencias.",
        "Se agregó marcador (*) para puntos máximos en el gráfico.",
        "Se corrigieron errores en el cálculo de tendencias negativas."
      )
    ),
    list(
      version = "1.0",
      fecha = "04/11/2024",
      cambios = c("Lanzamiento inicial.", "Visualización de llegadas por nacionalidad.")
    )
  )
}

render_changes_modal <- function() {
  changes <- get_changes_history()
  modalDialog(
    title = "Historial de Cambios",
    easyClose = TRUE,
    footer = modalButton("Cerrar"),
    div(
      style = "max-height: 400px; overflow-y: auto;",
      lapply(changes, function(version) {
        tagList(
          h5(paste("Versión", version$version, "(", version$fecha, ")")),
          tags$ul(lapply(version$cambios, tags$li))
        )
      })
    )
  )
}
