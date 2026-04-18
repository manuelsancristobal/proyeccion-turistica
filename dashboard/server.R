# server.R
# Logica server principal

server <- function(input, output, session) {
  # Cargar todos los datos pre-computados
  data <- read_and_process_data()

  # Modal de cambios
  observeEvent(input$show_changes, {
    showModal(render_changes_modal())
  })

  # Wiring de cada tab
  llegadas_server(input, output, session, data)
  salidas_server(input, output, session, data)
  analitica_server(input, output, session, data)
}
