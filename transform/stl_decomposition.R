# transform/stl_decomposition.R
# Descomposicion STL para series de salidas

#' Ejecuta descomposicion STL en todos los archivos real_*.csv
#' Genera trend_YYYYMM.csv y metrics_stl.csv
run_stl_decomposition <- function(raw_dir, out_dir, seasonal_period = 12) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  datos <- read_raw_salidas(raw_dir)
  if (length(datos) == 0) {
    warning("No hay datos para descomposicion STL")
    return(invisible(NULL))
  }

  metrics <- data.frame(
    serie = character(),
    filas = integer(),
    inicio = character(),
    fin = character(),
    strength_trend = numeric(),
    strength_season = numeric(),
    stringsAsFactors = FALSE
  )

  for (nombre in names(datos)) {
    df <- datos[[nombre]]
    tryCatch({
      serie <- to_monthly_ts(df, freq = seasonal_period)

      # STL robusto
      stl_result <- stl(serie, s.window = "periodic", robust = TRUE)
      trend <- as.vector(stl_result$time.series[, "trend"])
      seasonal <- as.vector(stl_result$time.series[, "seasonal"])
      residual <- as.vector(stl_result$time.series[, "remainder"])

      # Metricas de fortaleza (Cleveland)
      var_res <- var(residual, na.rm = TRUE)
      var_rt <- var(residual + trend, na.rm = TRUE)
      var_rs <- var(residual + seasonal, na.rm = TRUE)

      strength_trend <- max(0, 1 - var_res / var_rt)   # F_T = 1 - Var(R)/Var(T+R)
      strength_season <- max(0, 1 - var_res / var_rs)   # F_S = 1 - Var(R)/Var(S+R)

      # Guardar
      out_df <- data.frame(
        Fecha = df$Fecha,
        Tendencia = trend,
        Estacional = seasonal,
        Residuo = residual
      )
      code <- extract_code(nombre)
      out_path <- file.path(out_dir, paste0("trend_", code, ".csv"))
      write_csv(out_df, out_path)
      message(sprintf("[STL] %s -> %s", nombre, basename(out_path)))

      metrics <- rbind(metrics, data.frame(
        serie = nombre,
        filas = nrow(df),
        inicio = as.character(min(df$Fecha)),
        fin = as.character(max(df$Fecha)),
        strength_trend = strength_trend,
        strength_season = strength_season,
        stringsAsFactors = FALSE
      ))
    }, error = function(e) {
      message(sprintf("[STL FAIL] %s: %s", nombre, e$message))
    })
  }

  # Guardar metricas
  metrics_path <- file.path(out_dir, "metrics_stl.csv")
  write_csv(metrics, metrics_path)
  message(sprintf("[STL DONE] %d series procesadas. Metricas: %s", nrow(metrics), metrics_path))
}
