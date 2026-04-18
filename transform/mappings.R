# transform/mappings.R
# Tablas de mapeo entre fuentes de datos de trafico aereo y llegadas

#' Mapeo de pais (ORIG_1_PAIS en trafico) -> nombre columna en llegadas_nacionalidad
#' Solo incluye paises que difieren entre fuentes
get_country_mapping <- function() {
  c(
    "ESTADOS UNIDOS"      = "EEUU",
    "REP. POPULAR CHINA"  = "CHINA",
    "REP.POPULAR CHINA"   = "CHINA",
    "REP. COREA DEL SUR"  = "COREA DEL SUR",
    "REP.COREA DEL SUR"   = "COREA DEL SUR",
    "REINO UNIDO"         = "INGLATERRA",
    "RUSIA"               = "FEDERACION RUSA",
    "EMI. ARABES UNIDOS"  = "EMIRATOS ARABES",
    "EMI.ARABES UNIDOS"   = "EMIRATOS ARABES",
    "SURINAM"             = "SURINAME",
    "REP. DOMINICANA"     = "REPUBLICA DOMINICANA"
  )
}

#' Paises a excluir (existen en trafico pero no en llegadas)
get_country_exclusions <- function() {
  c("CHECOESLOVAQUIA")
}

#' Mapeo de codigo IATA (DEST_1 en trafico) -> nombre en llegadas_paso
get_airport_mapping <- function() {
  c(
    "SCL" = "Aeropuerto C. Arturo Merino Ben\u00edtez",
    "ANF" = "Aeropuerto Cerro Moreno",
    "IQQ" = "Aeropuerto Diego Aracena",
    "ARI" = "Chacalluta - Aeropuerto",
    "PMC" = "Aeropuerto El Tepual",
    "PUQ" = "Aeropuerto Punta Arenas",
    "BBA" = "Aeropuerto Balmaceda",
    "CCP" = "Aeropuerto Carriel Sur",
    "LSC" = "Aeropuerto La Florida",
    "ZAL" = "Aeropuerto Pichoy",
    "ZCO" = "Aeropuerto Maquehue",
    "IPC" = "Aeropuerto Isla de Pascua"
  )
}
