"""Copia assets y markdown del proyecto al repo Jekyll local."""

from __future__ import annotations

import logging
import os
import shutil
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ── Rutas ──────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
PORTFOLIO_CHARTS_DIR = PROJECT_ROOT / "portfolio_charts"

_default_jekyll = Path.home() / "OneDrive" / "Documentos" / "manuelsancristobal.github.io"
JEKYLL_REPO = Path(os.getenv("JEKYLL_REPO", str(_default_jekyll)))
JEKYLL_BASE = JEKYLL_REPO / "proyectos" / "proyeccion-turistica"
JEKYLL_CHARTS_DIR = JEKYLL_BASE / "assets" / "charts"
JEKYLL_PROJECTS_DIR = JEKYLL_REPO / "_projects"
JEKYLL_PROJECT_MD = PROJECT_ROOT / "jekyll" / "proyeccion-turistica.md"


def deploy() -> None:
    """Copia assets y .md al repo Jekyll. El push es manual."""
    # ── PNGs de portfolio_charts ──
    if PORTFOLIO_CHARTS_DIR.exists():
        JEKYLL_CHARTS_DIR.mkdir(parents=True, exist_ok=True)
        count = 0
        for f in PORTFOLIO_CHARTS_DIR.glob("*.png"):
            shutil.copy2(f, JEKYLL_CHARTS_DIR / f.name)
            count += 1
        logger.info("Copiados %d PNGs → %s", count, JEKYLL_CHARTS_DIR)
    else:
        logger.warning("Directorio de charts no existe: %s", PORTFOLIO_CHARTS_DIR)

    # ── Markdown del proyecto ──
    if JEKYLL_PROJECT_MD.exists():
        JEKYLL_PROJECTS_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(JEKYLL_PROJECT_MD, JEKYLL_PROJECTS_DIR / JEKYLL_PROJECT_MD.name)
        logger.info("Copiado proyecto .md → %s", JEKYLL_PROJECTS_DIR)
    else:
        logger.warning("Markdown no encontrado: %s", JEKYLL_PROJECT_MD)

    logger.info("Deploy completado. Recuerda hacer git push en el repo Jekyll.")


if __name__ == "__main__":
    deploy()
