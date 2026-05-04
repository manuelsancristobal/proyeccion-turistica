"""
Punto de entrada de la capa Extract.
Lee URLs desde config.yml, descarga y parsea los Excel/Sheets, genera CSVs limpios.

Uso: python -m extract.main  (desde la raiz del proyecto)
  o: python extract/main.py
"""

import logging
import sys
from pathlib import Path

# Asegurar que el directorio raiz este en el path
ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from extract.config import load_config
from extract.scraper_llegadas import extraer_llegadas
from extract.scraper_salidas import extraer_salidas
from extract.scraper_trafico import extraer_trafico
from extract.utils import get_http_session

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


def main():
    cfg = load_config()
    timeout = cfg.get("extract", {}).get("timeout", 15)
    sources = cfg.get("sources", {})
    session = get_http_session(timeout)

    exitos = 0
    errores = 0

    # --- 1. Salidas (turismo emisivo) ---
    salidas_url = sources.get("salidas_url", "")
    if salidas_url:
        logger.info("=" * 60)
        logger.info("EXTRAYENDO: Salidas de residentes chilenos")
        logger.info("URL: %s", salidas_url)
        try:
            archivos = extraer_salidas(
                url=salidas_url,
                out_dir=cfg["_raw_salidas"],
                timeout=timeout,
                session=session,
            )
            logger.info("Salidas: %d archivos generados.", len(archivos))
            exitos += 1
        except Exception as e:
            logger.error("ERROR extrayendo salidas: %s", e)
            errores += 1
    else:
        logger.warning("No hay URL configurada para salidas en config.yml")

    # --- 2. Llegadas (turismo receptivo) ---
    llegadas_url = sources.get("llegadas_url", "")
    if llegadas_url:
        logger.info("=" * 60)
        logger.info("EXTRAYENDO: Llegadas de turistas extranjeros")
        logger.info("URL: %s", llegadas_url)
        try:
            archivos = extraer_llegadas(
                url=llegadas_url,
                out_dir=cfg["_raw_llegadas"],
                timeout=timeout,
                session=session,
            )
            logger.info("Llegadas: %d archivos generados.", len(archivos))
            exitos += 1
        except Exception as e:
            logger.error("ERROR extrayendo llegadas: %s", e)
            errores += 1
    else:
        logger.warning("No hay URL configurada para llegadas en config.yml")

    # --- 3. Trafico aereo (Google Sheets) ---
    trafico_url = sources.get("trafico_url", "")
    if trafico_url:
        logger.info("=" * 60)
        logger.info("EXTRAYENDO: Tráfico aéreo")
        logger.info("URL: %s", trafico_url)
        try:
            ruta = extraer_trafico(
                url=trafico_url,
                out_dir=cfg["_raw_trafico"],
                timeout=timeout,
                session=session,
            )
            logger.info("Tráfico aéreo: archivo generado en %s", ruta)
            exitos += 1
        except Exception as e:
            logger.error("ERROR extrayendo tráfico aéreo: %s", e)
            errores += 1
    else:
        logger.warning("No hay URL configurada para tráfico aéreo en config.yml")

    # --- Resumen ---
    logger.info("=" * 60)
    logger.info("EXTRACT COMPLETADO: %d éxitos, %d errores", exitos, errores)

    if errores > 0:
        logger.error("Hubo errores en la extracción. Revisa las URLs en config.yml.")
        sys.exit(1)


if __name__ == "__main__":
    main()
