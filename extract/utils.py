"""Utilidades compartidas para la capa Extract."""

import io
import logging
import re
import unicodedata

import pandas as pd
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

logger = logging.getLogger(__name__)

HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; TurismoPipeline/2.0)"}


def get_http_session(timeout: int = 15) -> requests.Session:
    """Crea una sesion HTTP con reintentos y backoff exponencial."""
    retry = Retry(
        total=3,
        connect=3,
        read=3,
        backoff_factor=0.6,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=("HEAD", "GET", "OPTIONS"),
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retry)
    sess = requests.Session()
    sess.headers.update(HEADERS)
    sess.mount("http://", adapter)
    sess.mount("https://", adapter)
    return sess


def descargar_excel(url: str, session: requests.Session | None = None, timeout: int = 15) -> io.BytesIO:
    """Descarga un Excel desde URL y retorna BytesIO."""
    sess = session or get_http_session(timeout)
    logger.info("Descargando: %s", url)
    r = sess.get(url, timeout=timeout, stream=True)
    r.raise_for_status()
    return io.BytesIO(r.content)


def strip_accents_lower(s: str) -> str:
    """Elimina tildes, normaliza espacios y pasa a minusculas."""
    if not isinstance(s, str):
        s = str(s)
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"\s+", " ", s)
    return s.strip().lower()


MESES_MAP = {
    # Español
    "enero": 1,
    "ene": 1,
    "febrero": 2,
    "feb": 2,
    "marzo": 3,
    "mar": 3,
    "abril": 4,
    "abr": 4,
    "mayo": 5,
    "may": 5,
    "junio": 6,
    "jun": 6,
    "julio": 7,
    "jul": 7,
    "agosto": 8,
    "ago": 8,
    "septiembre": 9,
    "setiembre": 9,
    "sep": 9,
    "set": 9,
    "octubre": 10,
    "oct": 10,
    "noviembre": 11,
    "nov": 11,
    "diciembre": 12,
    "dic": 12,
    # Inglés
    "january": 1,
    "jan": 1,
    "february": 2,
    "march": 3,
    "april": 4,
    "apr": 4,
    "june": 6,
    "july": 7,
    "august": 8,
    "aug": 8,
    "sept": 9,
    "september": 9,
    "october": 10,
    "november": 11,
    "december": 12,
    "dec": 12,
}


_PAT_EU = re.compile(r"^\d{1,3}(\.\d{3})+(,\d+)?$")
_PAT_US = re.compile(r"^\d{1,3}(,\d{3})+(\.\d+)?$")


def normalize_numeric(s: str) -> str:
    """Normaliza un string numérico con formato EU (12.345,67) o US (12,345.67) a formato plano."""
    s = s.strip()
    if _PAT_EU.match(s):
        return s.replace(".", "").replace(",", ".")
    if _PAT_US.match(s):
        return s.replace(",", "")
    return s


def normalize_numeric_series(s: pd.Series) -> pd.Series:
    """Normaliza una Serie de strings numéricos EU/US y convierte a float."""
    s = s.astype(str).str.strip()
    m_eu = s.str.match(r"^\d{1,3}(\.\d{3})+(,\d+)?$")
    m_us = s.str.match(r"^\d{1,3}(,\d{3})+(\.\d+)?$")
    s = s.copy()
    s.loc[m_eu] = s.loc[m_eu].str.replace(".", "", regex=False).str.replace(",", ".", regex=False)
    s.loc[m_us] = s.loc[m_us].str.replace(",", "", regex=False)
    return pd.to_numeric(s, errors="coerce")


def match_sheet_name(available: list, target=None, heuristic_keywords=None):
    """Match flexible de hoja Excel por índice, nombre exacto o heurística de keywords.

    Args:
        available: Lista de nombres de hojas disponibles.
        target: Índice (int), nombre (str) o None para heurística.
        heuristic_keywords: Lista de keywords para buscar si target es None.
            Defaults: ["datos", "serie", "hoja1"].
    """
    if isinstance(target, int):
        if 0 <= target < len(available):
            return target
        raise ValueError(f"Indice de hoja fuera de rango: {target}.")
    if isinstance(target, str):
        tgt = strip_accents_lower(target)
        norm = {nm: strip_accents_lower(nm) for nm in available}
        for nm, nv in norm.items():
            if nv == tgt:
                return nm
        for nm, nv in norm.items():
            if tgt in nv:
                return nm
        raise ValueError(f"No se encontro la hoja '{target}'. Hojas: {available}")
    # Heurística por keywords
    keywords = heuristic_keywords or ["datos", "serie", "hoja1"]
    norm = {nm: strip_accents_lower(nm) for nm in available}
    for cand in keywords:
        for nm, nv in norm.items():
            if cand in nv:
                return nm
    return available[0]


def parse_mes_a_num(x) -> int | None:
    """Convierte nombre o numero de mes a int (1-12)."""
    if pd.isna(x):
        return None
    try:
        n = int(str(x).strip())
        if 1 <= n <= 12:
            return n
    except Exception:
        pass
    return MESES_MAP.get(strip_accents_lower(x))
