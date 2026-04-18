# ui/conjunto_salidas.R
# Tab de Salidas de residentes (turismo emisivo)

conjunto_salidas_ui <- function() {
  tabPanel(
    "Salidas",
    icon = icon("plane-departure"),

    # CSS personalizado para este tab (misma estructura que llegadas)
    tags$style(HTML("
      .salidas-controls {
        display: flex;
        align-items: flex-start;
        gap: 24px;
        padding: 14px 20px;
        background: #f8f9fa;
        border: 1px solid #e9ecef;
        border-radius: 8px;
        margin-bottom: 16px;
      }
      .salidas-controls .form-group { margin-bottom: 0; }
      .salidas-controls .control-label { font-weight: 600; color: #495057; font-size: 12px; text-transform: uppercase; letter-spacing: 0.5px; }
      .salidas-charts {
        display: flex;
        gap: 16px;
        min-height: 0;
      }
      .salidas-chart-card {
        flex: 1;
        background: #fff;
        border: 1px solid #e9ecef;
        border-radius: 8px;
        padding: 16px;
        display: flex;
        flex-direction: column;
      }
      .salidas-chart-card h5 {
        margin: 0 0 8px 0;
        font-size: 13px;
        font-weight: 600;
        color: #343a40;
        text-transform: uppercase;
        letter-spacing: 0.3px;
      }
      .salidas-chart-card .chart-note {
        font-size: 10px;
        color: #999;
        margin-top: 6px;
        font-style: italic;
        line-height: 1.4;
      }
      .salidas-analisis {
        margin-bottom: 16px;
        border: 1px solid #e9ecef;
        border-radius: 8px;
        background: #f8f9fa;
        padding: 10px 20px;
        max-height: 160px;
        overflow-y: auto;
      }
      .salidas-analisis .analisis-grid {
        display: flex;
        gap: 24px;
        flex-wrap: wrap;
      }
      .salidas-analisis .analisis-item {
        flex: 1;
        min-width: 220px;
        padding: 6px 0;
      }
      .salidas-analisis h5 { font-size: 13px; font-weight: 600; color: #343a40; margin: 0 0 4px 0; }
      .salidas-analisis p { font-size: 11.5px; color: #555; margin-bottom: 3px; line-height: 1.45; }
      .salidas-chart-card .form-group { margin-bottom: 0; }
      .salidas-chart-card .checkbox { margin-top: 0; margin-bottom: 0; }
      .salidas-chart-card .checkbox label { font-size: 12px; color: #6c757d; }
    ")),

    # Panel de analisis (arriba de los graficos)
    tags$div(
      class = "salidas-analisis",
      uiOutput("info_panel_salidas")
    ),

    # Graficos lado a lado
    tags$div(
      class = "salidas-charts",
      tags$div(
        class = "salidas-chart-card",
        tags$div(
          style = "display: flex; justify-content: space-between; align-items: center;",
          tags$h5("Salidas de Residentes Chilenos"),
          tags$div(
            style = "display: flex; gap: 12px; align-items: center;",
            checkboxInput("mostrar_tendencia_sal", "Mostrar tendencia", TRUE),
            checkboxInput("mostrar_proyeccion_sal", "Mostrar proyección", FALSE)
          )
        ),
        withSpinner(plotlyOutput("plot_salidas", height = "380px"), type = 6, color = "#2C6FAC"),
        tags$div(class = "chart-note", "Fuente: Servicio Nacional de Turismo")
      ),
      tags$div(
        class = "salidas-chart-card",
        tags$h5("Frecuencia de Vuelos Internacionales Salientes"),
        withSpinner(plotlyOutput("plot_salidas_frecuencia", height = "380px"), type = 6, color = "#2C6FAC"),
        tags$div(
          class = "chart-note",
          "Cálculo: Total de operaciones aéreas internacionales salientes registradas por mes.",
          tags$br(), tags$br(),
          "Fuente: Elaboración propia con datos de la Junta Aeronáutica Civil."
        )
      )
    )
  )
}
