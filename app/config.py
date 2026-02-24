"""Parámetros tributarios Chile - Año Tributario 2026 (rentas 2025)."""

import os

# Unidad Tributaria Mensual (UTM) en pesos chilenos
UTM = int(os.environ.get("APV_UTM", 66_362))

# Unidad Tributaria Anual (UTA) = UTM * 12
UTA = int(os.environ.get("APV_UTA", UTM * 12))

# Unidad de Fomento (UF) valor referencial
UF = int(os.environ.get("APV_UF", 38_500))

# Límite APV Régimen B: 600 UF anuales
LIMITE_APV_UF = 600
LIMITE_APV_PESOS = LIMITE_APV_UF * UF

# Límite beneficio Régimen A: 6 UTM (bonificación 15% con tope)
LIMITE_REGIMEN_A_UTM = 6
TOPE_BONIFICACION_A = LIMITE_REGIMEN_A_UTM * UTM

# Tasa de bonificación Régimen A
TASA_BONIFICACION_A = 0.15

# Tasa aproximada de cotizaciones previsionales obligatorias
# AFP ~12.5% + Salud 7% + Seguro cesantía 0.6%
TASA_COTIZACIONES = float(os.environ.get("APV_TASA_COTIZACIONES", 0.205))

# Impuesto ganancia de capital LIR 107 (inversión normal ETF)
TASA_IMPUESTO_LIR107 = 0.10

ANO_TRIBUTARIO = int(os.environ.get("APV_ANO_TRIBUTARIO", 2026))
