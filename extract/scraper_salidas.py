"""
Scraper de salidas de residentes chilenos (turismo emisivo).
Descarga el Excel desde la URL configurada y genera CSVs por codigo YYYYMM.

Basado en la logica de parseo de archive/Turismo Emisivo/2. Scrap.py
"""

import logging
import os
import re
from pathlib import Path

import pandas as pd
import requests

from .utils import (
    descargar_excel,
    get_http_session,
    match_sheet_name,
    normalize_numeric_series,
    parse_mes_a_num,
    strip_accents_lower,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Funciones de parseo (preservadas del codigo original)
# ---------------------------------------------------------------------------


def _extraer_codigo_yymm_desde_url(url: str) -> str:
    nombre = os.path.basename(url)
    m = re.search(r"\d{6}", nombre)
    return m.group(0) if m else "SINFECHA"


_SALIDAS_SHEET_KEYWORDS = [
    "salidos por motivos turisticos",
    "salidas por motivos turisticos",
    "series",
    "serie",
    "datos",
    "hoja1",
]


def _clean_excel_wide_to_long(df_raw: pd.DataFrame) -> pd.DataFrame:
    """Detecta encabezados y columna Mes por contenido. Retorna [Mes,Ano,Cantidad,Fecha]."""
    if df_raw is None or df_raw.empty:
        return pd.DataFrame(columns=["Mes", "Ano", "Cantidad", "Fecha"])

    df = df_raw.copy()
    df.dropna(how="all", inplace=True)
    df.dropna(axis=1, how="all", inplace=True)
    if df.empty:
        return pd.DataFrame(columns=["Mes", "Ano", "Cantidad", "Fecha"])

    # Recortar si aparece columna "Variacion"
    corte_col = None
    for _, row in df.iterrows():
        hits = [j for j, v in enumerate(row) if isinstance(v, str) and "variacion" in strip_accents_lower(v)]
        if hits:
            corte_col = hits[0]
            break
    if corte_col is not None and corte_col > 0:
        df = df.iloc[:, :corte_col]

    # Fila de encabezado: aquella con >=2 "anos" (XXXX)
    def _count_years(vals) -> int:
        c = 0
        for x in vals:
            xs = strip_accents_lower(str(x))
            if re.fullmatch(r"\d{4}", xs) or xs.startswith("ano"):
                c += 1
        return c

    header_idx = None
    for i in range(min(8, len(df))):
        if _count_years(df.iloc[i].tolist()) >= 2:
            header_idx = i
            break
    if header_idx is None:
        header_idx = 1 if len(df) > 1 else 0

    df.columns = df.iloc[header_idx].astype(str).tolist()
    df = df.iloc[header_idx + 1 :].reset_index(drop=True)
    df.dropna(how="all", inplace=True)
    df.dropna(axis=1, how="all", inplace=True)
    if df.empty:
        return pd.DataFrame(columns=["Mes", "Ano", "Cantidad", "Fecha"])

    # Detectar columna de meses por contenido
    score = []
    for c in df.columns:
        vals = df[c].dropna().astype(str).head(24)
        ok = sum(parse_mes_a_num(v) is not None for v in vals)
        score.append((ok, c))
    score.sort(reverse=True)
    cand_mes = score[0][1] if score and score[0][0] >= 4 else df.columns[0]
    df.rename(columns={cand_mes: "Mes"}, inplace=True)

    # Eliminar totales
    mask_total = df["Mes"].astype(str).map(strip_accents_lower).isin({"total", "totales", "subtotal", "acumulado"})
    df = df[~mask_total]

    # Columnas ano
    col_years = []
    for c in df.columns:
        if c == "Mes":
            continue
        cn = strip_accents_lower(c)
        if cn.startswith("ano") or re.fullmatch(r"\d{4}", cn):
            col_years.append(c)
    if not col_years:
        col_years = [c for c in df.columns if c != "Mes"]
    if not col_years:
        return pd.DataFrame(columns=["Mes", "Ano", "Cantidad", "Fecha"])

    # Ancho -> largo
    df_long = df.melt(id_vars=["Mes"], value_vars=col_years, var_name="Ano", value_name="Cantidad")

    # Normalizaciones
    df_long["Ano"] = (
        df_long["Ano"].astype(str).str.replace("Año", "", case=False, regex=False).str.replace(" ", "", regex=False)
    )
    df_long["Ano"] = pd.to_numeric(df_long["Ano"], errors="coerce").astype("Int64")

    df_long["Cantidad"] = normalize_numeric_series(df_long["Cantidad"])

    df_long["Mes_num"] = df_long["Mes"].map(parse_mes_a_num)
    df_long = df_long.dropna(subset=["Ano", "Mes_num", "Cantidad"])
    if df_long.empty:
        return pd.DataFrame(columns=["Mes", "Ano", "Cantidad", "Fecha"])

    df_long["Ano"] = df_long["Ano"].astype(int)
    df_long["Mes_num"] = df_long["Mes_num"].astype(int)
    df_long["Fecha"] = pd.to_datetime({"year": df_long["Ano"], "month": df_long["Mes_num"], "day": 1})
    df_long = df_long.drop(columns=["Mes_num"]).sort_values("Fecha").reset_index(drop=True)
    return df_long[["Mes", "Ano", "Cantidad", "Fecha"]]


def _normalize_fecha_inicio_de_mes(s: pd.Series) -> pd.Series:
    """Normaliza Serie heterogenea al primer dia del mes."""
    ss = s.astype(str).str.strip()
    parsed = pd.Series(pd.NaT, index=ss.index, dtype="datetime64[ns]")
    formatos = [
        ("%Y-%m-%d", None),
        ("%d/%m/%Y", None),
        ("%m/%d/%Y", None),
        ("%Y-%m", "-01"),
        ("%Y/%m", "/01"),
        ("%m-%Y", "-01"),
        ("%m/%Y", "/01"),
        ("%Y%m", "01"),
        ("%Y%m%d", None),
    ]
    resto = parsed.isna()
    for fmt, suf in formatos:
        if not resto.any():
            break
        tmp = ss[resto] + (suf or "")
        dt = pd.to_datetime(tmp, format=fmt, errors="coerce")
        parsed.loc[resto] = dt.combine_first(parsed.loc[resto])
        resto = parsed.isna()
    if resto.any():
        dt = pd.to_datetime(ss[resto], dayfirst=True, errors="coerce")
        parsed.loc[resto] = dt
    return parsed.dt.to_period("M").dt.to_timestamp()


def _clean_csv_like(df_raw: pd.DataFrame) -> pd.DataFrame:
    """Para data ya larga con [Fecha,Cantidad]."""
    if df_raw is None or df_raw.empty:
        return pd.DataFrame(columns=["Fecha", "Variable", "Cantidad"])
    if not {"Fecha", "Cantidad"}.issubset(df_raw.columns.astype(str)):
        raise ValueError("Se requieren columnas 'Fecha' y 'Cantidad'.")
    df = df_raw.copy()
    df["Fecha"] = _normalize_fecha_inicio_de_mes(df["Fecha"])
    df["Cantidad"] = normalize_numeric_series(df["Cantidad"])
    return df.dropna(subset=["Fecha", "Cantidad"])


def clean_excel_wide_or_long(df_raw: pd.DataFrame) -> pd.DataFrame:
    """Router: detecta si es formato largo o ancho y limpia."""
    cols_norm = {strip_accents_lower(c): c for c in df_raw.columns.astype(str)}
    if "fecha" in cols_norm and "cantidad" in cols_norm:
        tmp = df_raw.rename(columns={cols_norm["fecha"]: "Fecha", cols_norm["cantidad"]: "Cantidad"})
        df = _clean_csv_like(tmp)
        if "Variable" not in df.columns:
            df["Variable"] = "Dato"
        return df[["Fecha", "Variable", "Cantidad"]]

    dfw = _clean_excel_wide_to_long(df_raw)
    if dfw.empty:
        logger.warning("Todas las filas quedaron con Fecha NaT.")
        return pd.DataFrame(columns=["Fecha", "Variable", "Cantidad"])

    dfw["Variable"] = "Salidas por motivos turísticos"
    return dfw[["Fecha", "Variable", "Cantidad"]]


# ---------------------------------------------------------------------------
# API publica
# ---------------------------------------------------------------------------


def extraer_salidas(url: str, out_dir: Path, timeout: int = 15, session: requests.Session | None = None) -> list[Path]:
    """
    Descarga el Excel de salidas, parsea y exporta CSVs por codigo YYYYMM.
    Retorna lista de archivos generados.
    """
    sess = session or get_http_session(timeout)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Descargar y leer Excel
    buf = descargar_excel(url, session=sess, timeout=timeout)
    xls = pd.ExcelFile(buf, engine="openpyxl")
    hoja = match_sheet_name(
        xls.sheet_names, "Salidos por Motivos Turísticos", heuristic_keywords=_SALIDAS_SHEET_KEYWORDS
    )
    buf.seek(0)
    df_raw = pd.read_excel(buf, sheet_name=hoja, header=None, engine="openpyxl")
    logger.info("Excel cargado: %d filas x %d cols (hoja: %s)", df_raw.shape[0], df_raw.shape[1], hoja)

    # Limpiar
    df_largo = clean_excel_wide_or_long(df_raw)
    if df_largo.empty:
        logger.warning("No se obtuvieron datos válidos del Excel de salidas.")
        return []

    codigo = _extraer_codigo_yymm_desde_url(url)
    df_largo["Codigo"] = codigo

    # Limpiar CSVs anteriores
    old_files = list(out_dir.glob("real_*.csv"))
    for f in old_files:
        f.unlink()
    if old_files:
        logger.info("Limpiados %d archivos anteriores en %s", len(old_files), out_dir)

    # Exportar un CSV por cada codigo (en este caso sera uno solo)
    generados: list[Path] = []
    for cod, df_mes in df_largo.groupby("Codigo"):
        ruta = out_dir / f"real_{cod}.csv"
        df_export = df_mes[["Fecha", "Cantidad"]].copy()
        df_export["Cantidad"] = df_export["Cantidad"].round(0).astype(int)
        df_export.to_csv(ruta, index=False, encoding="utf-8")
        logger.info("CSV exportado: %s (%d filas)", ruta, len(df_mes))
        generados.append(ruta)

    return generados
