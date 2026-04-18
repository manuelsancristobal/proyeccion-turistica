# transform/trafico_transform.R
# Transformacion y agregacion de datos de trafico aereo

#' Ejecuta transformacion de trafico aereo
#' Acepta datos pre-leidos (df_trafico) o lee desde raw_dir si no se proveen.
run_trafico_transform <- function(raw_dir, out_dir, df_trafico = NULL) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.null(df_trafico)) {
    df_trafico <- read_trafico_normalizado(raw_dir)
  }
  if (is.null(df_trafico) || nrow(df_trafico) == 0) {
    warning("No hay datos de trafico aereo")
    return(invisible(NULL))
  }

  # Validar columnas requeridas
  required <- c("Fecha", "Direccion", "Tipo", "Pasajeros")
  missing <- setdiff(required, names(df_trafico))
  if (length(missing) > 0) {
    warning(sprintf("[TRAFICO] Columnas faltantes: %s", paste(missing, collapse = ", ")))
    return(invisible(NULL))
  }

  df_all <- df_trafico[!is.na(df_trafico$Fecha) & !is.na(df_trafico$Pasajeros),
                       c("Fecha", "Direccion", "Tipo", "Pasajeros")]
  message(sprintf("[TRAFICO] %d filas procesadas", nrow(df_all)))

  # Agregar por Fecha/Direccion/Tipo
  df_agg <- df_all %>%
    dplyr::group_by(Fecha, Direccion, Tipo) %>%
    dplyr::summarise(Pasajeros = sum(Pasajeros, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(Fecha)

  # Guardar consolidado
  out_path <- file.path(out_dir, "trafico_aereo_transformed.csv")
  readr::write_csv(df_agg, out_path)
  message(sprintf("[TRAFICO] Consolidado: %s (%d filas)", out_path, nrow(df_agg)))

  # Generar subsets por Direccion/Tipo
  for (dir_val in unique(df_agg$Direccion)) {
    for (tipo_val in unique(df_agg$Tipo)) {
      subset_df <- df_agg %>%
        dplyr::filter(Direccion == dir_val, Tipo == tipo_val)
      if (nrow(subset_df) == 0) next

      dir_label <- tolower(gsub("[^a-zA-Z]", "", dir_val))
      tipo_label <- tolower(gsub("[^a-zA-Z]", "", tipo_val))
      subset_name <- paste0("trafico_", dir_label, "_", tipo_label, ".csv")
      subset_path <- file.path(out_dir, subset_name)
      readr::write_csv(subset_df, subset_path)
      message(sprintf("[TRAFICO] Subset: %s (%d filas)", subset_name, nrow(subset_df)))
    }
  }

  message("[TRAFICO DONE]")
}

#' Calcula Load Factor por pais y aeropuerto para vuelos internacionales de llegada
#' Estima capacidad usando percentil 95 de pasajeros por ruta con ventana movil de 12 meses
#' Acepta datos pre-leidos (df_trafico) o lee desde raw_dir si no se proveen.
run_load_factor_transform <- function(raw_dir, out_dir, fecha_inicio = NULL, df_trafico = NULL) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.null(df_trafico)) {
    df_trafico <- read_trafico_normalizado(raw_dir)
  }
  if (is.null(df_trafico) || nrow(df_trafico) == 0) {
    warning("No hay datos para load factor")
    return(invisible(NULL))
  }

  country_map <- get_country_mapping()
  country_excl <- get_country_exclusions()
  airport_map <- get_airport_mapping()

  df <- df_trafico

  # Mapear columnas estándar a las que necesita load factor
  has_operador <- "Operador" %in% names(df)
  has_origen   <- "Origen" %in% names(df)
  has_destino  <- "Destino" %in% names(df)
  has_pais     <- "PaisOrigen" %in% names(df)

  if (!has_operador || !has_origen || !"Pasajeros" %in% names(df)) {
    warning("[LOAD_FACTOR] Columnas requeridas no encontradas (Pasajeros, Operador, Origen)")
    return(invisible(NULL))
  }

  # Filtrar: solo vuelos internacionales de llegada
  if ("Direccion" %in% names(df)) {
    df <- df[df$Direccion == "LLEGAN", ]
  }
  if ("Tipo" %in% names(df)) {
    df <- df[df$Tipo == "INTERNACIONAL", ]
  }

  if (nrow(df) == 0) {
    warning("[LOAD_FACTOR] No hay datos de vuelos internacionales de llegada")
    return(invisible(NULL))
  }

  df <- df[!is.na(df$Fecha) & !is.na(df$Pasajeros), ]

  # Construir clave de ruta: Operador + Origen + Destino
  df$operador_clean <- df$Operador
  df$orig_clean <- df$Origen
  dest_val <- if (has_destino) df$Destino else "NA"
  df$clave_ruta <- paste(df$operador_clean, df$orig_clean, dest_val, sep = "|")

  # Calcular percentil 95 de pasajeros por ruta con ventana movil de 12 meses
  # Para cada fila, P95 se calcula con los datos de los 12 meses anteriores (incluyendo el mes actual)
  df <- df %>% dplyr::arrange(clave_ruta, Fecha)

  cap_p95_list <- df %>%
    dplyr::group_by(clave_ruta) %>%
    dplyr::group_split() %>%
    lapply(function(grp) {
      # P95 rolling 12 meses usando ventana basada en fecha
      grp$Capacidad_P95 <- slider::slide_index_dbl(
        grp$Pasajeros,
        grp$Fecha,
        .f = ~stats::quantile(.x, 0.95, na.rm = TRUE),
        .before = months(11),
        .after = 0
      )
      grp
    })

  df <- dplyr::bind_rows(cap_p95_list)
  n_rutas <- length(unique(df$clave_ruta))

  message(sprintf("[LOAD_FACTOR] %d rutas unicas, %d filas con P95 rolling 12m", n_rutas, nrow(df)))

  # --- Output 1: Load Factor por pais ---
  if (has_pais) {
    df$pais_raw <- df$PaisOrigen

    df$Pais <- ifelse(
      df$pais_raw %in% names(country_map),
      country_map[df$pais_raw],
      df$pais_raw
    )

    df_pais <- df[!df$pais_raw %in% country_excl, ]

    lf_pais <- df_pais %>%
      dplyr::group_by(Fecha, Pais) %>%
      dplyr::summarise(
        Pasajeros = sum(Pasajeros, na.rm = TRUE),
        Capacidad = sum(Capacidad_P95, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(
        LoadFactor = ifelse(Capacidad > 0, (Pasajeros / Capacidad) * 100, NA_real_)
      ) %>%
      dplyr::arrange(Fecha, Pais)

    if (!is.null(fecha_inicio)) {
      lf_pais <- lf_pais[lf_pais$Fecha >= fecha_inicio, ]
    }

    out_pais <- file.path(out_dir, "load_factor_pais.csv")
    readr::write_csv(lf_pais, out_pais)
    message(sprintf("[LOAD_FACTOR] Pais: %s (%d filas)", out_pais, nrow(lf_pais)))
  }

  # --- Output 2: Load Factor por aeropuerto ---
  if (has_destino) {
    df$aero_raw <- df$Destino

    df_aero <- df[df$aero_raw %in% names(airport_map), ]
    df_aero$Aeropuerto <- airport_map[df_aero$aero_raw]

    lf_aero <- df_aero %>%
      dplyr::group_by(Fecha, Aeropuerto) %>%
      dplyr::summarise(
        Pasajeros = sum(Pasajeros, na.rm = TRUE),
        Capacidad = sum(Capacidad_P95, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(
        LoadFactor = ifelse(Capacidad > 0, (Pasajeros / Capacidad) * 100, NA_real_)
      ) %>%
      dplyr::arrange(Fecha, Aeropuerto)

    if (!is.null(fecha_inicio)) {
      lf_aero <- lf_aero[lf_aero$Fecha >= fecha_inicio, ]
    }

    out_aero <- file.path(out_dir, "load_factor_aeropuerto.csv")
    readr::write_csv(lf_aero, out_aero)
    message(sprintf("[LOAD_FACTOR] Aeropuerto: %s (%d filas)", out_aero, nrow(lf_aero)))
  }

  message("[LOAD_FACTOR DONE]")
}

# ---------------------------------------------------------------------------
# Frecuencia de vuelos internacionales salientes (pasajeros + operaciones)
# ---------------------------------------------------------------------------
run_frecuencia_salidas_transform <- function(raw_dir, out_dir, df_trafico = NULL) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.null(df_trafico)) {
    df_trafico <- read_trafico_normalizado(raw_dir)
  }
  if (is.null(df_trafico) || nrow(df_trafico) == 0) {
    warning("No hay datos para frecuencia de salidas")
    return(invisible(NULL))
  }

  df <- df_trafico

  if (!"Pasajeros" %in% names(df)) {
    warning("[FRECUENCIA_SALIDAS] Columna Pasajeros no encontrada")
    return(invisible(NULL))
  }

  # Filtrar: solo vuelos internacionales de salida
  if ("Direccion" %in% names(df)) df <- df[df$Direccion == "SALEN", ]
  if ("Tipo" %in% names(df))      df <- df[df$Tipo == "INTERNACIONAL", ]

  if (nrow(df) == 0) {
    warning("[FRECUENCIA_SALIDAS] No hay datos de vuelos internacionales de salida")
    return(invisible(NULL))
  }

  df <- df[!is.na(df$Fecha) & !is.na(df$Pasajeros), ]

  resultado <- df %>%
    dplyr::group_by(Fecha) %>%
    dplyr::summarise(
      Pasajeros = sum(Pasajeros, na.rm = TRUE),
      Operaciones = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::arrange(Fecha)

  out_path <- file.path(out_dir, "frecuencia_vuelos_salientes.csv")
  readr::write_csv(resultado, out_path)
  message(sprintf("[FRECUENCIA_SALIDAS] %s (%d filas)", out_path, nrow(resultado)))
}

# ---------------------------------------------------------------------------
# Conectividad aerea por pais
# ---------------------------------------------------------------------------
run_connectivity_transform <- function(raw_dir, out_dir, df_trafico = NULL) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.null(df_trafico)) {
    df_trafico <- read_trafico_normalizado(raw_dir)
  }
  if (is.null(df_trafico) || !"PaisOrigen" %in% names(df_trafico)) {
    warning("[CONNECTIVITY] No hay datos de trafico con columna de pais")
    return(invisible(NULL))
  }

  # Filtrar vuelos internacionales de llegada
  df <- df_trafico
  if ("Direccion" %in% names(df)) df <- df[df$Direccion == "LLEGAN", ]
  if ("Tipo" %in% names(df))      df <- df[df$Tipo == "INTERNACIONAL", ]
  if (nrow(df) == 0) {
    warning("[CONNECTIVITY] No hay datos de vuelos internacionales de llegada")
    return(invisible(NULL))
  }

  country_map  <- get_country_mapping()
  country_excl <- get_country_exclusions()

  df$pais_raw <- df$PaisOrigen
  df$Pais <- ifelse(df$pais_raw %in% names(country_map), country_map[df$pais_raw], df$pais_raw)
  df <- df[!df$pais_raw %in% country_excl, ]

  fecha_max_global <- max(df$Fecha, na.rm = TRUE)
  fecha_12m <- seq.Date(fecha_max_global, by = "-11 months", length.out = 2)[2]

  conectividad <- df %>%
    dplyr::group_by(Pais) %>%
    dplyr::summarise(
      FechaInicio = min(Fecha, na.rm = TRUE),
      FechaFin    = max(Fecha, na.rm = TRUE),
      MesesTotales = dplyr::n_distinct(Fecha),
      .groups = "drop"
    )

  # Rutas activas en los ultimos 12 meses (orig+dest distintas)
  df_reciente <- df[df$Fecha >= fecha_12m, ]
  if ("Origen" %in% names(df) && "Destino" %in% names(df)) {
    rutas_activas <- df_reciente %>%
      dplyr::group_by(Pais) %>%
      dplyr::summarise(
        NRutasActivas = dplyr::n_distinct(paste(Origen, Destino, sep = "|")),
        .groups = "drop"
      )
  } else {
    rutas_activas <- df_reciente %>%
      dplyr::group_by(Pais) %>%
      dplyr::summarise(NRutasActivas = dplyr::n(), .groups = "drop")
  }

  # Determinar si esta activo (tiene datos en los ultimos 12 meses)
  paises_activos <- unique(df_reciente$Pais)

  conectividad <- conectividad %>%
    dplyr::left_join(rutas_activas, by = "Pais") %>%
    dplyr::mutate(
      NRutasActivas = ifelse(is.na(NRutasActivas), 0L, as.integer(NRutasActivas)),
      Activo = Pais %in% paises_activos
    ) %>%
    dplyr::arrange(Pais)

  out_path <- file.path(out_dir, "conectividad_pais.csv")
  readr::write_csv(conectividad, out_path)
  message(sprintf("[CONNECTIVITY] %s (%d paises)", out_path, nrow(conectividad)))
}

# ---------------------------------------------------------------------------
# Analisis de aeropuerto (diversidad, concentracion, operadores)
# ---------------------------------------------------------------------------
run_airport_analysis_transform <- function(raw_dir, out_dir, df_trafico = NULL) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.null(df_trafico)) {
    df_trafico <- read_trafico_normalizado(raw_dir)
  }
  if (is.null(df_trafico) || nrow(df_trafico) == 0) {
    warning("[AIRPORT_ANALYSIS] No hay datos de trafico")
    return(invisible(NULL))
  }

  airport_map  <- get_airport_mapping()
  country_map  <- get_country_mapping()

  # Filtrar vuelos internacionales de llegada
  df <- df_trafico
  if ("Direccion" %in% names(df)) df <- df[df$Direccion == "LLEGAN", ]
  if ("Tipo" %in% names(df))      df <- df[df$Tipo == "INTERNACIONAL", ]

  if (!"Destino" %in% names(df)) {
    warning("[AIRPORT_ANALYSIS] No se encontro columna de destino")
    return(invisible(NULL))
  }

  # Filtrar solo aeropuertos mapeados
  df <- df[df$Destino %in% names(airport_map), ]
  if (nrow(df) == 0) {
    warning("[AIRPORT_ANALYSIS] No hay datos para aeropuertos mapeados")
    return(invisible(NULL))
  }
  df$Aeropuerto <- airport_map[df$Destino]

  # Mapear pais de origen
  if ("PaisOrigen" %in% names(df)) {
    df$PaisOrigen <- ifelse(df$PaisOrigen %in% names(country_map), country_map[df$PaisOrigen], df$PaisOrigen)
  }

  fecha_max_global <- max(df$Fecha, na.rm = TRUE)
  fecha_12m <- seq.Date(fecha_max_global, by = "-11 months", length.out = 2)[2]
  df_reciente <- df[df$Fecha >= fecha_12m, ]

  # --- Diversidad de paises de origen ---
  diversidad <- if ("PaisOrigen" %in% names(df_reciente)) {
    df_reciente %>%
      dplyr::group_by(Aeropuerto) %>%
      dplyr::summarise(NPaisesOrigen = dplyr::n_distinct(PaisOrigen), .groups = "drop")
  } else {
    data.frame(Aeropuerto = character(), NPaisesOrigen = integer())
  }

  # --- Concentracion top 3 paises (por pasajeros) ---
  top3 <- if ("PaisOrigen" %in% names(df_reciente) && "Pasajeros" %in% names(df_reciente)) {
    pax_por_aero_pais <- df_reciente %>%
      dplyr::group_by(Aeropuerto, PaisOrigen) %>%
      dplyr::summarise(Pax = sum(Pasajeros, na.rm = TRUE), .groups = "drop")

    pax_por_aero_pais %>%
      dplyr::group_by(Aeropuerto) %>%
      dplyr::mutate(PaxTotal = sum(Pax, na.rm = TRUE)) %>%
      dplyr::arrange(Aeropuerto, dplyr::desc(Pax)) %>%
      dplyr::slice_head(n = 3) %>%
      dplyr::summarise(
        Top3Paises = paste0(PaisOrigen, " (", round(Pax / PaxTotal * 100, 1), "%)", collapse = ", "),
        ConcentracionTop3Pct = round(sum(Pax) / dplyr::first(PaxTotal) * 100, 1),
        .groups = "drop"
      )
  } else {
    data.frame(Aeropuerto = character(), Top3Paises = character(), ConcentracionTop3Pct = numeric())
  }

  # --- Operadores activos ---
  operadores <- if ("Operador" %in% names(df_reciente)) {
    df_reciente %>%
      dplyr::group_by(Aeropuerto) %>%
      dplyr::summarise(NOperadores = dplyr::n_distinct(Operador), .groups = "drop")
  } else {
    data.frame(Aeropuerto = character(), NOperadores = integer())
  }

  # --- Patron estacional (meses activos en ultimos 3 anios) ---
  fecha_3a <- seq.Date(fecha_max_global, by = "-35 months", length.out = 2)[2]
  df_3a <- df[df$Fecha >= fecha_3a, ]
  estacionalidad <- df_3a %>%
    dplyr::group_by(Aeropuerto) %>%
    dplyr::summarise(
      MesesActivos = dplyr::n_distinct(Mes),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      PatronEstacional = dplyr::case_when(
        MesesActivos >= 10 ~ "Todo el ano",
        MesesActivos >= 4  ~ "Estacional",
        TRUE               ~ "Limitado"
      )
    )

  # Combinar todo
  resultado <- diversidad %>%
    dplyr::left_join(top3, by = "Aeropuerto") %>%
    dplyr::left_join(operadores, by = "Aeropuerto") %>%
    dplyr::left_join(estacionalidad, by = "Aeropuerto") %>%
    dplyr::arrange(Aeropuerto)

  out_path <- file.path(out_dir, "analisis_aeropuerto.csv")
  readr::write_csv(resultado, out_path)
  message(sprintf("[AIRPORT_ANALYSIS] %s (%d aeropuertos)", out_path, nrow(resultado)))
}
