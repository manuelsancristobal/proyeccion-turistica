# export_charts.R
# Genera graficos estaticos PNG para el portafolio en GitHub Pages
# Uso: Rscript export_charts.R

library(ggplot2)
library(dplyr)
library(readr)
library(tidyr)
library(lubridate)

# --- Config ---
base_path <- "."
output_dir <- file.path(base_path, "portfolio_charts")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

data_salidas  <- file.path(base_path, "dashboard/data/salidas")
data_llegadas <- file.path(base_path, "dashboard/data/llegadas")
data_trafico  <- file.path(base_path, "dashboard/data/trafico_aereo")

# Paleta consistente con el dashboard
COLOR_REAL      <- "#2C6FAC"
COLOR_TENDENCIA <- "#2A9D8F"
COLOR_ARIMA     <- "#8E6BBF"
COLOR_SARIMAX   <- "#C44E52"
COLOR_HHI       <- "#E07B39"

COLORES_CONTINENTE <- c(
  "AMERICA DEL SUR"   = "#2A9D8F",
  "EUROPA"            = "#E07B39",
  "AMERICA DEL NORTE" = "#2C6FAC",
  "ASIA"              = "#C44E52",
  "OCEANIA"           = "#8E6BBF",
  "AMERICA CENTRAL"   = "#7FB069",
  "CARIBE"            = "#5BA3CF",
  "MEDIO ORIENTE"     = "#D4A03C",
  "AFRICA"            = "#D97DB0",
  "OTROS"             = "#888888"
)

theme_portfolio <- theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 15, color = "#212529"),
    plot.subtitle = element_text(size = 11, color = "#6c757d"),
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    legend.title = element_blank()
  )

fmt_miles <- function(x) format(x, big.mark = ".", decimal.mark = ",", scientific = FALSE)

cat("Exportando graficos para el portafolio...\n")

# ============================================================
# 1. Salidas de residentes + tendencia + proyecciones
# ============================================================
cat("  [1/5] Salidas de residentes con proyecciones...\n")
merged <- read_csv(list.files(data_salidas, "^merged_", full.names = TRUE)[1], show_col_types = FALSE)
merged$Fecha <- as.Date(merged$Fecha)

unified <- read_csv(file.path(data_salidas, "unified_forecast.csv"), show_col_types = FALSE)
unified$Fecha <- as.Date(unified$Fecha)

# Tendencia STL
trend <- read_csv(list.files(data_salidas, "^trend_", full.names = TRUE)[1], show_col_types = FALSE)
trend$Fecha <- as.Date(trend$Fecha)

# unified tiene columna con nombre de codigo (ej: "202512"), renombrar
forecast_col <- setdiff(names(unified), "Fecha")[1]
unified$Forecast <- unified[[forecast_col]]

# merged: Cantidad = salidas observadas; arima_Pronostico y sarimax_Pronostico = proyecciones
# Separar historico de proyeccion
historico <- merged %>% filter(!is.na(Cantidad))
proyeccion_arima   <- merged %>% filter(!is.na(arima_Pronostico) & is.na(Cantidad) | arima_Pronostico != Cantidad)
proyeccion_sarimax <- merged %>% filter(!is.na(sarimax_Pronostico) & is.na(Cantidad) | sarimax_Pronostico != Cantidad)

p1 <- ggplot() +
  geom_line(data = merged, aes(x = Fecha, y = Cantidad, color = "Observado"), linewidth = 0.6) +
  geom_line(data = trend, aes(x = Fecha, y = Tendencia, color = "Tendencia STL"), linewidth = 0.8) +
  geom_line(data = merged %>% filter(!is.na(arima_Pronostico)),
            aes(x = Fecha, y = arima_Pronostico, color = "ARIMA"), linewidth = 0.7, linetype = "dashed") +
  geom_line(data = merged %>% filter(!is.na(sarimax_Pronostico)),
            aes(x = Fecha, y = sarimax_Pronostico, color = "SARIMAX"), linewidth = 0.7, linetype = "dashed") +
  scale_color_manual(values = c(
    "Observado" = COLOR_REAL,
    "Tendencia STL" = COLOR_TENDENCIA,
    "ARIMA" = COLOR_ARIMA,
    "SARIMAX" = COLOR_SARIMAX
  )) +
  scale_y_continuous(labels = fmt_miles) +
  labs(
    title = "Salidas de residentes chilenos al extranjero",
    subtitle = "Serie historica, tendencia y proyecciones ARIMA/SARIMAX",
    x = NULL, y = "Salidas mensuales"
  ) +
  theme_portfolio

ggsave(file.path(output_dir, "01_salidas_proyeccion.png"), p1, width = 10, height = 5.5, dpi = 150, bg = "white")

# ============================================================
# 2. Llegadas por nacionalidad (top 5)
# ============================================================
cat("  [2/5] Llegadas por nacionalidad...\n")
llegadas <- read_csv(file.path(data_llegadas, "llegadas_nacionalidad.csv"), show_col_types = FALSE)
llegadas$Fecha <- as.Date(llegadas$Fecha)

# Obtener top 5 nacionalidades por volumen total
totales <- llegadas %>%
  select(-Fecha) %>%
  summarise(across(everything(), ~sum(.x, na.rm = TRUE))) %>%
  pivot_longer(everything(), names_to = "Nacionalidad", values_to = "Total") %>%
  filter(!grepl("_trend$", Nacionalidad)) %>%
  arrange(desc(Total)) %>%
  head(5)

top5 <- totales$Nacionalidad

llegadas_long <- llegadas %>%
  select(Fecha, all_of(top5)) %>%
  pivot_longer(-Fecha, names_to = "Nacionalidad", values_to = "Llegadas")

p2 <- ggplot(llegadas_long, aes(x = Fecha, y = Llegadas, color = Nacionalidad)) +
  geom_line(linewidth = 0.7) +
  scale_y_continuous(labels = fmt_miles) +
  labs(
    title = "Llegadas de turistas extranjeros a Chile",
    subtitle = paste("Top 5 mercados emisores:", paste(top5, collapse = ", ")),
    x = NULL, y = "Llegadas mensuales"
  ) +
  theme_portfolio

ggsave(file.path(output_dir, "02_llegadas_nacionalidad.png"), p2, width = 10, height = 5.5, dpi = 150, bg = "white")

# ============================================================
# 3. Frecuencia de vuelos internacionales
# ============================================================
cat("  [3/5] Frecuencia de vuelos...\n")
freq <- read_csv(file.path(data_salidas, "frecuencia_vuelos_salientes.csv"), show_col_types = FALSE)
freq$Fecha <- as.Date(freq$Fecha)

p3 <- ggplot(freq, aes(x = Fecha, y = Operaciones)) +
  geom_line(color = COLOR_REAL, linewidth = 0.7) +
  geom_smooth(method = "loess", se = FALSE, color = COLOR_TENDENCIA, linewidth = 0.8, span = 0.3) +
  scale_y_continuous(labels = fmt_miles) +
  labs(
    title = "Frecuencia de vuelos internacionales salientes",
    subtitle = "Total de operaciones aereas mensuales con suavizado LOESS",
    x = NULL, y = "Operaciones mensuales"
  ) +
  theme_portfolio +
  theme(legend.position = "none")

ggsave(file.path(output_dir, "03_frecuencia_vuelos.png"), p3, width = 10, height = 5, dpi = 150, bg = "white")

# ============================================================
# 4. Load Factor por aeropuerto (top aeropuertos)
# ============================================================
cat("  [4/5] Load factor por aeropuerto...\n")
lf <- read_csv(file.path(data_trafico, "load_factor_aeropuerto.csv"), show_col_types = FALSE)
lf$Fecha <- as.Date(lf$Fecha)

# Top aeropuertos por volumen
top_aero <- lf %>%
  group_by(Aeropuerto) %>%
  summarise(vol = sum(Pasajeros, na.rm = TRUE)) %>%
  arrange(desc(vol)) %>%
  head(5) %>%
  pull(Aeropuerto)

lf_top <- lf %>% filter(Aeropuerto %in% top_aero)

# LoadFactor esta en porcentaje (0-100), convertir a 0-1
lf_top$LoadFactor <- lf_top$LoadFactor / 100

p4 <- ggplot(lf_top, aes(x = Fecha, y = LoadFactor, color = Aeropuerto)) +
  geom_line(linewidth = 0.7) +
  geom_hline(yintercept = 0.85, linetype = "dashed", color = "#C44E52", alpha = 0.6) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1.1)) +
  labs(
    title = "Factor de ocupacion por aeropuerto",
    subtitle = "Top 5 aeropuertos. Linea roja: umbral de saturacion (85%)",
    x = NULL, y = "Load Factor"
  ) +
  theme_portfolio

ggsave(file.path(output_dir, "04_load_factor.png"), p4, width = 10, height = 5.5, dpi = 150, bg = "white")

# ============================================================
# 5. Estacionalidad (heatmap salidas)
# ============================================================
cat("  [5/5] Estacionalidad...\n")
estac <- merged %>%
  mutate(Anio = year(Fecha), Mes = month(Fecha)) %>%
  filter(!is.na(Cantidad))

MESES_ES <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
              "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
estac$Mes_label <- factor(MESES_ES[estac$Mes], levels = MESES_ES)

p5 <- ggplot(estac, aes(x = Mes_label, y = factor(Anio), fill = Cantidad)) +
  geom_tile(color = "white", linewidth = 0.3) +
  scale_fill_gradient2(low = "#f7fbff", mid = "#6baed6", high = "#08306b",
                       midpoint = median(estac$Cantidad, na.rm = TRUE),
                       labels = fmt_miles) +
  labs(
    title = "Estacionalidad de salidas de residentes",
    subtitle = "Patron mensual por ano. Colores mas intensos indican mayor flujo",
    x = NULL, y = NULL, fill = "Cantidad"
  ) +
  theme_portfolio +
  theme(
    legend.position = "right",
    axis.text.x = element_text(size = 10),
    panel.grid = element_blank()
  )

ggsave(file.path(output_dir, "05_estacionalidad.png"), p5, width = 10, height = 6, dpi = 150, bg = "white")

cat("\nGraficos exportados en:", normalizePath(output_dir), "\n")
cat("Archivos generados:\n")
cat(paste(" ", list.files(output_dir, pattern = "\\.png$"), collapse = "\n"), "\n")
