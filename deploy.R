# deploy.R
# Script para publicar automaticamente el dashboard en shinyapps.io

cat("Iniciando proceso de despliegue a shinyapps.io...\n")

# 1. Cargar la libreria necesaria
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  install.packages("rsconnect", repos = "https://cran.rstudio.com")
}
library(rsconnect)

# 2. Leer credenciales desde variables de entorno (seguridad)
# Debes configurar esto en tu archivo .Renviron local
SHINY_ACC_NAME <- Sys.getenv("SHINY_ACC_NAME")
SHINY_TOKEN    <- Sys.getenv("SHINY_TOKEN")
SHINY_SECRET   <- Sys.getenv("SHINY_SECRET")

if (SHINY_ACC_NAME == "" || SHINY_TOKEN == "" || SHINY_SECRET == "") {
  stop("ERROR: Faltan credenciales. Por favor configura SHINY_ACC_NAME, SHINY_TOKEN y SHINY_SECRET en tu archivo .Renviron")
}

# 3. Preparar archivos para el despliegue (Self-contained)
cat("Preparando carpeta dashboard para despliegue...\n")
if (file.exists("config.yml")) {
  file.copy("config.yml", "dashboard/config.yml", overwrite = TRUE)
  cat(" - config.yml copiado a dashboard/\n")
}

# 4. Configurar la cuenta localmente
rsconnect::setAccountInfo(name = SHINY_ACC_NAME,
                          token = SHINY_TOKEN,
                          secret = SHINY_SECRET)

# 5. Desplegar la carpeta 'dashboard'
rsconnect::deployApp(appDir = "dashboard", forceUpdate = TRUE)

cat("¡Despliegue completado con exito!\n")