# ui.R
# Estructura principal de tabs (patron conjunto del Proyecto 2)

source("ui/conjunto_llegadas.R")
source("ui/conjunto_salidas.R")
source("ui/conjunto_analitica.R")

ui <- fluidPage(
  header_ui(),
  tabsetPanel(
    id = "tabs_principal",
    type = "tabs",
    conjunto_analitica_ui(), # Ahora es la primera pestaña
    conjunto_llegadas_ui(),
    conjunto_salidas_ui()
  )
)
