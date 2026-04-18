# transform/sarimax_forecast.R
# Pronostico SARIMAX con dummies de pandemia para series de salidas

library(forecast)

#' Crea variables dummy para pandemia COVID
#' lockdown: 2020-03 a 2020-09, rehab: 2020-10 a 2022-09
crear_dummies_pandemia <- function(fechas) {
  fechas <- as.Date(fechas)
  dummy_lockdown <- as.integer(fechas >= as.Date("2020-03-01") & fechas < as.Date("2020-10-01"))
  dummy_rehab <- as.integer(fechas >= as.Date("2020-10-01") & fechas < as.Date("2022-10-01"))
  cbind(Dummy_lockdown = dummy_lockdown, Dummy_rehab = dummy_rehab)
}

#' Aplica guardrail estacional: limita forecast futuro a +-50% del valor
#' esperado segun patron estacional historico (ratios mensuales)
guardrail_future <- function(values, df_real, n_future, band = 0.5) {
  if (n_future <= 0 || nrow(df_real) == 0) return(values)
  n_total <- length(values)
  n_hist <- n_total - n_future
  if (n_hist < 0) return(values)

  # Calcular ratios mensuales historicos
  df_real$mes <- as.integer(format(as.Date(df_real$Fecha), "%m"))
  global_mean <- mean(df_real$Cantidad, na.rm = TRUE)
  if (is.na(global_mean) || global_mean == 0) return(values)

  ratio_mes <- tapply(df_real$Cantidad, df_real$mes, mean, na.rm = TRUE) / global_mean
  ratio_mes[is.na(ratio_mes)] <- 1

  # Base: media del ultimo ano de datos reales
  last_year <- tail(df_real, 12)
  base <- mean(last_year$Cantidad, na.rm = TRUE)
  if (is.na(base) || base == 0) return(values)

  # Meses futuros
  last_date <- max(as.Date(df_real$Fecha))
  future_months <- as.integer(format(seq(last_date %m+% months(1),
                                         by = "month", length.out = n_future), "%m"))

  # Valor esperado estacional por mes
  expected <- base * ratio_mes[as.character(future_months)]
  upper_limit <- expected * (1 + band)
  lower_limit <- expected * (1 - band)

  future_idx <- (n_hist + 1):n_total
  values[future_idx] <- pmin(pmax(values[future_idx], lower_limit), upper_limit)
  return(values)
}

#' Ejecuta SARIMAX en todos los archivos real_*.csv
run_sarimax_forecast <- function(raw_dir, out_dir, forecast_horizon = 6,
                                 seasonal_period = 12, use_pandemic_dummy = TRUE) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  datos <- read_raw_salidas(raw_dir)
  if (length(datos) == 0) {
    warning("No hay datos para SARIMAX")
    return(invisible(NULL))
  }

  for (nombre in names(datos)) {
    df <- datos[[nombre]]
    tryCatch({
      serie <- to_monthly_ts(df, freq = seasonal_period)

      # Exogenas: dummies de pandemia
      if (use_pandemic_dummy) {
        xreg_in <- crear_dummies_pandemia(df$Fecha)
      } else {
        xreg_in <- NULL
      }

      # auto.arima con componente estacional
      modelo <- auto.arima(serie, seasonal = TRUE, xreg = xreg_in,
                           stepwise = TRUE, approximation = FALSE,
                           trace = FALSE, D = 1)

      # Exogenas para forecast (futuro: dummies = 0)
      start_future <- max(df$Fecha) %m+% months(1)
      fechas_future <- seq(start_future, by = "month", length.out = forecast_horizon)
      if (use_pandemic_dummy) {
        xreg_future <- crear_dummies_pandemia(fechas_future)
      } else {
        xreg_future <- NULL
      }

      # Forecast
      fc <- forecast(modelo, h = forecast_horizon, level = 95, xreg = xreg_future)

      # In-sample + forecast
      fitted_vals <- as.vector(fitted(modelo))
      pronostico <- c(fitted_vals, as.vector(fc$mean))
      li_95 <- c(rep(NA, length(fitted_vals)), as.vector(fc$lower[, 1]))
      ls_95 <- c(rep(NA, length(fitted_vals)), as.vector(fc$upper[, 1]))
      fechas_all <- c(df$Fecha, fechas_future)

      # Guardrail estacional en forecast futuro
      pronostico <- guardrail_future(pronostico, df, forecast_horizon)
      li_95 <- guardrail_future(li_95, df, forecast_horizon)
      ls_95 <- guardrail_future(ls_95, df, forecast_horizon)

      out_df <- data.frame(
        Fecha = fechas_all,
        Pronostico = pronostico,
        li_95 = li_95,
        ls_95 = ls_95
      )

      code <- extract_code(nombre)
      out_path <- file.path(out_dir, paste0("sarimax_", code, ".csv"))
      write_csv(out_df, out_path)
      message(sprintf("[SARIMAX] %s -> %s", nombre, basename(out_path)))

    }, error = function(e) {
      message(sprintf("[SARIMAX FAIL] %s: %s", nombre, e$message))
    })
  }

  message("[SARIMAX DONE]")
}
