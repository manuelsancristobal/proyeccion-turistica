"""Tests para extract/config.py — carga de configuración."""

from pathlib import Path

from extract.config import load_config


class TestLoadConfig:
    def test_loads_successfully(self):
        cfg = load_config()
        assert isinstance(cfg, dict)

    def test_has_sources(self):
        cfg = load_config()
        assert "sources" in cfg

    def test_has_resolved_paths(self):
        cfg = load_config()
        assert "_raw_salidas" in cfg
        assert "_raw_llegadas" in cfg
        assert "_raw_trafico" in cfg
        assert isinstance(cfg["_raw_salidas"], Path)

    def test_has_extract_config(self):
        cfg = load_config()
        assert "extract" in cfg
        assert "timeout" in cfg["extract"]
