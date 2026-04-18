# dashboard/global.R
# Librerias y carga de modulos

suppressPackageStartupMessages({
  library(lubridate)
  library(shiny)
  library(dplyr)
  library(plotly)
  library(tidyr)
  library(stats)
  library(readr)
  library(yaml)
  library(shinycssloaders)
})

# Cargar funciones y modulos
source("functions/data_processing.R")
source("functions/analysis.R")
source("functions/llegadas_mappings.R")
source("modules/ui_components.R")
source("modules/server_components.R")
source("modules/modal_changes.R")

# --- Paleta y tema unificado para graficos ---

# Paleta profesional para series multiples (max 8)
PALETA_SERIES <- c(
  "#2C6FAC",  # azul oscuro

  "#E07B39",  # naranja quemado
  "#2A9D8F",  # verde azulado
  "#C44E52",  # rojo suave
  "#8E6BBF",  # purpura
  "#D4A03C",  # dorado
  "#5BA3CF",  # azul claro
  "#7FB069"   # verde oliva
)

# Colores para series especiales (nombrados)
COLOR_REAL      <- "#2C6FAC"
COLOR_TENDENCIA <- "#2A9D8F"
COLOR_ARIMA     <- "#8E6BBF"
COLOR_SARIMAX   <- "#C44E52"
COLOR_TRAFICO   <- "#2C6FAC"
COLOR_POSITIVO  <- "#2A9D8F"
COLOR_NEGATIVO  <- "#C44E52"
COLOR_HHI       <- "#E07B39"

# Colores por continente (para graficos de mercados)
COLORES_CONTINENTE <- c(
  "AMERICA DEL SUR"   = "#2A9D8F",
  "EUROPA"            = "#E07B39",
  "AMERICA DEL NORTE" = "#2C6FAC",
  "ASIA"              = "#C44E52",
  "OCEANIA"           = "#8E6BBF",
  "AMERICA CENTRAL"   = "#7FB069",
  "CARIBE"            = "#5BA3CF",
  "MEDIO ORIENTE"     = "#D4A03C",
  "AFRICA"            = "#D97DB0",
  "OTROS"             = "#888888"
)

# Lookup: pais -> continente
get_continente <- function(pais) {
  sapply(pais, function(p) {
    for (cont in names(LLEGADAS_GRUPOS_NACIONALIDAD)) {
      if (p %in% LLEGADAS_GRUPOS_NACIONALIDAD[[cont]]) return(cont)
    }
    "OTROS"
  }, USE.NAMES = FALSE)
}

# Grosor de lineas
GROSOR_PRIMARIO   <- 1.2
GROSOR_SECUNDARIO <- 0.9

# Formateo numerico estilo espanol
fmt_num <- function(x) format(round(x), big.mark = ".", decimal.mark = ",", scientific = FALSE)

# Vector de meses en español (independiente del locale del sistema)
MESES_ES <- c("Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
              "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre")

# Formato de fecha en español: reemplaza %B por el mes en español
fmt_fecha_es <- function(fecha, formato = "%B %Y") {
  mes_num <- as.integer(format(fecha, "%m"))
  resultado <- gsub("%B", MESES_ES[mes_num], formato)
  format(fecha, resultado)
}

# Hover text: "Mes Ano<br>Etiqueta: Valor"
fmt_hover <- function(fecha, etiqueta, valor) {
  paste0(fmt_fecha_es(fecha), "<br>", etiqueta, ": ", fmt_num(valor))
}

# Grafico vacio reutilizable
empty_plotly <- function(mensaje = "Sin datos disponibles") {
  plot_ly() %>%
    add_annotations(text = mensaje, x = 0.5, y = 0.5,
                    xref = "paper", yref = "paper",
                    showarrow = FALSE, font = list(size = 14, color = "grey")) %>%
    layout(xaxis = list(visible = FALSE), yaxis = list(visible = FALSE)) %>%
    config(displayModeBar = FALSE)
}

# Layout base unificado
layout_dashboard <- function(p, xaxis = list(), yaxis = list(), ...) {
  p %>%
    layout(
      xaxis     = modifyList(list(title = "Fecha", tickfont = list(size = 11)), xaxis),
      yaxis     = modifyList(list(tickfont = list(size = 11)), yaxis),
      hovermode = "x unified",
      legend    = list(orientation = "h", x = 0.5, xanchor = "center", y = 1.08),
      margin    = list(t = 40),
      ...
    ) %>%
    config(displayModeBar = FALSE)
}
