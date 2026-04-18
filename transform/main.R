# transform/main.R
# Punto de entrada de la capa Transform
# Uso: Rscript transform/main.R (desde la raiz del proyecto)

cat("=== TRANSFORM: Iniciando ===\n")

# Cargar librerias necesarias
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(forecast)
  library(lubridate)
  library(future)
  library(future.apply)
})

# Source modulos
script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) normalizePath("transform")
)
source(file.path(script_dir, "config.R"))
source(file.path(script_dir, "utils.R"))
source(file.path(script_dir, "stl_decomposition.R"))
source(file.path(script_dir, "arima_forecast.R"))
source(file.path(script_dir, "sarimax_forecast.R"))
source(file.path(script_dir, "unification.R"))
source(file.path(script_dir, "llegadas_transform.R"))
source(file.path(script_dir, "trafico_transform.R"))

# Cargar configuracion
cfg <- load_config()
forecast_horizon <- cfg$transform$forecast_horizon %||% 6
seasonal_period <- cfg$transform$seasonal_period %||% 12
use_pandemic_dummy <- cfg$transform$use_pandemic_dummy %||% TRUE

# Configurar paralelizacion
parallel_workers <- cfg$transform$parallel_workers %||% "auto"
if (identical(parallel_workers, "auto")) {
  n_workers <- max(1, parallel::detectCores() - 1)
} else {
  n_workers <- max(1, as.integer(parallel_workers))
}
future::plan(future::multisession, workers = n_workers)
cat(sprintf("  Paralelizacion: %d workers (multisession)\n", n_workers))

# === 1. STL Decomposition (salidas) ===
cat("\n--- STL Decomposition ---\n")
run_stl_decomposition(
  raw_dir = cfg$raw_salidas,
  out_dir = cfg$transformed_salidas,
  seasonal_period = seasonal_period
)

# === 2+3. ARIMA y SARIMAX Forecast (salidas) — en paralelo ===
cat("\n--- ARIMA + SARIMAX Forecast (paralelo) ---\n")
f_arima <- future::future({
  run_arima_forecast(
    raw_dir = cfg$raw_salidas,
    out_dir = cfg$transformed_salidas,
    forecast_horizon = forecast_horizon
  )
})
f_sarimax <- future::future({
  run_sarimax_forecast(
    raw_dir = cfg$raw_salidas,
    out_dir = cfg$transformed_salidas,
    forecast_horizon = forecast_horizon,
    seasonal_period = seasonal_period,
    use_pandemic_dummy = use_pandemic_dummy
  )
})
future::value(f_arima)
future::value(f_sarimax)
cat("  ARIMA y SARIMAX completados.\n")

# === 4. Unification (salidas) ===
cat("\n--- Unification ---\n")
run_unification(
  raw_dir = cfg$raw_salidas,
  transformed_dir = cfg$transformed_salidas
)

# === 5. Llegadas Transform ===
cat("\n--- Llegadas Transform ---\n")
run_llegadas_transform(
  raw_dir = cfg$raw_llegadas,
  out_dir = cfg$transformed_llegadas
)

# === 6. Trafico Aereo Transform ===
cat("\n--- Trafico Aereo (lectura unica) ---\n")
source(file.path(script_dir, "mappings.R"))

# Leer datos de trafico una sola vez y pasar a todas las funciones
df_trafico <- read_trafico_normalizado(cfg$raw_trafico)
if (!is.null(df_trafico)) {
  cat(sprintf("  Trafico: %d filas leidas\n", nrow(df_trafico)))
} else {
  cat("  ADVERTENCIA: No se encontraron datos de trafico\n")
}

run_trafico_transform(
  raw_dir = cfg$raw_trafico,
  out_dir = cfg$transformed_trafico,
  df_trafico = df_trafico
)

# === 6b. Frecuencia Vuelos Salientes ===
cat("\n--- Frecuencia Vuelos Salientes ---\n")
run_frecuencia_salidas_transform(
  raw_dir = cfg$raw_trafico,
  out_dir = cfg$transformed_salidas,
  df_trafico = df_trafico
)

# === 7. Load Factor Transform ===
cat("\n--- Load Factor Transform ---\n")

# Determinar fecha de inicio desde los datos de llegadas para alinear series
fecha_inicio_llegadas <- tryCatch({
  nac_csv <- file.path(cfg$transformed_llegadas, "llegadas_nacionalidad.csv")
  if (file.exists(nac_csv)) {
    df_ll <- readr::read_csv(nac_csv, show_col_types = FALSE, n_max = 1)
    as.Date(df_ll$Fecha[1])
  } else NULL
}, error = function(e) NULL)

if (!is.null(fecha_inicio_llegadas)) {
  cat(sprintf("  Alineando load factor desde %s (inicio de llegadas)\n", fecha_inicio_llegadas))
}

run_load_factor_transform(
  raw_dir = cfg$raw_trafico,
  out_dir = cfg$transformed_trafico,
  fecha_inicio = fecha_inicio_llegadas,
  df_trafico = df_trafico
)

# === 8. Connectivity Transform ===
cat("\n--- Connectivity Transform ---\n")
run_connectivity_transform(raw_dir = cfg$raw_trafico, out_dir = cfg$transformed_trafico,
                           df_trafico = df_trafico)

# === 9. Airport Analysis Transform ===
cat("\n--- Airport Analysis Transform ---\n")
run_airport_analysis_transform(raw_dir = cfg$raw_trafico, out_dir = cfg$transformed_trafico,
                               df_trafico = df_trafico)

# === 10. Llegadas Forecast (ARIMA/SARIMAX) ===
cat("\n--- Llegadas Forecast ---\n")
run_llegadas_forecast(
  out_dir = cfg$transformed_llegadas,
  forecast_horizon = forecast_horizon,
  seasonal_period = seasonal_period,
  use_pandemic_dummy = use_pandemic_dummy
)

# Limpiar plan de paralelizacion
future::plan(future::sequential)

cat("\n=== TRANSFORM COMPLETADO ===\n")
