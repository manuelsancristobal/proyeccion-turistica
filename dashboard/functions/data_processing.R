# functions/data_processing.R
# Carga datos pre-computados desde data/transformed/

library(yaml)

read_and_process_data <- function() {
  # Leer config para obtener paths
  # Primero intentar localmente (necesario para despliegues)
  cfg_path <- "config.yml"
  if (!file.exists(cfg_path)) {
    # Fallback a directorio padre (desarrollo local tipico)
    cfg_path <- normalizePath(file.path("..", "config.yml"), mustWork = FALSE)
  }
  
  if (!file.exists(cfg_path)) {
    stop("ERROR: No se encontro config.yml. Asegurate de copiarlo a la carpeta dashboard antes del despliegue.")
  }
  
  cfg <- yaml::read_yaml(cfg_path)
  
  base_root <- cfg$base_path
  if (base_root == "") base_root <- "."

  # Determinar la carpeta de datos transformados
  transformed_path <- cfg$paths$data_transformed

  # Detectar si estamos dentro de dashboard/ (despliegue en la nube)
  # Si la ruta con prefijo "dashboard/" no existe pero sin el si, estamos desplegados
  actual_transformed <- file.path(base_root, transformed_path)
  if (!dir.exists(actual_transformed) && grepl("^dashboard/", transformed_path)) {
    transformed_path <- gsub("^dashboard/", "", transformed_path)
  }
  
  transformed_llegadas <- file.path(base_root, transformed_path, "llegadas")
  transformed_salidas <- file.path(base_root, transformed_path, "salidas")
  transformed_trafico <- file.path(base_root, transformed_path, "trafico_aereo")

  result <- list()

  # --- Llegadas (nacionalidad y paso) ---
  # Intentar cargar RDS pre-computado, si no, cargar CSV
  nac_rds <- file.path(transformed_llegadas, "llegadas_nacionalidad.rds")
  paso_rds <- file.path(transformed_llegadas, "llegadas_paso.rds")

  if (file.exists(nac_rds)) {
    result$nacionalidad <- readRDS(nac_rds)
  } else {
    nac_csv <- file.path(transformed_llegadas, "llegadas_nacionalidad.csv")
    if (file.exists(nac_csv)) {
      df <- readr::read_csv(nac_csv, show_col_types = FALSE)
      df$Fecha <- as.Date(df$Fecha)
      # Si no tiene tendencias, calcularlas on-the-fly (fallback defensivo)
      if (!any(grepl("_trend$", names(df)))) {
        warning("[DASHBOARD] llegadas_nacionalidad.rds no encontrado y CSV sin tendencias. ",
                "Calculando STL on-the-fly. Verificar que Transform genero los RDS correctamente.")
        tendencias <- calcular_tendencias(df)
        df <- left_join(df, tendencias, by = "Fecha")
      }
      result$nacionalidad <- df
    }
  }

  if (file.exists(paso_rds)) {
    result$aeropuerto <- readRDS(paso_rds)
  } else {
    paso_csv <- file.path(transformed_llegadas, "llegadas_paso.csv")
    if (file.exists(paso_csv)) {
      df <- readr::read_csv(paso_csv, show_col_types = FALSE)
      df$Fecha <- as.Date(df$Fecha)
      if (!any(grepl("_trend$", names(df)))) {
        warning("[DASHBOARD] llegadas_paso.rds no encontrado y CSV sin tendencias. ",
                "Calculando STL on-the-fly. Verificar que Transform genero los RDS correctamente.")
        tendencias <- calcular_tendencias(df)
        df <- left_join(df, tendencias, by = "Fecha")
      }
      result$aeropuerto <- df
    }
  }

  # --- Salidas (turismo emisivo) ---
  merged_files <- list.files(transformed_salidas, pattern = "^merged_\\d{6}\\.csv$",
                             full.names = TRUE)
  if (length(merged_files) > 0) {
    # Cargar todos los merged y combinarlos
    salidas_list <- lapply(merged_files, function(f) {
      df <- readr::read_csv(f, show_col_types = FALSE)
      df$Fecha <- as.Date(df$Fecha)
      code <- gsub(".*_(\\d{6})\\.csv$", "\\1", basename(f))
      df$Codigo <- code
      df
    })
    result$salidas <- do.call(rbind, salidas_list)
  }

  # Frecuencia vuelos salientes
  freq_sal_csv <- file.path(transformed_salidas, "frecuencia_vuelos_salientes.csv")
  if (file.exists(freq_sal_csv)) {
    df <- readr::read_csv(freq_sal_csv, show_col_types = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    result$frecuencia_salidas <- df
  }

  # Unified forecast
  unified_path <- file.path(transformed_salidas, "unified_forecast.csv")
  if (file.exists(unified_path)) {
    result$unified_forecast <- readr::read_csv(unified_path, show_col_types = FALSE)
    result$unified_forecast$Fecha <- as.Date(result$unified_forecast$Fecha)
  }

  # --- Trafico aereo ---
  trafico_csv <- file.path(transformed_trafico, "trafico_aereo.csv")
  if (!file.exists(trafico_csv)) {
    # Intentar desde raw (usando la raiz calculada)
    trafico_csv <- file.path(base_root, cfg$paths$data_raw_trafico, "trafico_aereo.csv")
  }
  if (file.exists(trafico_csv)) {
    result$trafico <- readr::read_csv(trafico_csv, show_col_types = FALSE)
  }

  # --- Load Factor (pais y aeropuerto) ---
  lf_pais_csv <- file.path(transformed_trafico, "load_factor_pais.csv")
  if (file.exists(lf_pais_csv)) {
    df <- readr::read_csv(lf_pais_csv, show_col_types = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    result$load_factor_pais <- df
  }

  lf_aero_csv <- file.path(transformed_trafico, "load_factor_aeropuerto.csv")
  if (file.exists(lf_aero_csv)) {
    df <- readr::read_csv(lf_aero_csv, show_col_types = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    result$load_factor_aeropuerto <- df
  }

  # --- Llegadas Forecast (ARIMA/SARIMAX) ---
  ll_fc_nac_csv <- file.path(transformed_llegadas, "llegadas_nacionalidad_forecast.csv")
  if (file.exists(ll_fc_nac_csv)) {
    df <- readr::read_csv(ll_fc_nac_csv, show_col_types = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    result$llegadas_forecast_nacionalidad <- df
  }

  ll_fc_paso_csv <- file.path(transformed_llegadas, "llegadas_paso_forecast.csv")
  if (file.exists(ll_fc_paso_csv)) {
    df <- readr::read_csv(ll_fc_paso_csv, show_col_types = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    result$llegadas_forecast_paso <- df
  }

  # --- Conectividad por pais ---
  conect_csv <- file.path(transformed_trafico, "conectividad_pais.csv")
  if (file.exists(conect_csv)) {
    df <- readr::read_csv(conect_csv, show_col_types = FALSE)
    df$FechaInicio <- as.Date(df$FechaInicio)
    df$FechaFin    <- as.Date(df$FechaFin)
    result$conectividad_pais <- df
  }

  # --- Analisis de aeropuerto ---
  aero_csv <- file.path(transformed_trafico, "analisis_aeropuerto.csv")
  if (file.exists(aero_csv)) {
    result$analisis_aeropuerto <- readr::read_csv(aero_csv, show_col_types = FALSE)
  }

  return(result)
}
