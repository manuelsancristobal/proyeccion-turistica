# Proyección Turística Chile — Dashboard Interactivo

Dashboard interactivo con modelado estadístico para proyectar flujos turísticos de Chile, integrando datos de SERNATUR y la Junta Aeronáutica Civil. Incluye descomposición STL, modelos ARIMA y SARIMAX, y análisis de conectividad aérea.

## Guía para Principiantes

### ¿Qué es `make`?

`make` es una herramienta que ejecuta comandos predefinidos. En vez de recordar comandos largos, solo escribes `make` seguido de una palabra clave. Para ver todos los comandos disponibles:

```bash
make help
```

### Requisitos Previos

1. **Python 3.10 o superior** — [Descargar aquí](https://www.python.org/downloads/)
2. **R 4.0 o superior** — [Descargar aquí](https://cran.r-project.org/)
3. **Git** — [Descargar aquí](https://git-scm.com/downloads)
4. **Make** — En Windows viene incluido con Git Bash. En macOS/Linux ya está instalado.

> Este proyecto usa Python para descargar los datos y R para procesarlos y visualizarlos. Necesitas ambos instalados.

### Instalación paso a paso

```bash
# 1. Clonar el repositorio
git clone https://github.com/manuelsancristobal/proyeccion-turistica.git
cd proyeccion-turistica

# 2. Crear un entorno virtual (aísla las dependencias Python de este proyecto)
python -m venv .venv

# 3. Activar el entorno virtual
source .venv/Scripts/activate   # Windows (Git Bash)
# source .venv/bin/activate     # Linux / macOS

# 4. Instalar el proyecto y sus dependencias
make install-dev
```

### Comandos principales

Todos los comandos se ejecutan desde la carpeta raíz del proyecto, con el entorno virtual activado.

```bash
make help          # Muestra todos los comandos disponibles
make extract       # Descarga datos desde SERNATUR y Google Sheets (Python)
make transform     # Procesa datos y genera pronósticos (R)
make assets        # Genera gráficos estáticos para el portafolio (R)
make launch        # Abre el dashboard interactivo en el navegador (R)
make test          # Ejecuta los tests para verificar que todo funciona
make lint          # Verifica la calidad del código Python
make deploy-jekyll # Copia página del proyecto al portafolio web
make deploy-shiny  # Publica el dashboard en shinyapps.io
make deploy        # Ejecuta ambos deploys
make clean         # Elimina archivos temporales
```

### Flujo de trabajo típico

```bash
# 1. Descargar los datos más recientes
make extract

# 2. Procesar datos y generar pronósticos
make transform

# 3. Ver el dashboard en tu navegador
make launch

# 4. Si modificaste el análisis en jekyll/proyeccion-turistica.md:
make deploy-jekyll    # Copia al repo Jekyll (portafolio web)
```

### ¿Cómo actualizo el análisis en el portafolio web?

```
Tu proyecto                          Repo Jekyll                   Sitio web
─────────────                        ──────────                    ─────────

jekyll/proyeccion-turistica.md ──┐
                                 ├─ make deploy-jekyll ──→  _projects/proyeccion-turistica.md
portfolio_charts/*.png         ──┘                         proyectos/proyeccion-turistica/assets/
                                                                  │
                                                            git push ──→  manuelsancristobal.github.io
```

**Para modificar texto de análisis:**

1. Edita `jekyll/proyeccion-turistica.md` con los cambios que quieras
2. Ejecuta `make deploy-jekyll` (copia los archivos al repo Jekyll local)
3. Ve a la carpeta del repo Jekyll (`~/manuelsancristobal.github.io`)
4. Ejecuta `git add . && git commit -m "actualizar análisis" && git push`
5. Espera ~1 minuto y el cambio aparece en tu sitio web

**Para agregar un gráfico nuevo:**

1. Genera el gráfico con `make assets` (los PNGs quedan en `portfolio_charts/`)
2. Edita `jekyll/proyeccion-turistica.md` y agrega la referencia al gráfico:
   ```markdown
   ![Descripción del gráfico](./assets/charts/mi_grafico.png)
   ```
3. Ejecuta `make deploy-jekyll` (copia el `.md` y los PNGs al repo Jekyll)
4. Ve al repo Jekyll, haz commit y push

> **Importante:** `make deploy-jekyll` solo copia archivos a tu computador. El sitio web no se actualiza hasta que haces `git push` en el repo Jekyll. Si también quieres actualizar el dashboard interactivo en shinyapps.io, usa `make deploy-shiny` o `make deploy` (que hace ambos).

---

## Estructura del Proyecto

```
├── extract/              # Capa Extract (Python): descarga Excel y Google Sheets
│   ├── main.py           # Punto de entrada
│   ├── scraper_salidas.py
│   ├── scraper_llegadas.py
│   └── scraper_trafico.py
├── transform/            # Capa Transform (R): STL, ARIMA, SARIMAX
│   ├── main.R
│   ├── arima_forecast.R
│   ├── sarimax_forecast.R
│   └── stl_decomposition.R
├── dashboard/            # App R Shiny
│   ├── app.R
│   ├── ui.R
│   ├── server.R
│   └── global.R
├── portfolio_charts/     # PNGs estáticos para portafolio
├── jekyll/               # Markdown del proyecto para portafolio Jekyll
├── scripts/              # Scripts de deploy
├── tests/                # Tests unitarios (Python)
├── config.yml            # Configuración central del pipeline
└── Makefile              # Punto de entrada estandarizado
```

## Tech Stack

- **Python**: pandas, requests, openpyxl — extracción y parseo de datos
- **R**: shiny, plotly, forecast, dplyr, tidyr — transformación y visualización
- **Modelos**: ARIMA, SARIMAX con variable dummy pandémica, descomposición STL
- **Deploy**: shinyapps.io (dashboard) + GitHub Pages (portafolio)

## Pipeline ETL

1. **Extract** (Python): Descarga Excel de salidas/llegadas desde SERNATUR y tráfico aéreo desde Google Sheets
2. **Transform** (R): Limpieza, descomposición STL, pronósticos ARIMA/SARIMAX (horizonte 6 meses)
3. **Dashboard** (R Shiny): 3 módulos interactivos — Analítica, Llegadas, Salidas

## Deploy

El proyecto tiene dos destinos de deploy:

```bash
# Deploy dashboard interactivo a shinyapps.io
make deploy-shiny

# Deploy página estática al portafolio Jekyll
make deploy-jekyll

# Ambos
make deploy
```

Requiere configurar credenciales en `.Renviron` (ver `.Renviron.example`).

## Licencia

MIT License. Ver [LICENSE](LICENSE).
