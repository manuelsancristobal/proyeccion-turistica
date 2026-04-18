# -*- coding: utf-8 -*-
"""Carga configuracion desde config.yml."""

from pathlib import Path

import yaml


def load_config() -> dict:
    """Lee config.yml desde la raiz del proyecto."""
    root = Path(__file__).resolve().parent.parent
    cfg_path = root / "config.yml"
    if not cfg_path.exists():
        raise FileNotFoundError(f"No se encontro config.yml en {root}")
    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    base = Path(cfg.get("base_path", str(root)))
    cfg["_base"] = base
    cfg["_raw_salidas"] = base / cfg["paths"]["data_raw_salidas"]
    cfg["_raw_llegadas"] = base / cfg["paths"]["data_raw_llegadas"]
    cfg["_raw_trafico"] = base / cfg["paths"]["data_raw_trafico"]
    return cfg
