"""FastAPI app - Motor de Reglas Fiscales APV Chile."""

import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.services.indicadores import refresh_indicadores

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Carga inicial de UF/UTM/UTA desde mindicador.cl (caché en memoria)."""
    try:
        refresh_indicadores()
    except Exception as e:
        logger.warning("Indicadores no actualizados al inicio (se usarán valores por defecto): %s", e)
    yield


app = FastAPI(
    title="Motor de Reglas Fiscales APV Chile",
    description="Calcula ahorro tributario APV Régimen B según normativa SII Chile",
    version="1.0.0",
    lifespan=lifespan,
)

# En producción definir CORS_ORIGINS con orígenes concretos (ej. https://app.tudominio.com).
# No usar "*" con allow_credentials=True en entornos sensibles.
cors_origins = os.environ.get("CORS_ORIGINS", "*")
allow_origins = [o.strip() for o in cors_origins.split(",")] if cors_origins != "*" else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)
