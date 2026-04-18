# transform/unification.R
# Unificacion de datos: merge real + trend + forecast por YYYYMM

library(dplyr)
library(readr)

#' Unifica real + trend + arima + sarimax por codigo YYYYMM
#' Genera merged_YYYYMM.csv y unified_forecast.csv
run_unification <- function(raw_dir, transformed_dir) {
  dir.create(transformed_dir, recursive = TRUE, showWarnings = FALSE)

  # Leer todos los archivos por tipo
  reales <- list.files(raw_dir, pattern = "^real_\\d{6}\\.csv$", full.names = TRUE)
  trends <- list.files(transformed_dir, pattern = "^trend_\\d{6}\\.csv$", full.names = TRUE)
  arimas <- list.files(transformed_dir, pattern = "^arima_\\d{6}\\.csv$", full.names = TRUE)
  sarimax <- list.files(transformed_dir, pattern = "^sarimax_\\d{6}\\.csv$", full.names = TRUE)

  # Extraer codigos unicos
  codigos <- unique(gsub(".*_(\\d{6})\\.csv$", "\\1", basename(reales)))

  if (length(codigos) == 0) {
    warning("No se encontraron archivos para unificar")
    return(invisible(NULL))
  }

  all_forecasts <- list()

  for (code in codigos) {
    tryCatch({
      # Leer real
      real_file <- file.path(raw_dir, paste0("real_", code, ".csv"))
      if (!file.exists(real_file)) next
      df_real <- read_csv(real_file, show_col_types = FALSE) %>%
        mutate(Fecha = as.Date(Fecha))

      # Iniciar merge con real
      merged <- df_real

      # Merge trend
      trend_file <- file.path(transformed_dir, paste0("trend_", code, ".csv"))
      if (file.exists(trend_file)) {
        df_trend <- read_csv(trend_file, show_col_types = FALSE) %>%
          mutate(Fecha = as.Date(Fecha))
        merged <- full_join(merged, df_trend, by = "Fecha")
      }

      # Merge arima
      arima_file <- file.path(transformed_dir, paste0("arima_", code, ".csv"))
      if (file.exists(arima_file)) {
        df_arima <- read_csv(arima_file, show_col_types = FALSE) %>%
          mutate(Fecha = as.Date(Fecha)) %>%
          rename(arima_Pronostico = Pronostico, arima_li = li_95, arima_ls = ls_95)
        merged <- full_join(merged, df_arima, by = "Fecha")

        # Guardar para unified_forecast
        all_forecasts[[code]] <- df_arima %>%
          select(Fecha, arima_Pronostico) %>%
          rename(!!code := arima_Pronostico)
      }

      # Merge sarimax
      sarimax_file <- file.path(transformed_dir, paste0("sarimax_", code, ".csv"))
      if (file.exists(sarimax_file)) {
        df_sarimax <- read_csv(sarimax_file, show_col_types = FALSE) %>%
          mutate(Fecha = as.Date(Fecha)) %>%
          rename(sarimax_Pronostico = Pronostico, sarimax_li = li_95, sarimax_ls = ls_95)
        merged <- full_join(merged, df_sarimax, by = "Fecha")
      }

      # Guardar merged
      merged <- merged %>% arrange(Fecha)
      out_path <- file.path(transformed_dir, paste0("merged_", code, ".csv"))
      write_csv(merged, out_path)
      message(sprintf("[UNIFY] merged_%s.csv (%d filas)", code, nrow(merged)))

    }, error = function(e) {
      message(sprintf("[UNIFY FAIL] %s: %s", code, e$message))
    })
  }

  # Crear unified_forecast.csv
  if (length(all_forecasts) > 0) {
    unified <- all_forecasts[[1]]
    for (i in seq_along(all_forecasts)[-1]) {
      unified <- full_join(unified, all_forecasts[[i]], by = "Fecha")
    }
    unified <- unified %>% arrange(Fecha)
    out_path <- file.path(transformed_dir, "unified_forecast.csv")
    write_csv(unified, out_path)
    message(sprintf("[UNIFY] unified_forecast.csv (%d filas x %d cols)", nrow(unified), ncol(unified)))
  }

  message("[UNIFICATION DONE]")
}
