# functions/llegadas_mappings.R
# Mapeo de grupos a elementos individuales para selectores en cascada

LLEGADAS_GRUPOS_NACIONALIDAD <- list(
  "AFRICA" = c(
    "ANGOLA", "ARGELIA", "CABO VERDE", "EGIPTO", "GHANA", "KENIA",
    "LIBIA", "MARRUECOS", "NIGERIA", "SOMALIA", "SUDAFRICA", "TUNEZ",
    "ZAIRE", "ZIMBABWE", "O. AFRICA"
  ),
  "AMERICA CENTRAL" = c(
    "BELICE", "COSTA RICA", "EL SALVADOR", "GUATEMALA",
    "HONDURAS", "NICARAGUA", "PANAMA"
  ),
  "AMERICA DEL NORTE" = c(
    "CANADA", "EEUU", "MEXICO", "O. AMERICA DEL NORTE"
  ),
  "AMERICA DEL SUR" = c(
    "ARGENTINA", "BOLIVIA", "BRASIL", "COLOMBIA", "ECUADOR",
    "GUYANA", "PARAGUAY", "PERU", "SURINAME", "URUGUAY",
    "VENEZUELA", "O. AMERICA DEL SUR"
  ),
  "CARIBE" = c(
    "BAHAMAS", "BARBADOS", "CUBA", "DOMINICA", "GRANADA", "HAITI",
    "JAMAICA", "PUERTO RICO", "REPUBLICA DOMINICANA", "SAN VICENTE",
    "SANTA LUCIA", "TRINIDAD Y TOBAGO", "O. CARIBE"
  ),
  "ASIA" = c(
    "AFGANISTAN", "BANGLADESH", "BHUTAN", "BRUNEI", "CAMBOYA", "CHINA",
    "COREA DEL NORTE", "COREA DEL SUR", "FILIPINAS", "INDIA", "INDONESIA",
    "JAPON", "KASAJSTAN", "KIRGUIZTAN", "LAOS", "MALASIA", "MALDIVAS",
    "MAYNMAR", "MONGOLIA", "NEPAL", "PAKISTAN", "SINGAPUR", "SRI LANKA",
    "TADJIKISTAN", "TAILANDIA", "TAIWAN", "TURKMENISTAN", "UZBEKISTAN",
    "VIETNAM", "O. ASIA"
  ),
  "EUROPA" = c(
    "ALBANIA", "ALEMANIA", "ANDORRA", "ARMENIA", "AUSTRIA", "AZERBAIJAN",
    "BELGICA", "BIELORRUSIA", "BOSNIA-HERZEGOVINA", "BULGARIA", "CHIPRE",
    "CIUDAD DEL VATICANO", "CROACIA", "DINAMARCA", "ESCOCIA", "ESLOVAQUIA",
    "ESLOVENIA", "ESPAÑA", "ESTONIA", "FEDERACION RUSA", "FINLANDIA",
    "FRANCIA", "GALES", "GEORGIA", "GRECIA", "HOLANDA", "HUNGRIA",
    "INGLATERRA", "IRLANDA", "ISLANDIA", "ITALIA", "LETONIA", "LIECHTENSTEIN",
    "LITUANIA", "LUXEMBURGO", "MACEDONIA", "MALTA", "MOLDAVIA", "MONACO",
    "NORUEGA", "POLONIA", "PORTUGAL", "RUMANIA", "SAN MARINO", "SERBIA",
    "SUECIA", "SUIZA", "TURQUIA", "UCRANIA", "O. EUROPA"
  ),
  "MEDIO ORIENTE" = c(
    "ARABIA SAUDITA", "BAHREIN", "EMIRATOS ARABES", "IRAK", "IRAN",
    "ISRAEL", "JORDANIA", "KUWAIT", "LIBANO", "OMAN", "QATAR",
    "SIRIA", "YEMEN", "O. MEDIO ORIENTE"
  ),
  "OCEANIA" = c(
    "AUSTRALIA", "NUEVA ZELANDIA", "SAMOA", "TUVALU", "O. OCEANIA"
  ),
  "OTROS" = c("O. MUNDO", "CHILE")
)

LLEGADAS_GRUPOS_PASO <- list(
  "01. XV - ARICA Y PARINACOTA" = c(
    "Chacalluta - Aeropuerto", "Concordia (Chacalluta)",
    "Chungar\u00e1", "FF.CC. Arica - Tacna", "Visviri"
  ),
  "02. I - TARAPAC\u00c1" = c(
    "Aeropuerto Diego Aracena", "Apacheta de Irpa", "Colchane"
  ),
  "03. II - ANTOFAGASTA" = c(
    "Aer\u00f3dromo El Loa", "Aeropuerto Cerro Moreno", "FF.CC Ollague",
    "Jama", "Salar de Ollag\u00fce", "Hito Caj\u00f3n", "Socompa", "Sico"
  ),
  "04. III - ATACAMA" = c(
    "Aer\u00f3dromo Chamonate", "Pascua Lama", "Pircas Negras", "San Francisco"
  ),
  "05. IV - COQUIMBO" = c(
    "Aeropuerto La Florida", "Juntas del Toro"
  ),
  "06. V - VALPARA\u00cdSO" = c(
    "Aer\u00f3dromo Torquemada - Vi\u00f1a del Mar", "Aeropuerto Isla de Pascua",
    "Sistema Cristo Redentor (Los Libertadores)"
  ),
  "07. VII - MAULE" = c(
    "Pehuenche", "Vergara"
  ),
  "08. VIII - B\u00cdO - B\u00cdO" = c(
    "Aeropuerto Carriel Sur", "Copahue", "Pichach\u00e9n"
  ),
  "09. IX - ARAUCAN\u00cdA" = c(
    "Aer\u00f3dromo Puc\u00f3n", "Aeropuerto Maquehue", "Icalma",
    "Pino Hachado", "Puesco (Mamuil Malal)"
  ),
  "10. XIV - LOS R\u00cdOS" = c(
    "Aeropuerto Pichoy", "Carirri\u00f1e", "Hua Hum"
  ),
  "11. X - LOS LAGOS" = c(
    "Aeropuerto El Tepual", "Cardenal Antonio Samor\u00e9", "Futaleuf\u00fa",
    "P\u00e9rez Rosales (Peulla)", "R\u00edo Encuentro", "R\u00edo Manso",
    "R\u00edo Puelo", "Vuriloche"
  ),
  "12. XI - AYSEN DEL GENERAL CARLOS IBA\u00d1EZ DEL CAMPO" = c(
    "Aeropuerto Balmaceda", "Coyhaique", "Hito O-IV-B", "Huemules",
    "Ingeniero Ib\u00e1\u00f1ez Palavicini", "Las Pampas - Lago Verde",
    "Pampa Alta", "R\u00edo Fr\u00eda Appeleg", "Rio Jeinimeni",
    "R\u00edo Mayer", "R\u00edo Mosco", "Roballos", "Triana"
  ),
  "13. XII - MAGALLANES Y LA ANTARTICA CHILENA" = c(
    "Aeropuerto Punta Arenas", "Dorotea",
    "Integraci\u00f3n Austral (Monte Aymond)", "Laurita Casas Viejas",
    "R\u00edo Bellavista", "R\u00edo Don Guillermo", "San Sebasti\u00e1n"
  ),
  "14. RM - METROPOLITANA DE SANTIAGO" = c(
    "Aeropuerto C. Arturo Merino Ben\u00edtez", "Portillo de Piuquenes"
  )
)

# Retorna el mapeo segun la vista activa
get_llegadas_mapping <- function(vista) {
  if (vista == "nacionalidad") {
    LLEGADAS_GRUPOS_NACIONALIDAD
  } else {
    LLEGADAS_GRUPOS_PASO
  }
}

# Filtra el mapeo a solo grupos/items que existan en los datos cargados
filtrar_mapping_a_datos <- function(mapping, col_names) {
  resultado <- lapply(mapping, function(items) {
    items[items %in% col_names]
  })
  # Eliminar grupos vacios
  resultado[lengths(resultado) > 0]
}
