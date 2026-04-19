"""Tests para extract/utils.py — utilidades compartidas de la capa Extract."""

import pandas as pd
import pytest

from extract.utils import (
    match_sheet_name,
    normalize_numeric,
    normalize_numeric_series,
    parse_mes_a_num,
    strip_accents_lower,
)


class TestStripAccentsLower:
    def test_basic(self):
        assert strip_accents_lower("Café") == "cafe"

    def test_extra_spaces(self):
        assert strip_accents_lower("  hola   mundo  ") == "hola mundo"

    def test_non_string(self):
        assert strip_accents_lower(123) == "123"


class TestNormalizeNumeric:
    def test_eu_format(self):
        assert normalize_numeric("12.345,67") == "12345.67"

    def test_us_format(self):
        assert normalize_numeric("12,345.67") == "12345.67"

    def test_plain(self):
        assert normalize_numeric("12345") == "12345"

    def test_eu_integer(self):
        assert normalize_numeric("1.234.567") == "1234567"


class TestNormalizeNumericSeries:
    def test_mixed_formats(self):
        s = pd.Series(["1.234", "5,678", "100"])
        result = normalize_numeric_series(s)
        assert pd.api.types.is_numeric_dtype(result)
        assert result.iloc[0] == 1234
        assert result.iloc[2] == 100


class TestParseMesANum:
    def test_spanish_names(self):
        assert parse_mes_a_num("Enero") == 1
        assert parse_mes_a_num("dic") == 12

    def test_english_names(self):
        assert parse_mes_a_num("January") == 1
        assert parse_mes_a_num("Dec") == 12

    def test_numeric(self):
        assert parse_mes_a_num("3") == 3
        assert parse_mes_a_num(7) == 7

    def test_invalid(self):
        assert parse_mes_a_num("xyz") is None

    def test_nan(self):
        assert parse_mes_a_num(float("nan")) is None


class TestMatchSheetName:
    def test_by_index(self):
        sheets = ["Hoja1", "Datos", "Resumen"]
        assert match_sheet_name(sheets, 1) == 1

    def test_by_name_exact(self):
        sheets = ["Hoja1", "Datos", "Resumen"]
        assert match_sheet_name(sheets, "Datos") == "Datos"

    def test_by_name_case_insensitive(self):
        sheets = ["Hoja1", "Series Históricas", "Resumen"]
        assert match_sheet_name(sheets, "series historicas") == "Series Históricas"

    def test_heuristic(self):
        sheets = ["Info", "Datos Principales", "Notas"]
        result = match_sheet_name(sheets, None, ["datos"])
        assert result == "Datos Principales"

    def test_fallback_first(self):
        sheets = ["ABC", "DEF"]
        result = match_sheet_name(sheets, None, ["xyz"])
        assert result == "ABC"

    def test_index_out_of_range(self):
        with pytest.raises(ValueError):
            match_sheet_name(["A", "B"], 5)
