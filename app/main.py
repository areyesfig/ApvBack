"""FastAPI app - Motor de Reglas Fiscales APV Chile."""

import asyncio
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.routes import router
from app.limiter import limiter
from app.services.indicadores import refresh_indicadores, get_indicadores, is_indicadores_cache_valid

logger = logging.getLogger(__name__)

# Entorno: en producción exige CORS_ORIGINS explícito (no "*").
ENV = os.environ.get("ENV", "development").lower()


# Refresco programado de indicadores (cada 6 horas)
INDICADORES_REFRESH_INTERVAL = int(os.environ.get("APV_INDICADORES_REFRESH_SECONDS", 6 * 3600))


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Carga inicial de UF/UTM/UTA y tarea en background para actualizarlos periódicamente."""
    try:
        refresh_indicadores()
    except Exception as e:
        logger.warning("Indicadores no actualizados al inicio (se usarán valores por defecto): %s", e)

    async def _refresh_loop():
        loop = asyncio.get_event_loop()
        while True:
            await asyncio.sleep(INDICADORES_REFRESH_INTERVAL)
            try:
                await loop.run_in_executor(None, refresh_indicadores)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.warning("Error al refrescar indicadores en background: %s", e)

    task = asyncio.create_task(_refresh_loop())
    try:
        yield
    finally:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title="Motor de Reglas Fiscales APV Chile",
    description="Calcula ahorro tributario APV Régimen B según normativa SII Chile",
    version="1.0.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# CORS: en producción no permitir "*"; exige CORS_ORIGINS explícito.
cors_origins = os.environ.get("CORS_ORIGINS", "*").strip()
if ENV == "production" and (not cors_origins or cors_origins == "*"):
    logger.critical(
        "Producción: CORS_ORIGINS no puede ser '*'. Defina orígenes concretos (ej. https://app.tudominio.com)."
    )
    allow_origins = []
else:
    allow_origins = [o.strip() for o in cors_origins.split(",")] if cors_origins != "*" else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)


@app.get("/health")
@limiter.exempt
def health(_request: Request):
    """Liveness: la aplicación está en ejecución."""
    return {"status": "ok"}


@app.get("/ready")
@limiter.exempt
def ready(_request: Request):
    """Readiness: listo para recibir tráfico (indicadores cargados o con fallback)."""
    try:
        ind = get_indicadores()
        cache_ok = is_indicadores_cache_valid()
        return {
            "status": "ok",
            "indicadores": {"uf": ind["uf"], "utm": ind["utm"], "uta": ind["uta"]},
            "cache_indicadores": cache_ok,
        }
    except Exception as e:
        logger.exception("Ready check failed: %s", e)
        return JSONResponse(
            content={"status": "degraded", "detail": str(e)},
            status_code=503,
        )
