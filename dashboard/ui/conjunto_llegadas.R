# ui/conjunto_llegadas.R
# Tab de Llegadas de turistas extranjeros

conjunto_llegadas_ui <- function() {
  tabPanel(
    "Llegadas",
    icon = icon("plane-arrival"),

    # CSS personalizado para este tab
    tags$style(HTML("
      .llegadas-controls {
        display: flex;
        align-items: flex-start;
        gap: 24px;
        padding: 14px 20px;
        background: #f8f9fa;
        border: 1px solid #e9ecef;
        border-radius: 8px;
        margin-bottom: 16px;
      }
      .llegadas-controls .form-group { margin-bottom: 0; }
      .llegadas-controls .control-label { font-weight: 600; color: #495057; font-size: 12px; text-transform: uppercase; letter-spacing: 0.5px; }
      .llegadas-controls .radio-inline { margin-top: 2px; }
      .llegadas-charts {
        display: flex;
        gap: 16px;
        min-height: 0;
      }
      .llegadas-chart-card {
        flex: 1;
        background: #fff;
        border: 1px solid #e9ecef;
        border-radius: 8px;
        padding: 16px;
        display: flex;
        flex-direction: column;
      }
      .llegadas-chart-card h5 {
        margin: 0 0 8px 0;
        font-size: 13px;
        font-weight: 600;
        color: #343a40;
        text-transform: uppercase;
        letter-spacing: 0.3px;
      }
      .llegadas-chart-card .chart-note {
        font-size: 10px;
        color: #999;
        margin-top: 6px;
        font-style: italic;
        line-height: 1.4;
      }
      .llegadas-analisis {
        margin-bottom: 16px;
        border: 1px solid #e9ecef;
        border-radius: 8px;
        background: #f8f9fa;
        padding: 10px 20px;
        max-height: 160px;
        overflow-y: auto;
      }
      .llegadas-analisis .analisis-grid {
        display: flex;
        gap: 24px;
        flex-wrap: wrap;
      }
      .llegadas-analisis .analisis-item {
        flex: 1;
        min-width: 220px;
        padding: 6px 0;
        border-right: 1px solid #e0e0e0;
        padding-right: 20px;
      }
      .llegadas-analisis .analisis-item:last-child { border-right: none; padding-right: 0; }
      .llegadas-analisis h5 { font-size: 13px; font-weight: 600; color: #343a40; margin: 0 0 4px 0; }
      .llegadas-analisis p { font-size: 11.5px; color: #555; margin-bottom: 3px; line-height: 1.45; }
      .llegadas-chart-card .form-group { margin-bottom: 0; }
      .llegadas-chart-card .checkbox { margin-top: 0; margin-bottom: 0; }
      .llegadas-chart-card .checkbox label { font-size: 12px; color: #6c757d; }
    ")),

    # Fila de controles
    tags$div(
      class = "llegadas-controls",
      tags$div(
        style = "min-width: 200px;",
        radioButtons("vista_llegadas", "Vista:",
                     choices = c("Por Nacionalidad" = "nacionalidad",
                                 "Por Paso/Aeropuerto" = "aeropuerto"),
                     selected = "nacionalidad", inline = TRUE)
      ),
      tags$div(
        style = "min-width: 180px;",
        uiOutput("selector_grupo_llegadas")
      ),
      conditionalPanel(
        condition = "!input.mostrar_total_grupo && input.grupo_llegadas !== 'Total'",
        tags$div(
          style = "flex: 1; min-width: 200px;",
          uiOutput("selector_item_llegadas")
        )
      ),
      tags$div(
        style = "padding-top: 22px;",
        checkboxInput("mostrar_total_grupo", "Mostrar total del grupo", FALSE)
      ),
    ),

    # Panel de analisis (arriba de los graficos)
    tags$div(
      class = "llegadas-analisis",
      uiOutput("info_panel_llegadas")
    ),

    # Graficos lado a lado
    tags$div(
      class = "llegadas-charts",
      tags$div(
        class = "llegadas-chart-card",
        tags$div(
          style = "display: flex; justify-content: space-between; align-items: center;",
          tags$h5("Llegadas de Turistas"),
          tags$div(
            style = "display: flex; gap: 12px; align-items: center;",
            checkboxInput("mostrar_tendencia_ll", "Mostrar tendencia", TRUE),
            checkboxInput("mostrar_proyeccion_ll", "Mostrar proyección", FALSE)
          )
        ),
        withSpinner(plotlyOutput("plot_llegadas", height = "380px"), type = 6, color = "#2C6FAC"),
        tags$div(class = "chart-note", "Fuente: Servicio Nacional de Turismo")
      ),
      tags$div(
        class = "llegadas-chart-card",
        tags$h5("Factor de Ocupación (Load Factor)"),
        withSpinner(plotlyOutput("plot_load_factor", height = "380px"), type = 6, color = "#2C6FAC"),
        tags$div(
          class = "chart-note",
          "Cálculo: Razón entre pasajeros transportados y capacidad estimada (percentil 95 de pasajeros por ruta) ",
          "en ventana móvil de 12 meses. No refleja la capacidad real de asientos ofrecidos.",
          tags$br(), tags$br(),
          "Fuente: Elaboración propia con datos de la Junta Aeronáutica Civil."
        )
      )
    )
  )
}
