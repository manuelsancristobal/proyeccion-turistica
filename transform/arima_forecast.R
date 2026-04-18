# transform/arima_forecast.R
# Pronostico ARIMA para series de salidas

library(forecast)

#' Ejecuta ARIMA en todos los archivos real_*.csv
#' Genera arima_YYYYMM.csv con columnas Fecha, Pronostico, li_95, ls_95
run_arima_forecast <- function(raw_dir, out_dir, forecast_horizon = 6) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  datos <- read_raw_salidas(raw_dir)
  if (length(datos) == 0) {
    warning("No hay datos para ARIMA")
    return(invisible(NULL))
  }

  # Calcular longitud maxima para horizonte dinamico
  max_obs <- max(sapply(datos, nrow))

  metrics <- data.frame(
    serie = character(),
    p = integer(), d = integer(), q = integer(),
    mape = numeric(), rmse = numeric(),
    stringsAsFactors = FALSE
  )

  for (nombre in names(datos)) {
    df <- datos[[nombre]]
    tryCatch({
      serie <- to_monthly_ts(df, freq = 12)

      # seasonal=FALSE intencional: ARIMA no-estacional como baseline.
      # La estacionalidad se modela en SARIMAX (sarimax_forecast.R).
      modelo <- auto.arima(serie, seasonal = FALSE, stepwise = TRUE,
                           approximation = FALSE, trace = FALSE)

      # Horizonte dinamico
      diff_obs <- max_obs - length(serie)
      horizon <- diff_obs + forecast_horizon

      # Forecast
      fc <- forecast(modelo, h = horizon, level = 95)

      # In-sample fitted + forecast
      fechas_in <- df$Fecha
      start_future <- max(df$Fecha) %m+% months(1)
      fechas_out <- seq(start_future, by = "month", length.out = horizon)

      # Construir dataframe completo
      fitted_vals <- as.vector(fitted(modelo))
      pronostico <- c(fitted_vals, as.vector(fc$mean))
      li_95 <- c(rep(NA, length(fitted_vals)), as.vector(fc$lower[, 1]))
      ls_95 <- c(rep(NA, length(fitted_vals)), as.vector(fc$upper[, 1]))
      fechas_all <- c(fechas_in, fechas_out)

      out_df <- data.frame(
        Fecha = fechas_all,
        Pronostico = pronostico,
        li_95 = li_95,
        ls_95 = ls_95
      )

      code <- extract_code(nombre)
      out_path <- file.path(out_dir, paste0("arima_", code, ".csv"))
      write_csv(out_df, out_path)
      message(sprintf("[ARIMA] %s -> %s (order: %d,%d,%d)",
                      nombre, basename(out_path),
                      modelo$arma[1], modelo$arma[6], modelo$arma[2]))

      # Metricas (holdout de 12 meses si hay suficientes datos)
      if (length(serie) > 24) {
        train <- head(serie, length(serie) - 12)
        test <- tail(serie, 12)
        mod_test <- auto.arima(train, seasonal = FALSE, stepwise = TRUE)
        fc_test <- forecast(mod_test, h = 12)
        err <- as.vector(test) - as.vector(fc_test$mean)
        mape_val <- mean(abs(err / as.vector(test)), na.rm = TRUE) * 100
        rmse_val <- sqrt(mean(err^2, na.rm = TRUE))
      } else {
        mape_val <- NA
        rmse_val <- NA
      }

      metrics <- rbind(metrics, data.frame(
        serie = nombre,
        p = modelo$arma[1], d = modelo$arma[6], q = modelo$arma[2],
        mape = mape_val, rmse = rmse_val,
        stringsAsFactors = FALSE
      ))

    }, error = function(e) {
      message(sprintf("[ARIMA FAIL] %s: %s", nombre, e$message))
    })
  }

  # Guardar metricas
  metrics_path <- file.path(out_dir, "metricas_arima.csv")
  write_csv(metrics, metrics_path)
  message(sprintf("[ARIMA DONE] %d series procesadas.", nrow(metrics)))
}
