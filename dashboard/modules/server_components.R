# modules/server_components.R
# Logica server para cada tab

# --- Tab Llegadas ---
llegadas_server <- function(input, output, session, data) {
  datos_llegadas <- reactive({
    req(data$nacionalidad, data$aeropuerto)
    if (input$vista_llegadas == "nacionalidad") {
      data$nacionalidad
    } else {
      data$aeropuerto
    }
  })

  output$subtitulo_llegadas <- renderUI({
    if (input$vista_llegadas == "nacionalidad") {
      h4("según nacionalidad")
    } else {
      h4("según paso/aeropuerto")
    }
  })

  # Selector de grupo (continente / region)
  output$selector_grupo_llegadas <- renderUI({
    df <- datos_llegadas()
    mapping <- get_llegadas_mapping(input$vista_llegadas)
    mapping_filtered <- filtrar_mapping_a_datos(mapping, names(df))
    group_choices <- c("Total", names(mapping_filtered))
    req(length(group_choices) > 0)
    placeholder_grupo <- if (input$vista_llegadas == "nacionalidad") "Seleccione un continente" else "Seleccione una región"
    selectizeInput("grupo_llegadas",
                   label = if (input$vista_llegadas == "nacionalidad") "Continente" else "Región",
                   choices = group_choices, selected = "Total", multiple = FALSE,
                   options = list(placeholder = placeholder_grupo))
  })

  # Selector de items individuales (paises / pasos) - cascada del grupo
  output$selector_item_llegadas <- renderUI({
    req(input$grupo_llegadas)
    req(input$grupo_llegadas != "Total")
    df <- datos_llegadas()
    mapping <- get_llegadas_mapping(input$vista_llegadas)
    mapping_filtered <- filtrar_mapping_a_datos(mapping, names(df))
    items <- mapping_filtered[[input$grupo_llegadas]]
    req(length(items) > 0)
    placeholder_item <- if (input$vista_llegadas == "nacionalidad") "Seleccione uno o más países" else "Seleccione uno o más pasos/aeropuertos"
    selectizeInput("items_llegadas",
                   label = if (input$vista_llegadas == "nacionalidad") "País" else "Paso / Aeropuerto",
                   choices = items, selected = NULL, multiple = TRUE,
                   options = list(placeholder = placeholder_item))
  })

  # Determina las variables activas segun el modo (grupo total vs individual)
  vars_llegadas_validas <- reactive({
    df <- datos_llegadas()
    req(input$grupo_llegadas)
    if (isTRUE(input$mostrar_total_grupo) || identical(input$grupo_llegadas, "Total")) {
      # Para "Total" usar columna TOTAL; para grupo normal usar la columna del grupo
      col <- if (identical(input$grupo_llegadas, "Total")) "TOTAL" else input$grupo_llegadas
      req(col %in% names(df))
      col
    } else {
      req(input$items_llegadas)
      vars <- input$items_llegadas[input$items_llegadas %in% names(df)]
      req(length(vars) > 0)
      vars
    }
  })

  # Grafico de series
  output$plot_llegadas <- renderPlotly({
    vars <- vars_llegadas_validas()
    df <- datos_llegadas()
    colors <- setNames(PALETA_SERIES[seq_along(vars)], vars)

    p <- plot_ly()

    for (i in seq_along(vars)) {
      v <- vars[i]
      df_v <- df %>% select(Fecha, val = all_of(v)) %>% filter(!is.na(val))
      
      name_real <- if (length(vars) == 1) "Llegadas" else v
      p <- p %>% add_lines(
        data = df_v, x = ~Fecha, y = ~val, name = name_real,
        legendgroup = if (length(vars) > 1) v else NULL,
        line = list(color = colors[[v]], width = GROSOR_PRIMARIO * 2),
        hovertext = ~fmt_hover(Fecha, name_real, val),
        hoverinfo = "text"
      )

      # Tendencia STL
      if (isTRUE(input$mostrar_tendencia_ll)) {
        trend_col <- paste0(v, "_trend")
        if (trend_col %in% names(df)) {
          df_t <- df %>% select(Fecha, val = all_of(trend_col)) %>% filter(!is.na(val))
          if (nrow(df_t) > 0) {
            name_trend <- if (length(vars) == 1) "Tendencia" else paste0(v, " (tendencia)")
            p <- p %>% add_lines(
              data = df_t, x = ~Fecha, y = ~val, name = name_trend,
              legendgroup = if (length(vars) > 1) v else NULL, 
              showlegend = TRUE,
              line = list(color = colors[[v]], width = GROSOR_SECUNDARIO * 2, dash = "dashdot"),
              hovertext = ~fmt_hover(Fecha, name_trend, val),
              hoverinfo = "text"
            )
          }
        }
      }
    }

    # Overlay forecast ARIMA/SARIMAX si el checkbox esta activo
    if (isTRUE(input$mostrar_proyeccion_ll)) {
      fc_df <- if (input$vista_llegadas == "nacionalidad") {
        data$llegadas_forecast_nacionalidad
      } else {
        data$llegadas_forecast_paso
      }
      if (!is.null(fc_df) && nrow(fc_df) > 0) {
        fc_filtered <- fc_df %>% dplyr::filter(Variable %in% vars)
        if (nrow(fc_filtered) > 0) {
          # Construir fila puente (ultimo punto real -> inicio del forecast)
          last_real_per_var <- df %>%
            select(Fecha, all_of(vars)) %>%
            pivot_longer(-Fecha, names_to = "Variable", values_to = "val") %>%
            filter(!is.na(val)) %>%
            group_by(Variable) %>%
            slice_max(Fecha, n = 1, with_ties = FALSE) %>%
            transmute(Fecha, Variable,
                      arima_Pronostico = val, arima_li = NA_real_, arima_ls = NA_real_,
                      sarimax_Pronostico = val, sarimax_li = NA_real_, sarimax_ls = NA_real_)
          fc_filtered <- bind_rows(last_real_per_var, fc_filtered) %>%
            arrange(Variable, Fecha)

          # Iterar por variable para forecast
          for (v in unique(fc_filtered$Variable)) {
            fc_v <- fc_filtered %>% dplyr::filter(Variable == v)
            col_v <- if (v %in% names(colors)) colors[[v]] else PALETA_SERIES[1]
            
            # Nombre base para el forecast
            name_base <- if (length(vars) == 1) "" else paste0(" (", v, ")")

            # ARIMA ribbon + line
            if (any(!is.na(fc_v$arima_Pronostico))) {
              if ("arima_li" %in% names(fc_v) && "arima_ls" %in% names(fc_v)) {
                p <- p %>% add_ribbons(
                  data = fc_v, x = ~Fecha, ymin = ~arima_li, ymax = ~arima_ls,
                  name = paste0("IC ARIMA", name_base), 
                  legendgroup = if (length(vars) > 1) v else "ARIMA",
                  line = list(color = "transparent"),
                  fillcolor = "rgba(142,107,191,0.12)", showlegend = FALSE
                )
              }
              p <- p %>% add_lines(
                data = fc_v, x = ~Fecha, y = ~arima_Pronostico, name = paste0("ARIMA", name_base),
                legendgroup = if (length(vars) > 1) v else "ARIMA",
                line = list(color = COLOR_ARIMA, width = GROSOR_SECUNDARIO * 2, dash = "dot"),
                hovertext = ~fmt_num(arima_Pronostico),
                hoverinfo = "text"
              )
            }

            # SARIMAX ribbon + line
            if (any(!is.na(fc_v$sarimax_Pronostico))) {
              if ("sarimax_li" %in% names(fc_v) && "sarimax_ls" %in% names(fc_v)) {
                p <- p %>% add_ribbons(
                  data = fc_v, x = ~Fecha, ymin = ~sarimax_li, ymax = ~sarimax_ls,
                  name = paste0("IC SARIMAX", name_base), 
                  legendgroup = if (length(vars) > 1) v else "SARIMAX",
                  line = list(color = "transparent"),
                  fillcolor = "rgba(196,78,82,0.10)", showlegend = FALSE
                )
              }
              p <- p %>% add_lines(
                data = fc_v, x = ~Fecha, y = ~sarimax_Pronostico, name = paste0("SARIMAX", name_base),
                legendgroup = if (length(vars) > 1) v else "SARIMAX",
                line = list(color = COLOR_SARIMAX, width = GROSOR_SECUNDARIO * 2, dash = "dash"),
                hovertext = ~fmt_num(sarimax_Pronostico),
                hoverinfo = "text"
              )
            }
          }
        }
      }
    }

    p %>% layout_dashboard(
      yaxis = list(title = "Cantidad de turistas", tickformat = ",.0f")
    )
  })

  # Panel informativo
  output$info_panel_llegadas <- renderUI({
    vars <- vars_llegadas_validas()
    info_texts <- lapply(vars, function(var) {
      df <- datos_llegadas()
      datos_var <- df %>% select(Fecha, all_of(var))
      max_row <- datos_var %>% filter(get(var) == max(get(var), na.rm = TRUE)) %>% slice(1)
      fecha_max <- fmt_fecha_es(max_row$Fecha, "%B de %Y")
      cantidad_max <- format(max_row[[var]], big.mark = ".", decimal.mark = ",")

      tendencia_col <- paste0(var, "_trend")
      tendencia <- if (tendencia_col %in% names(df)) df[[tendencia_col]] else NULL
      resultado_tendencia <- evaluar_tendencia(tendencia)

      analisis <- tryCatch(analizar_estacionalidad(df, var), error = function(e) NULL)

      # Load factor promedio ultimos 12 meses (aislado para no bloquear el resto del analisis)
      lf_text <- local({
        tryCatch({
          lf_df <- if (input$vista_llegadas == "nacionalidad") data$load_factor_pais else data$load_factor_aeropuerto
          if (is.null(lf_df) || nrow(lf_df) == 0) return(NULL)
          lf_col <- if (input$vista_llegadas == "nacionalidad") "Pais" else "Aeropuerto"
          if (!lf_col %in% names(lf_df) || !"LoadFactor" %in% names(lf_df)) return(NULL)
          lf_var <- lf_df %>% dplyr::filter(.data[[lf_col]] == var, !is.na(LoadFactor))
          if (nrow(lf_var) == 0) return(NULL)
          ultimos_12 <- tail(lf_var %>% dplyr::arrange(Fecha), 12)
          prom <- round(mean(ultimos_12$LoadFactor, na.rm = TRUE), 1)

          conclusion <- if (prom >= 85) {
            paste0("Durante los últimos 12 meses, los vuelos registran una ocupación estimada promedio del ",
                   prom, "%, lo que representa un nivel elevado que podría limitar la capacidad de crecimiento en llegadas aéreas.")
          } else if (prom >= 70) {
            paste0("Durante los últimos 12 meses, la ocupación estimada promedio es del ",
                   prom, "%, un nivel saludable que indica margen disponible para absorber mayor demanda de pasajeros.")
          } else {
            paste0("Durante los últimos 12 meses, la ocupación estimada promedio es del ",
                   prom, "%, lo que sugiere capacidad disponible en los vuelos para incrementar el flujo de turistas.")
          }

          alza_y_alta_ocupacion <- prom >= 85 && resultado_tendencia$direccion == "alza"
          extra <- if (alza_y_alta_ocupacion) {
            " Considerando que la tendencia de llegadas es al alza y la ocupación se encuentra en niveles altos, esto sugiere la necesidad de ampliar la oferta aérea."
          } else {
            ""
          }

          tags$p(tags$strong("Ocupación aérea: "), conclusion, extra)
        }, error = function(e) NULL)
      })

      # Conectividad aérea:solo para items individuales (no aplica a totales de grupo)
      es_total_grupo <- isTRUE(input$mostrar_total_grupo) || identical(input$grupo_llegadas, "Total")
      connectivity_text <- if (es_total_grupo) NULL else local({
        tryCatch({
          if (input$vista_llegadas == "nacionalidad") {
            # --- Conectividad por pais ---
            conect_df <- data$conectividad_pais
            if (is.null(conect_df) || nrow(conect_df) == 0) return(NULL)
            row <- conect_df %>% dplyr::filter(Pais == var)
            if (nrow(row) == 0) {
              return(tags$p(tags$strong("Conectividad aérea: "),
                            "No se registran vuelos directos desde ", var,
                            " hacia Chile en los datos de tráfico aéreo disponibles."))
            }
            row <- row[1, ]
            desde <- fmt_fecha_es(row$FechaInicio)
            hasta <- fmt_fecha_es(row$FechaFin)

            if (row$Activo) {
              rutas_txt <- if (row$NRutasActivas == 1) "1 ruta activa" else paste0(row$NRutasActivas, " rutas activas")
              txt <- paste0(var, " cuenta con vuelos directos hacia Chile desde ", desde,
                            ". Actualmente opera(n) ", rutas_txt,
                            " (", row$MesesTotales, " meses con operación registrada).")
            } else {
              txt <- paste0(var, " registró vuelos directos hacia Chile entre ", desde,
                            " y ", hasta, " (", row$MesesTotales,
                            " meses con operación). No se registran vuelos directos en los últimos 12 meses.")
            }
            tags$p(tags$strong("Conectividad aérea: "), txt)

          } else {
            # --- Analisis de aeropuerto ---
            aero_df <- data$analisis_aeropuerto
            if (is.null(aero_df) || nrow(aero_df) == 0) return(NULL)
            row <- aero_df %>% dplyr::filter(Aeropuerto == var)
            if (nrow(row) == 0) return(NULL)
            row <- row[1, ]

            partes <- list()
            if (!is.na(row$NPaisesOrigen)) {
              partes <- c(partes, paste0("recibe vuelos desde ", row$NPaisesOrigen, " países de origen"))
            }
            if (!is.na(row$ConcentracionTop3Pct) && !is.na(row$Top3Paises)) {
              partes <- c(partes, paste0("con una concentración del ", row$ConcentracionTop3Pct,
                                         "% del tráfico en los tres principales mercados (",
                                         row$Top3Paises, ")"))
            }
            if (!is.na(row$NOperadores)) {
              partes <- c(partes, paste0("operan ", row$NOperadores, " aerolíneas"))
            }
            if (!is.na(row$PatronEstacional)) {
              partes <- c(partes, paste0("patrón de operación: ", tolower(row$PatronEstacional)))
            }
            if (length(partes) == 0) return(NULL)
            txt <- paste0(var, " ", paste(partes, collapse = ", "), ".")
            tags$p(tags$strong("Conectividad aérea: "), txt)
          }
        }, error = function(e) NULL)
      })

      tags$div(
        class = "analisis-item",
        tags$h5(var),
        # 1. Tendencia reciente (lo más importante: dirección actual)
        tags$p(tags$strong("Tendencia reciente: "),
               resultado_tendencia$descripcion, "."),
        # 2. Estacionalidad (complementa tendencia: patrones temporales)
        if (!is.null(analisis)) {
          tags$p(tags$strong("Estacionalidad: "),
                 "los meses de mayor afluencia turística corresponden a ",
                 tags$strong(analisis$resumen$alta), ".")
        },
        # 3. Ocupación aérea (lado oferta: capacidad)
        lf_text,
        # 4. Conectividad aérea (complementa ocupación: oferta de rutas)
        connectivity_text,
        # 5. Mayor registro (referencia histórica)
        tags$p(tags$strong("Mayor registro de llegadas: "),
               "La mayor cantidad de pasajeros recibidos se registró en ",
               tags$strong(fecha_max), ", con un total de ",
               tags$strong(cantidad_max), " llegadas.")
      )
    })
    tags$div(class = "analisis-grid", do.call(tagList, info_texts))
  })

  # Analisis estacional
  output$estacional_llegadas <- renderUI({
    vars <- vars_llegadas_validas()
    info_texts <- lapply(vars, function(var) {
      analisis <- tryCatch(analizar_estacionalidad(datos_llegadas(), var), error = function(e) NULL)
      if (is.null(analisis)) return(NULL)
      tagList(
        div(style = "margin-bottom: 20px; padding: 10px; border: 1px solid #ddd; border-radius: 5px;",
            h4(var), h5("Índice estacional por mes:"),
            tableOutput(NS(var, "tabla_est_ll")))
      )
    })
    do.call(tagList, info_texts)
  })

  observe({
    vars <- vars_llegadas_validas()
    for (var in vars) {
      local({
        local_var <- var
        output[[NS(local_var, "tabla_est_ll")]] <- renderTable({
          analisis <- tryCatch(analizar_estacionalidad(datos_llegadas(), local_var),
                               error = function(e) NULL)
          if (!is.null(analisis)) analisis$indices_estacionales
        })
      })
    }
  })

  # --- Load Factor ---
  datos_load_factor <- reactive({
    vars <- vars_llegadas_validas()
    if (input$vista_llegadas == "nacionalidad") {
      req(data$load_factor_pais)
      df <- data$load_factor_pais
      df_filtered <- df %>% dplyr::filter(Pais %in% vars)
      list(data = df_filtered, group_col = "Pais")
    } else {
      req(data$load_factor_aeropuerto)
      df <- data$load_factor_aeropuerto
      df_filtered <- df %>% dplyr::filter(Aeropuerto %in% vars)
      list(data = df_filtered, group_col = "Aeropuerto")
    }
  })

  output$plot_load_factor <- renderPlotly({
    lf <- tryCatch(datos_load_factor(), error = function(e) NULL)

    if (is.null(lf) || nrow(lf$data) == 0 || all(is.na(lf$data$LoadFactor))) {
      return(empty_plotly("Sin datos de Load Factor para la selección actual"))
    }

    df_plot <- lf$data %>% dplyr::filter(!is.na(LoadFactor))
    group_col <- lf$group_col
    groups <- unique(df_plot[[group_col]])
    colors <- setNames(PALETA_SERIES[seq_along(groups)], groups)

    p <- plot_ly()
    for (grp in groups) {
      df_grp <- df_plot[df_plot[[group_col]] == grp, ]
      p <- p %>% add_lines(
        data = df_grp, x = ~Fecha, y = ~LoadFactor, name = grp,
        line = list(color = colors[[grp]], width = GROSOR_PRIMARIO * 2),
        hovertext = ~paste0(fmt_fecha_es(Fecha), "<br>", grp,
                            "<br>Load Factor: ", round(LoadFactor, 1), "%"),
        hoverinfo = "text"
      )
    }

    p %>% layout_dashboard(
      yaxis = list(title = "Load Factor (%)", ticksuffix = "%"),
      shapes = list(list(
        type = "line", x0 = 0, x1 = 1, xref = "paper",
        y0 = 80, y1 = 80, yref = "y",
        line = list(color = "grey40", width = 1, dash = "dot")
      ))
    )
  })
}

# --- Tab Salidas ---
salidas_server <- function(input, output, session, data) {
  datos_salidas_filtrado <- reactive({
    req(data$salidas)
    codigo_max <- max(data$salidas$Codigo)
    data$salidas %>% filter(Codigo == codigo_max)
  })

  # Panel informativo
  output$info_panel_salidas <- renderUI({
    df <- datos_salidas_filtrado()
    req(nrow(df) > 0, "Cantidad" %in% names(df))

    max_row <- df %>% filter(Cantidad == max(Cantidad, na.rm = TRUE)) %>% slice(1)
    fecha_max <- fmt_fecha_es(max_row$Fecha, "%B de %Y")
    cantidad_max <- format(round(max_row$Cantidad), big.mark = ".", decimal.mark = ",")

    tendencia <- if ("Tendencia" %in% names(df)) df$Tendencia[!is.na(df$Tendencia)] else NULL
    resultado_tendencia <- evaluar_tendencia(tendencia)

    # Analisis de frecuencia de vuelos (extraer datos para usar en la UI)
    freq_data <- local({
      tryCatch({
        df_freq <- data$frecuencia_salidas
        if (is.null(df_freq) || nrow(df_freq) == 0) return(NULL)

        # Mayor registro de operaciones
        max_ops_row <- df_freq %>% filter(Operaciones == max(Operaciones, na.rm = TRUE)) %>% slice(1)
        fecha_max_ops <- fmt_fecha_es(max_ops_row$Fecha, "%B de %Y")
        ops_max <- format(round(max_ops_row$Operaciones), big.mark = ".", decimal.mark = ",")

        # Pasajeros promedio por vuelo (ultimos 12 meses)
        ultimos_12 <- tail(df_freq %>% filter(!is.na(Pasajeros), !is.na(Operaciones)), 12)
        pax_por_vuelo <- round(sum(ultimos_12$Pasajeros, na.rm = TRUE) / sum(ultimos_12$Operaciones, na.rm = TRUE))

        # Variación interanual de operaciones
        n <- nrow(df_freq)
        var_text <- NULL
        if (n >= 24) {
          reciente <- tail(df_freq, 12)
          previo <- df_freq[(n - 23):(n - 12), ]
          ops_reciente <- sum(reciente$Operaciones, na.rm = TRUE)
          ops_previo <- sum(previo$Operaciones, na.rm = TRUE)
          if (ops_previo > 0) {
            variacion <- round(((ops_reciente - ops_previo) / ops_previo) * 100, 1)
            signo <- if (variacion >= 0) "+" else ""
            direccion <- if (variacion >= 0) "un incremento" else "una disminución"
            var_text <- tags$p(tags$strong("Variación interanual: "),
                               "en los últimos 12 meses se registra ", direccion,
                               " del ", tags$strong(paste0(signo, format(variacion, decimal.mark = ","), "%")),
                               " en operaciones respecto al período anterior.")
          }
        }

        list(fecha_max_ops = fecha_max_ops, ops_max = ops_max,
             pax_por_vuelo = pax_por_vuelo, var_text = var_text)
      }, error = function(e) NULL)
    })

    tags$div(
      class = "analisis-grid",
      tags$div(
        class = "analisis-item",
        tags$h5("Salidas de Residentes"),
        # 1. Tendencia reciente (lo más importante: dirección actual)
        tags$p(tags$strong("Tendencia reciente: "),
               resultado_tendencia$descripcion, "."),
        # 2. Variación interanual (cuantifica el cambio - complementa tendencia)
        if (!is.null(freq_data)) freq_data$var_text,
        # 3. Mayor registro de salidas (referencia histórica)
        tags$p(tags$strong("Mayor registro de salidas: "),
               "La mayor cantidad de salidas se registró en ",
               tags$strong(fecha_max), ", con un total de ",
               tags$strong(cantidad_max), " salidas.")
      ),
      if (!is.null(freq_data)) {
        tags$div(
          class = "analisis-item",
          tags$h5("Operaciones Aéreas"),
          # 4. Mayor registro de operaciones (referencia histórica vuelos - relacionado)
          tags$p(tags$strong("Mayor registro de operaciones: "),
                 "el mes con mayor cantidad de vuelos internacionales salientes fue ",
                 tags$strong(freq_data$fecha_max_ops), ", con ",
                 tags$strong(freq_data$ops_max), " operaciones."),
          # 5. Pasajeros por vuelo (detalle operativo)
          tags$p(tags$strong("Pasajeros por vuelo: "),
                 "en los últimos 12 meses, el promedio es de ",
                 tags$strong(fmt_num(freq_data$pax_por_vuelo)),
                 " pasajeros por operación.")
        )
      }
    )
  })

  # Grafico principal de series (con toggles de tendencia y proyeccion)
  output$plot_salidas <- renderPlotly({
    df <- datos_salidas_filtrado()
    req(nrow(df) > 0)

    df_real <- df %>% filter(!is.na(Cantidad))

    p <- plot_ly() %>%
      add_lines(data = df_real, x = ~Fecha, y = ~Cantidad, name = "Salidas",
                line = list(color = COLOR_REAL, width = GROSOR_PRIMARIO * 2),
                hovertext = ~fmt_hover(Fecha, "Salidas", Cantidad),
                hoverinfo = "text")

    if (isTRUE(input$mostrar_tendencia_sal) && "Tendencia" %in% names(df_real)) {
      df_tend <- df_real %>% filter(!is.na(Tendencia))
      p <- p %>% add_lines(data = df_tend, x = ~Fecha, y = ~Tendencia, name = "Tendencia",
                            line = list(color = COLOR_TENDENCIA, width = GROSOR_SECUNDARIO * 2, dash = "dashdot"),
                            hovertext = ~fmt_hover(Fecha, "Tendencia", Tendencia),
                            hoverinfo = "text")
    }

    if (isTRUE(input$mostrar_proyeccion_sal)) {
      df_fc <- df %>% filter(is.na(Cantidad))
      if (nrow(df_fc) > 0) {
        last_row <- df_real %>% slice_max(Fecha, n = 1)
        if (nrow(last_row) > 0) {
          bridge <- last_row %>%
            mutate(arima_Pronostico = Cantidad, arima_li = NA_real_, arima_ls = NA_real_,
                   sarimax_Pronostico = Cantidad, sarimax_li = NA_real_, sarimax_ls = NA_real_)
          df_fc <- bind_rows(bridge, df_fc) %>% arrange(Fecha)
        }

        if ("arima_Pronostico" %in% names(df_fc)) {
          if ("arima_li" %in% names(df_fc) && "arima_ls" %in% names(df_fc)) {
            p <- p %>% add_ribbons(data = df_fc, x = ~Fecha, ymin = ~arima_li, ymax = ~arima_ls,
                                   name = "IC ARIMA", line = list(color = "transparent"),
                                   fillcolor = "rgba(142,107,191,0.12)", showlegend = FALSE)
          }
          p <- p %>% add_lines(data = df_fc, x = ~Fecha, y = ~arima_Pronostico, name = "ARIMA",
                               line = list(color = COLOR_ARIMA, width = GROSOR_SECUNDARIO * 2, dash = "dot"),
                               hovertext = ~fmt_num(arima_Pronostico),
                               hoverinfo = "text")
        }
        if ("sarimax_Pronostico" %in% names(df_fc)) {
          if ("sarimax_li" %in% names(df_fc) && "sarimax_ls" %in% names(df_fc)) {
            p <- p %>% add_ribbons(data = df_fc, x = ~Fecha, ymin = ~sarimax_li, ymax = ~sarimax_ls,
                                   name = "IC SARIMAX", line = list(color = "transparent"),
                                   fillcolor = "rgba(196,78,82,0.10)", showlegend = FALSE)
          }
          p <- p %>% add_lines(data = df_fc, x = ~Fecha, y = ~sarimax_Pronostico, name = "SARIMAX",
                               line = list(color = COLOR_SARIMAX, width = GROSOR_SECUNDARIO * 2, dash = "dash"),
                               hovertext = ~fmt_num(sarimax_Pronostico),
                               hoverinfo = "text")
        }
      }
    }

    p %>%
      layout(
        xaxis = list(title = "Fecha"),
        yaxis = list(title = "Salidas", tickformat = ","),
        hovermode = "x unified",
        legend = list(orientation = "h", x = 0.5, xanchor = "center", y = 1.08)
      ) %>%
      config(displayModeBar = FALSE)
  })

  # Frecuencia de vuelos internacionales salientes (solo operaciones)
  output$plot_salidas_frecuencia <- renderPlotly({
    req(data$frecuencia_salidas)
    df <- data$frecuencia_salidas

    plot_ly(df, x = ~Fecha) %>%
      add_lines(y = ~Operaciones, name = "Operaciones",
                line = list(color = COLOR_REAL, width = 2),
                hovertext = ~paste0(fmt_fecha_es(Fecha), "<br>Operaciones: ", fmt_num(Operaciones)),
                hoverinfo = "text") %>%
      layout(
        yaxis = list(title = "Operaciones", tickformat = ","),
        hovermode = "x unified",
        legend = list(orientation = "h", x = 0.5, xanchor = "center", y = 1.08)
      ) %>%
      config(displayModeBar = FALSE)
  })
}

# --- Tab Analitica de Mercados ---
analitica_server <- function(input, output, session, data) {

  # Columnas a excluir del analisis de paises
  cols_excluir <- c("Fecha", "TOTAL",
                    # Grupos continentales de 1er nivel (ya son agregados)
                    "AFRICA", "AMERICA CENTRAL", "AMERICA DEL NORTE", "AMERICA DEL SUR",
                    "CARIBE", "ASIA", "EUROPA", "MEDIO ORIENTE", "OCEANIA", "OTROS",
                    # Sub-totales residuales y especiales
                    "O. AFRICA", "O. AMERICA DEL NORTE", "O. AMERICA DEL SUR",
                    "O. CARIBE", "O. ASIA", "O. EUROPA", "O. MEDIO ORIENTE",
                    "O. OCEANIA", "O. MUNDO", "CHILE")

  # Obtener nombres de paises validos (sin _trend, sin columnas excluidas)
  paises_validos <- reactive({
    req(data$nacionalidad)
    cols <- names(data$nacionalidad)
    cols <- cols[!grepl("_trend$", cols)]
    cols <- setdiff(cols, cols_excluir)
    cols
  })

  # Reactive: datos filtrados por periodo
  datos_periodo <- reactive({
    req(data$nacionalidad, input$periodo_analitica)
    df <- data$nacionalidad
    n_meses <- as.integer(input$periodo_analitica)
    fecha_max <- max(df$Fecha, na.rm = TRUE)
    fecha_corte <- fecha_max %m-% months(n_meses)
    df_filtrado <- df %>% dplyr::filter(Fecha > fecha_corte)
    df_filtrado
  })

  # --- KPI: Total llegadas ---
  output$kpi_total <- renderUI({
    df <- datos_periodo()
    paises <- paises_validos()
    total <- sum(rowSums(df[, paises, drop = FALSE], na.rm = TRUE), na.rm = TRUE)
    tags$div(
      class = "kpi-card-new",
      tags$div(class = "label", "Total Llegadas"),
      tags$div(class = "value", format(round(total), big.mark = ".", decimal.mark = ",")),
      tags$div(class = "subtext", paste0("Flujo acumulado últimos ", input$periodo_analitica, " meses"))
    )
  })

  # --- KPI: HHI concentracion ---
  output$kpi_hhi_card <- renderUI({
    df <- datos_periodo()
    paises <- paises_validos()
    totales_pais <- colSums(df[, paises, drop = FALSE], na.rm = TRUE)
    total_general <- sum(totales_pais)
    if (total_general == 0) {
      return(tags$div(class = "kpi-card-new", tags$div(class = "label", "Concentración HHI"), tags$div(class = "value", "N/A")))
    }
    shares <- (totales_pais / total_general) * 100
    hhi <- sum(shares^2)
    nivel <- if (hhi < 1500) "Baja (Saludable)" else if (hhi <= 2500) "Moderada" else "Alta (Riesgo)"
    tags$div(
      class = "kpi-card-new",
      tags$div(class = "label", "Concentración HHI"),
      tags$div(class = "value", format(round(hhi), big.mark = ".", decimal.mark = ",")),
      tags$div(class = "subtext", paste0("Estado: ", nivel))
    )
  })

  # --- KPI: Mercados activos ---
  output$kpi_mercados <- renderUI({
    df <- datos_periodo()
    paises <- paises_validos()
    totales_pais <- colSums(df[, paises, drop = FALSE], na.rm = TRUE)
    n_activos <- sum(totales_pais > 0)
    tags$div(
      class = "kpi-card-new",
      tags$div(class = "label", "Mercados Activos"),
      tags$div(class = "value", n_activos),
      tags$div(class = "subtext", "Países con flujo registrado")
    )
  })

  # --- Ranking Dinámico (Top 10 vs Emergentes) ---
  output$plot_ranking_dinamico <- renderPlotly({
    req(input$tipo_analisis_maestro)
    df <- datos_periodo()
    paises <- paises_validos()
    
    if (input$tipo_analisis_maestro == "top") {
      totales_pais <- sort(colSums(df[, paises, drop = FALSE], na.rm = TRUE), decreasing = TRUE)
      top10 <- head(totales_pais, 10)
      df_plot <- data.frame(Pais = names(top10), Val = as.numeric(top10), stringsAsFactors = FALSE)
      title_x <- "Total Llegadas"
      hover_suffix <- " llegadas"
    } else {
      # Logica de emergentes
      n_meses <- as.integer(input$periodo_analitica)
      df_completo <- data$nacionalidad
      fecha_max <- max(df_completo$Fecha, na.rm = TRUE)
      fecha_corte_actual <- fecha_max %m-% months(n_meses)
      fecha_corte_previo <- fecha_corte_actual %m-% months(n_meses)
      
      df_actual <- df_completo %>% dplyr::filter(Fecha > fecha_corte_actual)
      df_previo <- df_completo %>% dplyr::filter(Fecha > fecha_corte_previo & Fecha <= fecha_corte_actual)
      
      suma_actual <- colSums(df_actual[, paises, drop = FALSE], na.rm = TRUE)
      suma_previo <- colSums(df_previo[, paises, drop = FALSE], na.rm = TRUE)
      
      validos <- names(suma_actual)[suma_actual > 100 & suma_previo > 0]
      variacion <- ((suma_actual[validos] - suma_previo[validos]) / suma_previo[validos]) * 100
      # Filtrar solo crecimientos positivos para el analisis de "Emergentes"
      variacion <- variacion[variacion > 0]
      top10_emerge <- head(sort(variacion, decreasing = TRUE), 10)
      
      df_plot <- data.frame(Pais = names(top10_emerge), Val = as.numeric(top10_emerge), stringsAsFactors = FALSE)
      title_x <- "Crecimiento (%)"
      hover_suffix <- "%"
    }
    
    if (nrow(df_plot) == 0) return(empty_plotly("No hay datos para mostrar"))
    df_plot$Continente <- get_continente(df_plot$Pais)
    
    plot_ly() %>%
      add_bars(data = df_plot, x = ~Val, y = ~Pais, orientation = "h",
               marker = list(color = COLORES_CONTINENTE[df_plot$Continente]),
               hovertext = ~paste0("<b>", Pais, "</b><br>", fmt_num(Val), hover_suffix),
               hoverinfo = "text", showlegend = FALSE) %>%
      layout_dashboard(
        xaxis = list(title = title_x, 
                     range = c(0, max(df_plot$Val) * 1.1), # Comienza en 0
                     tickformat = if(input$tipo_analisis_maestro == "top") ",.0f" else ".1f"),
        yaxis = list(title = NULL, categoryorder = "array", categoryarray = rev(df_plot$Pais)),
        margin = list(l = 100)
      )
  })

  # --- HHI evolucion temporal ---
  output$plot_hhi <- renderPlotly({
    req(data$nacionalidad, input$periodo_analitica)
    df <- data$nacionalidad
    paises <- paises_validos()
    fecha_max <- max(df$Fecha, na.rm = TRUE)
    n_meses_hhi <- as.integer(input$periodo_analitica)
    fecha_corte_hhi <- fecha_max %m-% months(n_meses_hhi)
    df_periodo_hhi <- df %>% dplyr::filter(Fecha > fecha_corte_hhi)

    hhi_mensual <- df_periodo_hhi %>%
      dplyr::rowwise() %>%
      dplyr::mutate(total_mes = sum(dplyr::c_across(dplyr::all_of(paises)), na.rm = TRUE)) %>%
      dplyr::ungroup()

    hhi_vals <- sapply(seq_len(nrow(hhi_mensual)), function(i) {
      total <- hhi_mensual$total_mes[i]
      if (is.na(total) || total == 0) return(NA_real_)
      vals <- as.numeric(hhi_mensual[i, paises])
      shares <- (vals / total) * 100
      sum(shares^2, na.rm = TRUE)
    })

    df_hhi <- data.frame(Fecha = hhi_mensual$Fecha, HHI = hhi_vals) %>% filter(!is.na(HHI))
    
    # Generar etiquetas de meses en español para el eje X
    # Esto asegura el idioma sin depender de la configuracion del servidor/navegador
    fechas_eje <- df_hhi$Fecha
    etiquetas_es <- sapply(fechas_eje, function(f) fmt_fecha_es(f, "%b\n%Y"))

    plot_ly() %>%
      add_lines(data = df_hhi, x = ~Fecha, y = ~HHI, name = "HHI",
                line = list(color = COLOR_HHI, width = 3),
                hovertext = ~paste0("<b>", fmt_fecha_es(Fecha), "</b><br>HHI: ", fmt_num(HHI)),
                hoverinfo = "text", showlegend = FALSE) %>%
      layout_dashboard(
        xaxis = list(
          title = NULL,
          tickvals = fechas_eje,
          ticktext = etiquetas_es,
          tickangle = 0
        ),
        yaxis = list(title = "Índice HHI", range = c(0, max(df_hhi$HHI, 3000) * 1.1)),
        shapes = list(
          list(type = "rect", layer = "below", x0 = min(df_hhi$Fecha), x1 = max(df_hhi$Fecha),
               y0 = 0, y1 = 1500, fillcolor = "#2A9D8F", opacity = 0.05, line = list(width = 0)),
          list(type = "rect", layer = "below", x0 = min(df_hhi$Fecha), x1 = max(df_hhi$Fecha),
               y0 = 1500, y1 = 2500, fillcolor = "#E07B39", opacity = 0.05, line = list(width = 0)),
          list(type = "line", x0 = 0, x1 = 1, xref = "paper", y0 = 1500, y1 = 1500, line = list(color = "grey", dash = "dot", width = 1)),
          list(type = "line", x0 = 0, x1 = 1, xref = "paper", y0 = 2500, y1 = 2500, line = list(color = "grey", dash = "dot", width = 1))
        )
      )
  })

  # --- Reactive: Load Factor promedio por pais en el periodo ---
  lf_periodo <- reactive({
    req(data$load_factor_pais, input$periodo_analitica)
    lf <- data$load_factor_pais
    n_meses <- as.integer(input$periodo_analitica)
    fecha_max <- max(lf$Fecha, na.rm = TRUE)
    fecha_corte <- fecha_max %m-% months(n_meses)
    lf %>%
      dplyr::filter(Fecha > fecha_corte, !is.na(LoadFactor)) %>%
      dplyr::group_by(Pais) %>%
      dplyr::summarise(LF_promedio = mean(LoadFactor, na.rm = TRUE), .groups = "drop")
  })

  # Helper: construir scatter plot con zonas de load factor
  build_lf_scatter <- function(df_plot, x_col, x_title, hover_fn, log_x = FALSE) {
    # Definir limites de Load Factor (Eje Y)
    y_min <- 0
    y_max <- 105
    
    # Definir zonas de Load Factor (Umbrales estandar JAC/IATA)
    # Verde: < 70%, Amarillo: 70-85%, Rojo: > 85%
    
    p <- plot_ly() %>%
      # 1. Zonas de fondo (Shapes) - Capas inferiores
      layout(
        shapes = list(
          # Zona Verde: Capacidad disponible
          list(type = "rect", layer = "below", xref = "paper", x0 = 0, x1 = 1,
               y0 = 0, y1 = 70, yref = "y", fillcolor = "#2A9D8F", opacity = 0.08, line = list(width = 0)),
          # Zona Amarilla: Equilibrio
          list(type = "rect", layer = "below", xref = "paper", x0 = 0, x1 = 1,
               y0 = 70, y1 = 85, yref = "y", fillcolor = "#E9C46A", opacity = 0.08, line = list(width = 0)),
          # Zona Roja: Saturacion
          list(type = "rect", layer = "below", xref = "paper", x0 = 0, x1 = 1,
               y0 = 85, y1 = y_max, yref = "y", fillcolor = "#E76F51", opacity = 0.08, line = list(width = 0)),
          # Lineas divisorias
          list(type = "line", xref = "paper", x0 = 0, x1 = 1, y0 = 70, y1 = 70, yref = "y",
               line = list(color = "#adb5bd", width = 1, dash = "dot")),
          list(type = "line", xref = "paper", x0 = 0, x1 = 1, y0 = 85, y1 = 85, yref = "y",
               line = list(color = "#adb5bd", width = 1, dash = "dot"))
        )
      ) %>%
      # 2. Marcadores
      add_markers(
        data = df_plot, x = as.formula(paste0("~", x_col)), y = ~LF_promedio,
        marker = list(
          size = 14,
          color = COLORES_CONTINENTE[df_plot$Continente],
          line = list(width = 1.5, color = "white"),
          opacity = 0.9
        ),
        text = ~Pais, textposition = "top center",
        hovertext = hover_fn(df_plot),
        hoverinfo = "text", showlegend = FALSE
      ) %>%
      # 3. Etiquetas de paises (Texto estatico pequeño)
      add_text(
        data = df_plot, x = as.formula(paste0("~", x_col)), y = ~LF_promedio,
        text = ~Pais, textposition = "top center",
        textfont = list(size = 9, color = "#495057"),
        hoverinfo = "none", showlegend = FALSE
      )

    # Calculo de rangos del Eje X
    x_vals <- df_plot[[x_col]]
    if (log_x) {
      x0 <- min(x_vals) * 0.7
      x1 <- max(x_vals) * 1.5
    } else {
      x0 <- 0
      x1 <- max(x_vals) * 1.1
    }

    p %>% layout_dashboard(
      xaxis = list(
        title = x_title,
        type = if(log_x) "log" else "linear",
        range = if(log_x) log10(c(x0, x1)) else c(x0, x1),
        tickformat = if(log_x) ".1s" else ",.0f", # .1s reduce la longitud de los numeros (ej: 100k)
        dtick = if(log_x) 1 else NULL, # Controla la densidad de marcas en log
        gridcolor = "#f1f3f5"
      ),
      yaxis = list(
        title = "Load Factor Promedio (%)",
        ticksuffix = "%",
        range = c(0, y_max),
        gridcolor = "#f1f3f5"
      ),
      hovermode = "closest",
      annotations = list(
        list(x = 1, xref = "paper", xanchor = "right", y = 35, yref = "y",
             text = "CAPACIDAD DISPONIBLE", showarrow = FALSE,
             font = list(size = 8, color = "#264653", weight = "bold")),
        list(x = 1, xref = "paper", xanchor = "right", y = 77.5, yref = "y",
             text = "EQUILIBRIO", showarrow = FALSE,
             font = list(size = 8, color = "#856404", weight = "bold")),
        list(x = 1, xref = "paper", xanchor = "right", y = 95, yref = "y",
             text = "SATURACIÓN", showarrow = FALSE,
             font = list(size = 8, color = "#721c24", weight = "bold"))
      )
    )
  }

  # --- Matriz de Capacidad Aérea Dinámica ---
  output$plot_lf_dinamico <- renderPlotly({
    req(input$tipo_analisis_maestro, data$nacionalidad, data$load_factor_pais)
    df <- datos_periodo()
    paises <- paises_validos()
    lf_data <- lf_periodo()
    
    is_top <- input$tipo_analisis_maestro == "top"
    
    if (is_top) {
      totales_pais <- sort(colSums(df[, paises, drop = FALSE], na.rm = TRUE), decreasing = TRUE)
      top_n <- head(totales_pais, 10)
      df_base <- data.frame(Pais = names(top_n), X_Val = as.numeric(top_n), stringsAsFactors = FALSE)
      x_title <- "Total Llegadas (escala log)"
    } else {
      # Emergentes
      n_meses <- as.integer(input$periodo_analitica)
      df_completo <- data$nacionalidad
      fecha_max <- max(df_completo$Fecha, na.rm = TRUE)
      fecha_corte_actual <- fecha_max %m-% months(n_meses)
      fecha_corte_previo <- fecha_corte_actual %m-% months(n_meses)
      df_actual <- df_completo %>% dplyr::filter(Fecha > fecha_corte_actual)
      df_previo <- df_completo %>% dplyr::filter(Fecha > fecha_corte_previo & Fecha <= fecha_corte_actual)
      suma_actual <- colSums(df_actual[, paises, drop = FALSE], na.rm = TRUE)
      suma_previo <- colSums(df_previo[, paises, drop = FALSE], na.rm = TRUE)
      validos <- names(suma_actual)[suma_actual > 100 & suma_previo > 0]
      variacion <- ((suma_actual[validos] - suma_previo[validos]) / suma_previo[validos]) * 100
      variacion <- variacion[variacion > 0]
      top_n <- head(sort(variacion, decreasing = TRUE), 10)
      df_base <- data.frame(Pais = names(top_n), X_Val = as.numeric(top_n), stringsAsFactors = FALSE)
      x_title <- "Crecimiento (%)"
    }
    
    df_plot <- merge(df_base, lf_data, by = "Pais")
    if (nrow(df_plot) == 0) return(empty_plotly("No hay datos de ocupación para estos mercados"))
    df_plot$Continente <- get_continente(df_plot$Pais)
    
    hover_fn <- function(d) {
      paste0("<b>", d$Pais, "</b><br>",
             if(is_top) "Llegadas: " else "Crecimiento: ", fmt_num(d$X_Val), 
             if(!is_top) "%" else "",
             "<br>Load Factor: ", round(d$LF_promedio, 1), "%")
    }
    
    build_lf_scatter(df_plot, "X_Val", x_title, hover_fn, log_x = is_top)
  })

}
