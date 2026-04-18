# ui/conjunto_analitica.R
# Tab de Analitica de Mercados - Layout de Alto Nivel (Industry Standard)

conjunto_analitica_ui <- function() {
  tabPanel(
    "Analitica",
    icon = icon("chart-line"),

    # CSS optimizado para legibilidad y estructura
    tags$style(HTML("
      .analitica-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 15px 20px;
        background: #fff;
        border-bottom: 2px solid #f1f3f5;
        margin-bottom: 20px;
      }
      .analitica-section-title {
        font-size: 14px;
        font-weight: 700;
        color: #495057;
        text-transform: uppercase;
        letter-spacing: 1px;
        margin-bottom: 15px;
        display: flex;
        align-items: center;
        gap: 10px;
      }
      .analitica-section-title i { color: #2A9D8F; }
      
      .kpi-container {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 20px;
        margin-bottom: 25px;
      }
      .kpi-card-new {
        background: #fff;
        padding: 20px;
        border-radius: 10px;
        border: 1px solid #e9ecef;
        box-shadow: 0 2px 4px rgba(0,0,0,0.02);
      }
      .kpi-card-new .label { font-size: 11px; color: #adb5bd; text-transform: uppercase; font-weight: 600; margin-bottom: 5px; }
      .kpi-card-new .value { font-size: 32px; font-weight: 800; color: #212529; }
      .kpi-card-new .subtext { font-size: 12px; color: #6c757d; margin-top: 5px; }

      .analysis-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 20px;
        margin-bottom: 25px;
      }
      .card-dynamic {
        background: #fff;
        border-radius: 10px;
        border: 1px solid #e9ecef;
        padding: 20px;
        position: relative;
      }
      .card-header-tools {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 15px;
        flex-direction: column;
        gap: 5px;
      }
      .card-header-tools h5 { margin: 0; font-size: 15px; font-weight: 700; color: #343a40; text-transform: uppercase; }
      .card-subtitle { font-size: 12px; color: #6c757d; line-height: 1.4; }
      
      .chart-footer-note {
        font-size: 10px;
        color: #adb5bd;
        margin-top: 15px;
        font-style: italic;
        border-top: 1px solid #f8f9fa;
        padding-top: 10px;
      }
      
      .btn-group-container {
        background: #f8f9fa;
        padding: 15px 20px;
        border-radius: 10px;
        border: 1px solid #e9ecef;
        margin-bottom: 25px;
      }
      .btn-group-container label { 
        display: block;
        margin-bottom: 15px; 
        font-size: 13px; 
        font-weight: 700; 
        color: #495057; 
        text-transform: uppercase;
        letter-spacing: 0.5px;
        border-bottom: 1px solid #e9ecef;
        padding-bottom: 8px;
      }
      /* Forzar que las opciones esten en la misma linea y sin negrita */
      .btn-group-container .shiny-options-group {
        display: flex;
        flex-direction: row;
        gap: 30px;
      }
      .btn-group-container .radio-inline {
        font-weight: 400 !important;
        margin: 0 !important;
        padding: 0;
        display: flex;
        align-items: center;
      }
      .btn-group-container .radio-inline input {
        margin-top: 0;
        margin-right: 8px;
      }
      .btn-group-container .radio-inline span {
        font-weight: 400 !important;
      }
    ")),

    # Header
    tags$div(
      class = "analitica-header",
      tags$h3("Inteligencia de Mercados", style = "margin:0; font-weight:800; color:#212529;"),
      tags$div(
        radioButtons("periodo_analitica", NULL,
                     choices = c("6 meses" = "6", "12 meses" = "12", "24 meses" = "24"),
                     selected = "12", inline = TRUE)
      )
    ),

    # KPIs
    tags$div(
      class = "kpi-container",
      uiOutput("kpi_total"),
      uiOutput("kpi_hhi_card"),
      uiOutput("kpi_mercados")
    ),

    # Selector Maestro (Estructura mejorada)
    tags$div(
      class = "btn-group-container",
      tags$label("Enfoque del Análisis:"),
      radioButtons("tipo_analisis_maestro", NULL,
                   choices = c("Top 10 Mercados Emisores (Volumen)" = "top", 
                               "Mercados Emergentes (Crecimiento %)" = "emergentes"),
                   selected = "top", inline = TRUE)
    ),

    # Capa 2: Diagnóstico Operativo
    tags$div(class = "analitica-section-title", icon("microscope"), "Diagnóstico de Flujo y Capacidad Operativa"),
    tags$div(
      class = "analysis-grid",
      # Columna 1: Ranking
      tags$div(
        class = "card-dynamic",
        tags$div(
          class = "card-header-tools",
          tags$h5("Dinámica de Mercados"),
          tags$div(class = "card-subtitle", "Ranking según volumen o dinamismo reciente.")
        ),
        withSpinner(plotlyOutput("plot_ranking_dinamico", height = "450px"), type = 6, color = "#2A9D8F"),
        tags$div(
          class = "chart-footer-note",
          "Fuente: Elaboración propia con datos de SERNATUR."
        )
      ),
      # Columna 2: Matriz
      tags$div(
        class = "card-dynamic",
        tags$div(
          class = "card-header-tools",
          tags$h5("Matriz: Ocupación vs Flujo"),
          tags$div(
            class = "card-subtitle", 
            "Zona roja: mercados con saturación aérea.",
            tags$br(),
            tags$em("Nota: Se excluyen mercados con menos de 100 llegadas en el periodo o sin conectividad directa.")
          )
        ),
        withSpinner(plotlyOutput("plot_lf_dinamico", height = "450px"), type = 6, color = "#2A9D8F"),
        tags$div(
          class = "chart-footer-note",
          "Fuente: Elaboración propia con datos de SERNATUR y JAC."
        )
      )
    ),

    # Capa 3: Riesgo y Concentración
    tags$div(class = "analitica-section-title", icon("balance-scale"), "Análisis de Riesgo y Diversificación"),
    tags$div(
      class = "card-dynamic",
      style = "margin-bottom: 30px;",
      tags$div(
        class = "card-header-tools",
        tags$h5("Evolución de Concentración de Mercados (Índice HHI)"),
        tags$div(class = "card-subtitle", "Valores inferiores a 1.500 indican una base de mercados diversificada y resiliente.")
      ),
      withSpinner(plotlyOutput("plot_hhi", height = "380px"), type = 6, color = "#2A9D8F"),
      tags$div(
        class = "chart-footer-note",
        "Fuente: Elaboración propia con datos del Servicio Nacional de Turismo (SERNATUR)."
      )
    )
  )
}
