# functions/analysis.R
# Funciones de analisis reutilizadas del Proyecto 1

# Calculo de tendencias STL
calcular_tendencias <- function(data) {
  tendencias <- data.frame(Fecha = data$Fecha)
  for (col in names(data)[-1]) {
    tendencia <- tryCatch({
      serie <- ts(data[[col]], frequency = 12)
      stl_result <- stl(serie, s.window = "periodic")
      trend <- as.vector(stl_result$time.series[, "trend"])
      trend[trend < 0] <- 0
      trend
    }, error = function(e) {
      as.vector(data[[col]])
    })
    tendencias[[paste0(col, "_trend")]] <- tendencia
  }
  return(tendencias)
}

# Evaluacion de tendencia reciente
# Retorna lista con: descripcion (texto profesional), direccion ("alza"|"baja"|"estable"|"sin_datos"), n_meses
evaluar_tendencia <- function(tendencia, n = 3) {
  sin_datos <- list(
    descripcion = "no se dispone de suficientes datos para evaluar la tendencia reciente",
    direccion = "sin_datos",
    n_meses = n
  )
  if (is.null(tendencia) || length(tendencia) < n) return(sin_datos)
  ultimos_valores <- tail(tendencia, n)
  if (any(is.na(ultimos_valores)) || !is.numeric(ultimos_valores)) return(sin_datos)

  x <- seq_along(ultimos_valores)
  modelo <- tryCatch({ lm(ultimos_valores ~ x) }, error = function(e) NULL)
  if (is.null(modelo)) return(sin_datos)

  pendiente <- coef(modelo)[2]
  if (abs(pendiente) < 0.5) {
    list(
      descripcion = paste0("con base en los últimos ", n, " meses, el flujo se mantiene estable, sin variaciones significativas"),
      direccion = "estable",
      n_meses = n
    )
  } else if (pendiente > 0) {
    list(
      descripcion = paste0("con base en los últimos ", n, " meses, se observa una tendencia al alza"),
      direccion = "alza",
      n_meses = n
    )
  } else {
    list(
      descripcion = paste0("con base en los últimos ", n, " meses, se observa una tendencia a la baja"),
      direccion = "baja",
      n_meses = n
    )
  }
}

# Analisis de estacionalidad
analizar_estacionalidad <- function(data, variable) {
  ts_data <- ts(data[[variable]], frequency = 12)
  descomposicion <- stl(ts_data, s.window = "periodic")
  estacional <- descomposicion$time.series[, "seasonal"]
  n_complete_years <- floor(length(estacional) / 12)
  estacional_trim <- estacional[1:(n_complete_years * 12)]
  patron_estacional <- matrix(estacional_trim, ncol = 12, byrow = TRUE)
  promedio_estacional <- colMeans(patron_estacional)

  umbral <- mean(promedio_estacional)

  alta_temporada <- MESES_ES[promedio_estacional > umbral]
  baja_temporada <- MESES_ES[promedio_estacional <= umbral]

  indices <- data.frame(
    Mes = factor(MESES_ES, levels = MESES_ES),
    Indice = promedio_estacional,
    Temporada = ifelse(promedio_estacional > umbral, "Alta", "Baja")
  )

  encontrar_periodos <- function(meses_ordenados) {
    periodos <- list()
    periodo_actual <- c(meses_ordenados[1])
    for (i in 2:length(meses_ordenados)) {
      mes_actual_idx <- which(MESES_ES == meses_ordenados[i])
      mes_anterior_idx <- which(MESES_ES == meses_ordenados[i - 1])
      if (abs(mes_actual_idx - mes_anterior_idx) == 1 ||
          abs(mes_actual_idx - mes_anterior_idx) == 11) {
        periodo_actual <- c(periodo_actual, meses_ordenados[i])
      } else {
        periodos[[length(periodos) + 1]] <- periodo_actual
        periodo_actual <- c(meses_ordenados[i])
      }
    }
    periodos[[length(periodos) + 1]] <- periodo_actual
    return(periodos)
  }

  periodos_alta <- encontrar_periodos(alta_temporada)
  periodos_baja <- encontrar_periodos(baja_temporada)

  formatear_periodo <- function(periodo) {
    if (length(periodo) == 1) periodo else paste(periodo[1], "a", periodo[length(periodo)])
  }

  periodos_alta_fmt <- sapply(periodos_alta, formatear_periodo)
  periodos_baja_fmt <- sapply(periodos_baja, formatear_periodo)

  list(
    indices_estacionales = indices,
    periodos = list(alta = periodos_alta_fmt, baja = periodos_baja_fmt),
    resumen = list(
      alta = paste(periodos_alta_fmt, collapse = " y "),
      baja = paste(periodos_baja_fmt, collapse = " y ")
    )
  )
}
