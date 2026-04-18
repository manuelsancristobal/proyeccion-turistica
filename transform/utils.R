# transform/utils.R
# Utilidades compartidas para la capa Transform

library(dplyr)
library(readr)

#' Lee todos los CSV real_*.csv de un directorio
#' Retorna lista con nombre = nombre_archivo_sin_extension, valor = data.frame(Fecha, Cantidad)
read_raw_salidas <- function(dir_path) {
  archivos <- list.files(dir_path, pattern = "^real_.*\\.csv$", full.names = TRUE)
  if (length(archivos) == 0) {
    warning(paste("No se encontraron archivos real_*.csv en", dir_path))
    return(list())
  }

  result <- list()
  for (f in archivos) {
    nombre <- tools::file_path_sans_ext(basename(f))
    df <- readr::read_csv(f, show_col_types = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    df <- df %>% arrange(Fecha) %>% filter(!is.na(Fecha), !is.na(Cantidad))
    result[[nombre]] <- df
  }

  message(sprintf("Leidos %d archivos de salidas desde %s", length(result), dir_path))
  return(result)
}

#' Convierte data.frame con Fecha y Cantidad a serie temporal mensual
to_monthly_ts <- function(df, freq = 12) {
  df <- df %>% arrange(Fecha)
  start_year <- as.numeric(format(min(df$Fecha), "%Y"))
  start_month <- as.numeric(format(min(df$Fecha), "%m"))
  ts(df$Cantidad, start = c(start_year, start_month), frequency = freq)
}

#' Extrae codigo YYYYMM del nombre de archivo
extract_code <- function(nombre) {
  m <- regmatches(nombre, regexpr("\\d{6}", nombre))
  if (length(m) > 0) m else "SINFECHA"
}

#' Calcula tendencias STL para columnas numéricas de un DataFrame.
#'
#' @param data Data.frame con columna Fecha y columnas numéricas.
#' @param robust Logical. Usar STL robusto (default TRUE).
#' @param clamp_zero Logical. Clampear valores negativos de tendencia a 0 (default TRUE).
#' @param freq Frecuencia de la serie temporal (default 12).
#' @return Data.frame con Fecha y columnas *_trend.
calcular_stl_tendencias <- function(data, robust = TRUE, clamp_zero = TRUE, freq = 12) {
  tendencias <- data.frame(Fecha = data$Fecha)
  cols_num <- names(data)[sapply(data, is.numeric)]

  for (col in cols_num) {
    tendencia <- tryCatch({
      serie <- ts(data[[col]], frequency = freq)
      stl_result <- stl(serie, s.window = "periodic", robust = robust)
      trend <- as.vector(stl_result$time.series[, "trend"])
      if (clamp_zero) trend[trend < 0] <- 0
      trend
    }, error = function(e) {
      as.vector(data[[col]])
    })
    tendencias[[paste0(col, "_trend")]] <- tendencia
  }

  return(tendencias)
}

#' Normaliza nombres de columnas: quita acentos y pasa a minusculas
.normalize_colnames <- function(nms) {
  nms_ascii <- iconv(nms, from = "UTF-8", to = "ASCII//TRANSLIT")
  nms_ascii <- ifelse(is.na(nms_ascii), nms, nms_ascii)
  tolower(trimws(nms_ascii))
}

#' Limpia valores numericos: elimina separador de miles y convierte a numerico
.clean_numeric <- function(x) {
  x <- stringr::str_trim(as.character(x))
  x <- gsub("^(\\d+)\\.(\\d{3})$", "\\1\\2", x)
  as.numeric(x)
}

#' Lee y prepara datos crudos de trafico aereo.
#' Soporta tanto el formato normalizado por Extract (columnas Fecha, Pasajeros, etc.)
#' como el formato legacy crudo (columnas Ano, Mes, OPER_2, NAC, etc.).
#' Retorna un data.frame con columnas estandar o NULL si no hay datos.
read_trafico_normalizado <- function(raw_dir) {
  archivos <- list.files(raw_dir, pattern = "\\.csv$", full.names = TRUE)
  # Excluir archivos _raw.csv (son backups del Extract nuevo)
  archivos <- archivos[!grepl("_raw\\.csv$", archivos)]
  if (length(archivos) == 0) return(NULL)

  all_data <- list()
  for (f in archivos) {
    tryCatch({
      df <- readr::read_csv(f, show_col_types = FALSE, locale = readr::locale(encoding = "UTF-8"))
      if (nrow(df) == 0) next
      all_data[[basename(f)]] <- df
    }, error = function(e) {
      message(sprintf("[TRAFICO READ FAIL] %s: %s", basename(f), e$message))
    })
  }
  if (length(all_data) == 0) return(NULL)

  df <- dplyr::bind_rows(all_data)

  # Detectar si el CSV ya esta normalizado (tiene columna Fecha) o es legacy
  if ("Fecha" %in% names(df)) {
    # Formato nuevo (normalizado por Extract)
    df$Fecha <- as.Date(df$Fecha)
    if ("Pasajeros" %in% names(df)) df$Pasajeros <- as.numeric(df$Pasajeros)
    if ("Mes" %in% names(df)) df$Mes <- as.numeric(df$Mes)
  } else {
    # Formato legacy: normalizar columnas in situ
    norm_names <- .normalize_colnames(names(df))
    names(df) <- norm_names

    ano_col  <- intersect(norm_names, c("ano", "anio", "year"))[1]
    mes_col  <- intersect(norm_names, c("mes", "month", "mm"))[1]
    pax_col  <- intersect(norm_names, c("pasajeros", "pax", "pax_total", "passengers"))[1]
    dir_col  <- intersect(norm_names, c("oper_2", "direccion", "direction"))[1]
    tipo_col <- intersect(norm_names, c("nac", "tipo", "type"))[1]
    operador_col <- intersect(norm_names, c("cod_operador", "operador"))[1]
    orig_col <- intersect(norm_names, c("orig_1"))[1]
    dest_col <- intersect(norm_names, c("dest_1"))[1]
    pais_col <- intersect(norm_names, c("orig_1_pais"))[1]

    if (is.na(ano_col) || is.na(mes_col)) {
      warning("[TRAFICO] No se detectaron columnas de ano/mes en formato legacy")
      return(NULL)
    }

    df[[ano_col]] <- .clean_numeric(df[[ano_col]])
    df[[mes_col]] <- .clean_numeric(df[[mes_col]])
    if (!is.na(pax_col)) df[[pax_col]] <- .clean_numeric(df[[pax_col]])

    df$Fecha <- as.Date(paste(df[[ano_col]], df[[mes_col]], "01", sep = "-"))
    df$Mes   <- df[[mes_col]]

    if (!is.na(pax_col))  df$Pasajeros  <- df[[pax_col]]
    if (!is.na(dir_col))  df$Direccion  <- toupper(stringr::str_trim(as.character(df[[dir_col]])))
    else                  df$Direccion  <- "TODOS"
    if (!is.na(tipo_col)) df$Tipo       <- toupper(stringr::str_trim(as.character(df[[tipo_col]])))
    else                  df$Tipo       <- "TODOS"
    if (!is.na(operador_col)) df$Operador    <- toupper(stringr::str_trim(as.character(df[[operador_col]])))
    if (!is.na(orig_col))     df$Origen      <- toupper(stringr::str_trim(as.character(df[[orig_col]])))
    if (!is.na(dest_col))     df$Destino     <- toupper(stringr::str_trim(as.character(df[[dest_col]])))
    if (!is.na(pais_col))     df$PaisOrigen  <- toupper(stringr::str_trim(as.character(df[[pais_col]])))
  }

  df <- df[!is.na(df$Fecha), ]
  df
}
