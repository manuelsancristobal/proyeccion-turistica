# transform/config.R
# Carga configuracion desde config.yml

library(yaml)

load_config <- function() {
  root <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
  # Fallback: buscar config.yml subiendo desde el directorio actual
  cfg_path <- file.path(root, "config.yml")
  if (!file.exists(cfg_path)) {
    cfg_path <- file.path(getwd(), "config.yml")
  }
  if (!file.exists(cfg_path)) {
    # Intentar desde el directorio del script
    cfg_path <- file.path(dirname(sys.frame(1)$ofile %||% getwd()), "..", "config.yml")
    cfg_path <- normalizePath(cfg_path, mustWork = FALSE)
  }
  if (!file.exists(cfg_path)) {
    stop("No se encontro config.yml")
  }
  cfg <- yaml::read_yaml(cfg_path)

  base <- cfg$base_path
  cfg$raw_salidas <- file.path(base, cfg$paths$data_raw_salidas)
  cfg$raw_llegadas <- file.path(base, cfg$paths$data_raw_llegadas)
  cfg$raw_trafico <- file.path(base, cfg$paths$data_raw_trafico)
  cfg$transformed <- file.path(base, cfg$paths$data_transformed)
  cfg$transformed_salidas <- file.path(base, cfg$paths$data_transformed, "salidas")
  cfg$transformed_llegadas <- file.path(base, cfg$paths$data_transformed, "llegadas")
  cfg$transformed_trafico <- file.path(base, cfg$paths$data_transformed, "trafico_aereo")

  return(cfg)
}

# Operador %||% si no existe
`%||%` <- function(a, b) if (!is.null(a)) a else b
