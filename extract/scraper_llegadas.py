"""
Scraper de llegadas de turistas extranjeros (turismo receptivo).
Descarga el Excel desde la URL configurada y genera CSVs en formato wide.
"""

import logging
import re
from pathlib import Path

import pandas as pd
import requests

from .utils import (
    MESES_MAP,
    descargar_excel,
    get_http_session,
    match_sheet_name,
    normalize_numeric,
    strip_accents_lower,
)

logger = logging.getLogger(__name__)


def _match_sheet_llegadas(available: list, keyword: str = "llegadas"):
    """Busca la hoja que contenga el keyword (sin tildes)."""
    return match_sheet_name(available, keyword, heuristic_keywords=["datos", "serie", "hoja1"])


_SKIP_KEYWORDS = {"total", "variaci", "acumul", "promedio", "nan", "none"}


def _find_year_row(df: pd.DataFrame, max_rows: int = 10) -> int | None:
    """Devuelve el indice de la primera fila que contiene >= 2 años (2000-2030)."""
    for i in range(min(max_rows, len(df))):
        row = df.iloc[i]
        year_count = sum(1 for v in row if str(v).strip().isdigit() and 2000 <= int(str(v).strip()) <= 2030)
        if year_count >= 2:
            return i
    return None


def _build_col_date_map(year_row: pd.Series, month_row: pd.Series) -> dict:
    """
    Combina la fila de años y la fila de meses para construir
    un mapeo {col_position: pd.Timestamp}.
    El año se propaga hacia la derecha (forward-fill de celdas fusionadas).
    Se resetea al encontrar texto no-numérico (ej. 'Total XXXX', 'Variacion...'),
    lo que evita mapear columnas de totales o variaciones a fechas reales.
    """
    current_year = None
    col_date_map = {}
    for j in range(len(year_row)):
        yr_val = str(year_row.iloc[j]).strip()
        if yr_val.isdigit() and 2000 <= int(yr_val) <= 2030:
            current_year = int(yr_val)
        elif yr_val not in ("nan", "none", ""):
            # Texto no-año (ej. "Total 2008", "Variación 2025/2024 (%)"):
            # indica fin de la sección de datos mensuales → resetear año
            current_year = None
        if current_year is None:
            continue
        mon_val = strip_accents_lower(str(month_row.iloc[j])).strip()
        month_num = MESES_MAP.get(mon_val)
        if month_num is not None:
            col_date_map[j] = pd.Timestamp(year=current_year, month=month_num, day=1)
    return col_date_map


def _parse_llegadas_excel(buf, sheet_name) -> pd.DataFrame:
    """
    Parsea un Excel de llegadas cuya estructura real es:
      - Filas = entidades (nacionalidades o pasos fronterizos)
      - Columnas = meses organizados por año (cabecera de 2 niveles)

    Retorna un DataFrame transpuesto con:
      - Filas = meses (Fecha)
      - Columnas = entidades
    """
    buf.seek(0)
    df_raw = pd.read_excel(buf, sheet_name=sheet_name, header=None, engine="openpyxl")
    logger.info("Excel cargado: %d filas x %d cols (hoja: %s)", df_raw.shape[0], df_raw.shape[1], sheet_name)

    df_raw.dropna(how="all", inplace=True)
    df_raw.dropna(axis=1, how="all", inplace=True)
    df_raw.reset_index(drop=True, inplace=True)

    if df_raw.empty:
        return pd.DataFrame()

    # 1. Detectar fila de años (p.ej. "2008", "2009", ...)
    year_row_idx = _find_year_row(df_raw)
    if year_row_idx is None:
        logger.warning("No se encontro fila de años en hoja '%s'", sheet_name)
        return pd.DataFrame()

    # 2. La fila de meses (ene, feb, ...) esta justo debajo
    month_row_idx = year_row_idx + 1
    if month_row_idx >= len(df_raw):
        return pd.DataFrame()

    year_row = df_raw.iloc[year_row_idx]
    month_row = df_raw.iloc[month_row_idx]

    # 3. Construir mapeo columna → fecha
    col_date_map = _build_col_date_map(year_row, month_row)
    if not col_date_map:
        logger.warning("No se pudo reconstruir fechas en hoja '%s'", sheet_name)
        return pd.DataFrame()

    # 4. La columna de entidad es la que tiene un texto descriptivo (no año, no NaN)
    # en la fila de años — ej. "NACIONALIDAD" o "PASO FRONTERIZO"
    entity_col_idx = None
    for j in range(df_raw.shape[1]):
        val = str(year_row.iloc[j]).strip()
        is_year = val.isdigit() and 2000 <= int(val) <= 2030
        is_empty = val in ("nan", "none", "")
        if not is_year and not is_empty and j not in col_date_map:
            entity_col_idx = j
            break
    # Fallback: primera columna que no sea de fechas
    if entity_col_idx is None:
        entity_col_idx = next((j for j in range(df_raw.shape[1]) if j not in col_date_map), None)
    if entity_col_idx is None:
        return pd.DataFrame()

    # 5. Leer filas de datos (despues de la fila de meses)
    data_start = month_row_idx + 1
    df_data = df_raw.iloc[data_start:].copy()
    df_data.dropna(how="all", inplace=True)

    if df_data.empty:
        return pd.DataFrame()

    # 6. Extraer nombres de entidades y filtrar totales/variaciones
    entity_col = df_data.columns[entity_col_idx]
    entity_names = df_data[entity_col].astype(str).str.strip()

    valid_mask = ~entity_names.map(lambda x: any(kw in strip_accents_lower(x) for kw in _SKIP_KEYWORDS))
    df_data = df_data[valid_mask]
    entity_names = entity_names[valid_mask]

    if df_data.empty:
        return pd.DataFrame()

    # 7. Construir DataFrame resultado: filas = fechas, columnas = entidades
    sorted_cols = sorted(col_date_map.keys())
    dates = [col_date_map[j] for j in sorted_cols]

    result_rows = {}
    for entity, (_, row) in zip(entity_names.values, df_data.iterrows()):
        entity = entity.strip()
        if not entity or strip_accents_lower(entity) in _SKIP_KEYWORDS:
            continue
        values = []
        for j in sorted_cols:
            col_label = df_raw.columns[j]
            try:
                raw_val = row[col_label]
                s = normalize_numeric(str(raw_val))
                values.append(pd.to_numeric(s, errors="coerce"))
            except Exception:
                values.append(float("nan"))
        result_rows[entity] = values

    if not result_rows:
        return pd.DataFrame()

    result = pd.DataFrame(result_rows, index=dates)
    result.index.name = "Fecha"
    result = result.reset_index()
    result = result.sort_values("Fecha").reset_index(drop=True)

    logger.info("Hoja '%s': %d fechas x %d entidades", sheet_name, len(result), len(result.columns) - 1)
    return result


def extraer_llegadas(url: str, out_dir: Path, timeout: int = 15, session: requests.Session | None = None) -> list[Path]:
    """
    Descarga el Excel de llegadas y genera CSVs en formato wide.
    El Excel puede tener multiples hojas (por nacionalidad, por paso, etc).
    """
    sess = session or get_http_session(timeout)
    out_dir.mkdir(parents=True, exist_ok=True)

    buf = descargar_excel(url, session=sess, timeout=timeout)
    xls = pd.ExcelFile(buf, engine="openpyxl")
    logger.info("Hojas disponibles: %s", xls.sheet_names)

    generados: list[Path] = []

    # Intentar encontrar hojas por tipo
    hojas_config = [
        ("nacionalidad", ["nacionalidad", "pais", "extranjero"]),
        ("paso", ["paso", "aeropuerto", "frontera", "control"]),
    ]

    hojas_procesadas = set()

    for tipo, keywords in hojas_config:
        for sheet in xls.sheet_names:
            sn = strip_accents_lower(sheet)
            if any(kw in sn for kw in keywords) and sheet not in hojas_procesadas:
                logger.info("Procesando hoja '%s' como tipo '%s'", sheet, tipo)
                df = _parse_llegadas_excel(buf, sheet)
                if not df.empty:
                    ruta = out_dir / f"llegadas_{tipo}.csv"
                    df.to_csv(ruta, index=False, encoding="utf-8")
                    logger.info("CSV exportado: %s (%d filas x %d cols)", ruta, len(df), len(df.columns))
                    generados.append(ruta)
                hojas_procesadas.add(sheet)
                break

    # Si no se encontraron hojas especificas, procesar todas
    if not generados:
        for i, sheet in enumerate(xls.sheet_names):
            if sheet in hojas_procesadas:
                continue
            logger.info("Procesando hoja '%s' (indice %d)", sheet, i)
            df = _parse_llegadas_excel(buf, sheet)
            if not df.empty:
                nombre = re.sub(r"[^\w\s-]", "", sheet).strip().replace(" ", "_").lower()
                ruta = out_dir / f"llegadas_{nombre or i}.csv"
                df.to_csv(ruta, index=False, encoding="utf-8")
                logger.info("CSV exportado: %s (%d filas x %d cols)", ruta, len(df), len(df.columns))
                generados.append(ruta)

    if not generados:
        logger.warning("No se pudieron extraer datos del Excel de llegadas.")

    return generados
