# app.R
# Punto de entrada del dashboard

source("global.R")
source("ui.R")
source("server.R")

shinyApp(ui = ui, server = server)
