"""Servicio de indicadores tributarios Chile (UF, UTM, UTA) vía mindicador.cl con caché en memoria."""

import logging
import time
from datetime import datetime, timezone
from typing import Any

import httpx

from app.config import UF as UF_DEFAULT, UTM as UTM_DEFAULT, UTA as UTA_DEFAULT

logger = logging.getLogger(__name__)

BASE_URL = "https://mindicador.cl/api"
TTL_SECONDS = 24 * 60 * 60  # 24 horas

_cache: dict[str, Any] = {}
_cache_updated_at: float = 0.0
_cache_updated_at_iso: str | None = None  # Fecha/hora UTC ISO para respuestas API


def _parse_valor(data: dict) -> int | None:
    """Extrae valor numérico de la respuesta de mindicador (valor en root o en serie[0])."""
    if "valor" in data and data["valor"] is not None:
        try:
            return int(round(float(data["valor"])))
        except (TypeError, ValueError):
            pass
    serie = data.get("serie") or []
    if serie and isinstance(serie, list) and len(serie) > 0:
        first = serie[0]
        if isinstance(first, dict) and "valor" in first:
            try:
                return int(round(float(first["valor"])))
            except (TypeError, ValueError):
                pass
    return None


def _fetch_indicador(client: httpx.Client, codigo: str) -> int | None:
    """Obtiene un indicador desde mindicador.cl. Retorna valor en pesos o None."""
    try:
        r = client.get(f"{BASE_URL}/{codigo}", timeout=10.0)
        r.raise_for_status()
        data = r.json()
        return _parse_valor(data)
    except (httpx.HTTPError, ValueError) as e:
        logger.warning("mindicador.cl %s: %s", codigo, e)
        return None


def _is_cache_valid() -> bool:
    return bool(_cache) and (time.monotonic() - _cache_updated_at) < TTL_SECONDS


def is_indicadores_cache_valid() -> bool:
    """Indica si la caché de UF/UTM/UTA está cargada y dentro del TTL (para readiness)."""
    return _is_cache_valid()


def refresh_indicadores() -> dict[str, Any]:
    """Consulta mindicador.cl y actualiza la caché en memoria. UTA = UTM * 12."""
    global _cache, _cache_updated_at, _cache_updated_at_iso
    with httpx.Client() as client:
        uf = _fetch_indicador(client, "uf")
        utm = _fetch_indicador(client, "utm")
    uf = uf if uf is not None else UF_DEFAULT
    utm = utm if utm is not None else UTM_DEFAULT
    uta = utm * 12
    _cache_updated_at_iso = datetime.now(timezone.utc).isoformat()
    _cache = {"uf": uf, "utm": utm, "uta": uta, "indicadores_actualizado_en": _cache_updated_at_iso}
    _cache_updated_at = time.monotonic()
    logger.info("Indicadores actualizados: UF=%s, UTM=%s, UTA=%s", uf, utm, uta)
    return _cache


def get_indicadores() -> dict[str, Any]:
    """Devuelve UF, UTM, UTA y opcionalmente indicadores_actualizado_en (ISO UTC)."""
    if _is_cache_valid():
        return _cache.copy()
    try:
        return refresh_indicadores().copy()
    except Exception as e:
        logger.warning("Error al actualizar indicadores, usando defaults: %s", e)
        return {
            "uf": UF_DEFAULT,
            "utm": UTM_DEFAULT,
            "uta": UTA_DEFAULT,
            "indicadores_actualizado_en": None,
        }
