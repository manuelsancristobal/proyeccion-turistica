# modules/ui_components.R
# Componentes UI reutilizables

header_ui <- function() {
  div(
    style = "display: flex; justify-content: space-between; align-items: center;",
    h2("Dashboard de Turismo - Chile"),
    actionButton("show_changes", "Ver cambios recientes",
                 class = "btn-info", style = "margin-top: 10px;")
  )
}
