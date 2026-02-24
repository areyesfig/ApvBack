"""FastAPI app - Motor de Reglas Fiscales APV Chile."""

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router

app = FastAPI(
    title="Motor de Reglas Fiscales APV Chile",
    description="Calcula ahorro tributario APV Régimen B según normativa SII Chile",
    version="1.0.0",
)

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
