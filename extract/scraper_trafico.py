"""
Descarga datos de trafico aereo desde Google Sheets.
"""

import logging
import re
import unicodedata
from pathlib import Path

import pandas as pd
import requests

from .utils import get_http_session

logger = logging.getLogger(__name__)


def _build_export_url(sheets_url: str) -> str:
    """Convierte URL de Google Sheets a URL de exportacion CSV."""
    # Extraer el ID del spreadsheet
    m = re.search(r"/d/([a-zA-Z0-9_-]+)", sheets_url)
    if not m:
        raise ValueError(f"No se pudo extraer ID del spreadsheet de: {sheets_url}")
    sheet_id = m.group(1)
    return f"https://docs.google.com/spreadsheets/d/{sheet_id}/export?format=csv"


def _normalize_colname(name: str) -> str:
    """Quita acentos, normaliza espacios y pasa a minúsculas."""
    s = unicodedata.normalize("NFKD", str(name))
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", s).strip().lower()


def _clean_numeric_col(s: pd.Series) -> pd.Series:
    """Limpia separador de miles (punto seguido de 3 dígitos) y convierte a numérico."""
    s = s.astype(str).str.strip()
    s = s.str.replace(r"^(\d+)\.(\d{3})$", r"\1\2", regex=True)
    return pd.to_numeric(s, errors="coerce")


_COL_ALIASES = {
    "ano": ["ano", "anio", "year"],
    "mes": ["mes", "month", "mm"],
    "pasajeros": ["pasajeros", "pax", "pax_total", "passengers"],
    "direccion": ["oper_2", "direccion", "direction"],
    "tipo": ["nac", "tipo", "type"],
    "operador": ["cod_operador", "operador"],
    "origen": ["orig_1"],
    "destino": ["dest_1"],
    "pais_origen": ["orig_1_pais"],
}


def _detect_col(norm_names: list, alias_key: str) -> str | None:
    """Detecta una columna por sus alias conocidos."""
    aliases = _COL_ALIASES.get(alias_key, [])
    for a in aliases:
        if a in norm_names:
            return a
    return None


def _normalize_trafico_csv(ruta: Path) -> pd.DataFrame:
    """Lee el CSV crudo de tráfico y lo normaliza a columnas estándar.

    Retorna DataFrame con columnas: Fecha, Pasajeros, Direccion, Tipo,
    y opcionalmente: Operador, Origen, Destino, PaisOrigen, Mes.
    """
    df = pd.read_csv(ruta, encoding="utf-8")
    if df.empty:
        return pd.DataFrame()

    norm_names = [_normalize_colname(c) for c in df.columns]
    df.columns = norm_names

    ano_col = _detect_col(norm_names, "ano")
    mes_col = _detect_col(norm_names, "mes")
    pax_col = _detect_col(norm_names, "pasajeros")

    if not ano_col or not mes_col:
        logger.warning("CSV de trafico sin columnas de ano/mes: %s", ruta)
        return pd.DataFrame()

    # Limpiar numéricas
    df[ano_col] = _clean_numeric_col(df[ano_col])
    df[mes_col] = _clean_numeric_col(df[mes_col])
    if pax_col:
        df[pax_col] = _clean_numeric_col(df[pax_col])

    # Construir Fecha
    df["Fecha"] = pd.to_datetime(
        df[ano_col].astype("Int64").astype(str) + "-" + df[mes_col].astype("Int64").astype(str) + "-01", errors="coerce"
    )
    df["Mes"] = df[mes_col]

    # Pasajeros
    if pax_col:
        df["Pasajeros"] = df[pax_col]

    # Dirección (SALEN/LLEGAN)
    dir_col = _detect_col(norm_names, "direccion")
    if dir_col:
        df["Direccion"] = df[dir_col].astype(str).str.strip().str.upper()
    else:
        df["Direccion"] = "TODOS"

    # Tipo (INTERNACIONAL/NACIONAL)
    tipo_col = _detect_col(norm_names, "tipo")
    if tipo_col:
        df["Tipo"] = df[tipo_col].astype(str).str.strip().str.upper()
    else:
        df["Tipo"] = "TODOS"

    # Columnas opcionales
    operador_col = _detect_col(norm_names, "operador")
    if operador_col:
        df["Operador"] = df[operador_col].astype(str).str.strip().str.upper()

    orig_col = _detect_col(norm_names, "origen")
    if orig_col:
        df["Origen"] = df[orig_col].astype(str).str.strip().str.upper()

    dest_col = _detect_col(norm_names, "destino")
    if dest_col:
        df["Destino"] = df[dest_col].astype(str).str.strip().str.upper()

    pais_col = _detect_col(norm_names, "pais_origen")
    if pais_col:
        df["PaisOrigen"] = df[pais_col].astype(str).str.strip().str.upper()

    # Filtrar filas válidas
    df = df[df["Fecha"].notna()]

    # Seleccionar columnas estándar
    std_cols = ["Fecha", "Mes", "Direccion", "Tipo"]
    if "Pasajeros" in df.columns:
        std_cols.append("Pasajeros")
    for opt in ["Operador", "Origen", "Destino", "PaisOrigen"]:
        if opt in df.columns:
            std_cols.append(opt)

    return df[std_cols].reset_index(drop=True)


def extraer_trafico(url: str, out_dir: Path, timeout: int = 30, session: requests.Session | None = None) -> Path:
    """
    Descarga el Google Sheet como CSV, normaliza su estructura y lo guarda en out_dir.
    Retorna la ruta del archivo generado.
    """
    sess = session or get_http_session(timeout)
    out_dir.mkdir(parents=True, exist_ok=True)

    export_url = _build_export_url(url)
    logger.info("Descargando trafico aereo desde Google Sheets...")
    r = sess.get(export_url, timeout=timeout)
    r.raise_for_status()

    # Guardar CSV crudo temporalmente
    ruta_raw = out_dir / "trafico_aereo_raw.csv"
    ruta_raw.write_bytes(r.content)

    # Normalizar estructura
    try:
        df = _normalize_trafico_csv(ruta_raw)
        if df.empty:
            logger.warning("No se pudieron normalizar los datos de trafico")
            # Guardar tal cual como fallback
            ruta = out_dir / "trafico_aereo.csv"
            ruta.write_bytes(r.content)
            return ruta
    except Exception as e:
        logger.warning("Error normalizando trafico, guardando CSV crudo: %s", e)
        ruta = out_dir / "trafico_aereo.csv"
        ruta.write_bytes(r.content)
        return ruta

    ruta = out_dir / "trafico_aereo.csv"
    df.to_csv(ruta, index=False, encoding="utf-8")
    logger.info("Trafico aereo normalizado: %s (%d filas, %d columnas)", ruta, len(df), len(df.columns))

    return ruta
