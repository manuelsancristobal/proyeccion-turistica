# transform/llegadas_transform.R
# Transforma datos de llegadas: agrega tendencias STL

library(dplyr)
library(readr)

#' Calcula tendencias STL para cada columna numerica (llegadas).
#' Delegado a calcular_stl_tendencias() de utils.R con clamp_zero=TRUE, robust=FALSE.
calcular_tendencias_llegadas <- function(data) {
  calcular_stl_tendencias(data, robust = FALSE, clamp_zero = TRUE)
}

#' Procesa los CSVs de llegadas: agrega columna TOTAL y calcula tendencias
#' Guarda como .rds para preservar estructura (150+ columnas)
run_llegadas_transform <- function(raw_dir, out_dir) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  archivos <- list.files(raw_dir, pattern = "^llegadas_.*\\.csv$", full.names = TRUE)
  if (length(archivos) == 0) {
    warning(paste("No se encontraron archivos de llegadas en", raw_dir))
    return(invisible(NULL))
  }

  for (f in archivos) {
    nombre <- tools::file_path_sans_ext(basename(f))
    tryCatch({
      df <- read_csv(f, show_col_types = FALSE)
      df$Fecha <- as.Date(df$Fecha)
      df <- df %>% filter(!is.na(Fecha)) %>% arrange(Fecha)

      # Agregar columna TOTAL
      # Para nacionalidad: sumar solo grupos de 1er nivel (no solapantes)
      # Para paso: sumar todas las columnas numéricas
      GRUPOS_NAC_TOTAL <- c("AFRICA", "AMERICA CENTRAL", "AMERICA DEL NORTE",
                            "AMERICA DEL SUR", "CARIBE", "ASIA", "EUROPA",
                            "MEDIO ORIENTE", "OCEANIA", "OTROS")
      cols_num <- names(df)[sapply(df, is.numeric)]
      if (length(cols_num) > 0) {
        if (grepl("nacionalidad", nombre, ignore.case = TRUE)) {
          cols_para_total <- intersect(GRUPOS_NAC_TOTAL, cols_num)
          df$TOTAL <- if (length(cols_para_total) > 0) rowSums(df[cols_para_total], na.rm = TRUE) else NA_real_
        } else {
          df$TOTAL <- rowSums(df[cols_num], na.rm = TRUE)
        }
      }

      # Calcular tendencias
      tendencias <- calcular_tendencias_llegadas(df)

      # Unir datos originales con tendencias
      df_completo <- left_join(df, tendencias, by = "Fecha")

      # Guardar como RDS con tendencias (eficiente para 150+ columnas)
      out_path_rds <- file.path(out_dir, paste0(nombre, ".rds"))
      saveRDS(df_completo, out_path_rds)
      message(sprintf("[LLEGADAS] %s -> %s (%d filas x %d cols)",
                      nombre, basename(out_path_rds), nrow(df_completo), ncol(df_completo)))

      # CSV sin tendencias (solo datos originales + TOTAL) para forecast
      out_path_csv <- file.path(out_dir, paste0(nombre, ".csv"))
      cols_sin_trend <- names(df)[!grepl("_trend$", names(df))]
      write_csv(df[cols_sin_trend], out_path_csv)

    }, error = function(e) {
      message(sprintf("[LLEGADAS FAIL] %s: %s", nombre, e$message))
    })
  }

  message("[LLEGADAS DONE]")
}

# ---------------------------------------------------------------------------
# Forecast ARIMA/SARIMAX para llegadas de turistas
# Lee los CSVs wide de llegadas, forecast cada serie, genera CSVs en formato long
# ---------------------------------------------------------------------------
run_llegadas_forecast <- function(out_dir, forecast_horizon = 6,
                                  seasonal_period = 12,
                                  use_pandemic_dummy = TRUE) {
  archivos <- list.files(out_dir, pattern = "^llegadas_.*\\.csv$", full.names = TRUE)
  archivos <- archivos[!grepl("_forecast", basename(archivos))]
  if (length(archivos) == 0) {
    warning("[LLEGADAS_FORECAST] No hay CSVs de llegadas en ", out_dir)
    return(invisible(NULL))
  }

  for (f in archivos) {
    nombre <- tools::file_path_sans_ext(basename(f))
    tryCatch({
      df <- readr::read_csv(f, show_col_types = FALSE)
      df$Fecha <- as.Date(df$Fecha)
      df <- df[order(df$Fecha), ]

      # Columnas de series originales (excluir Fecha y *_trend)
      all_cols <- names(df)
      series_cols <- all_cols[all_cols != "Fecha" & !grepl("_trend$", all_cols) & sapply(df, is.numeric)]

      # Filtrar series con >= 36 observaciones validas
      valid_cols <- Filter(function(col) sum(!is.na(df[[col]])) >= 36, series_cols)

      # Paralelizar forecast por serie con future_lapply
      results <- future.apply::future_lapply(valid_cols, function(col) {
        valores <- df[[col]]
        fechas <- df$Fecha
        valid <- !is.na(valores)
        fc <- tryCatch(
          .forecast_llegadas_series(fechas[valid], valores[valid], forecast_horizon,
                                   seasonal_period, use_pandemic_dummy),
          error = function(e) NULL
        )
        if (!is.null(fc)) {
          fc$Variable <- col
          fc
        } else NULL
      }, future.seed = TRUE)
      names(results) <- valid_cols
      results <- Filter(Negate(is.null), results)

      if (length(results) > 0) {
        fc_df <- dplyr::bind_rows(results)
        out_path <- file.path(out_dir, paste0(nombre, "_forecast.csv"))
        readr::write_csv(fc_df, out_path)
        message(sprintf("[LLEGADAS_FORECAST] %s -> %s (%d series, %d filas)",
                        nombre, basename(out_path), length(results), nrow(fc_df)))
      } else {
        message(sprintf("[LLEGADAS_FORECAST] %s: ninguna serie con >=36 obs", nombre))
      }

    }, error = function(e) {
      message(sprintf("[LLEGADAS_FORECAST FAIL] %s: %s", nombre, e$message))
    })
  }

  message("[LLEGADAS_FORECAST DONE]")
}

# Helper: forecast ARIMA + SARIMAX para una serie individual de llegadas
.forecast_llegadas_series <- function(fechas, valores, forecast_horizon,
                                      seasonal_period, use_pandemic_dummy) {
  serie <- ts(valores, frequency = seasonal_period,
              start = c(as.integer(format(fechas[1], "%Y")),
                        as.integer(format(fechas[1], "%m"))))

  start_future <- max(fechas) %m+% months(1)
  fechas_future <- seq(start_future, by = "month", length.out = forecast_horizon)

  # --- ARIMA (non-seasonal) ---
  arima_result <- tryCatch({
    mod <- auto.arima(serie, seasonal = FALSE, stepwise = TRUE,
                      approximation = FALSE, trace = FALSE)
    fc <- forecast::forecast(mod, h = forecast_horizon, level = 95)
    list(
      mean  = pmax(as.vector(fc$mean), 0),
      lower = pmax(as.vector(fc$lower[, 1]), 0),
      upper = pmax(as.vector(fc$upper[, 1]), 0)
    )
  }, error = function(e) NULL)

  # --- SARIMAX (seasonal + pandemic dummies) ---
  sarimax_result <- tryCatch({
    xreg_in  <- if (use_pandemic_dummy) crear_dummies_pandemia(fechas) else NULL
    xreg_fut <- if (use_pandemic_dummy) crear_dummies_pandemia(fechas_future) else NULL
    mod <- auto.arima(serie, seasonal = TRUE, xreg = xreg_in,
                      stepwise = TRUE, approximation = FALSE,
                      trace = FALSE, D = 1)
    fc <- forecast::forecast(mod, h = forecast_horizon, level = 95, xreg = xreg_fut)
    list(
      mean  = pmax(as.vector(fc$mean), 0),
      lower = pmax(as.vector(fc$lower[, 1]), 0),
      upper = pmax(as.vector(fc$upper[, 1]), 0)
    )
  }, error = function(e) NULL)

  if (is.null(arima_result) && is.null(sarimax_result)) return(NULL)

  data.frame(
    Fecha              = fechas_future,
    arima_Pronostico   = if (!is.null(arima_result)) arima_result$mean else NA_real_,
    arima_li           = if (!is.null(arima_result)) arima_result$lower else NA_real_,
    arima_ls           = if (!is.null(arima_result)) arima_result$upper else NA_real_,
    sarimax_Pronostico = if (!is.null(sarimax_result)) sarimax_result$mean else NA_real_,
    sarimax_li         = if (!is.null(sarimax_result)) sarimax_result$lower else NA_real_,
    sarimax_ls         = if (!is.null(sarimax_result)) sarimax_result$upper else NA_real_,
    stringsAsFactors   = FALSE
  )
}
