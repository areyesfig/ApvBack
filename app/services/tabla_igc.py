"""Tabla Impuesto Global Complementario (IGC) - Año Tributario 2026.

Tramos expresados en UTA. Cada tramo define:
- desde: límite inferior en UTA
- hasta: límite superior en UTA
- tasa: tasa marginal del tramo
- rebaja: cantidad a rebajar en UTA
"""

from app.config import UTA, TASA_COTIZACIONES

# Tramos IGC AT2026 (rentas 2025)
# Fuente: SII Chile
TRAMOS_IGC = [
    {"desde": 0.0,    "hasta": 13.5,   "tasa": 0.00,  "rebaja": 0.0},
    {"desde": 13.5,   "hasta": 30.0,   "tasa": 0.04,  "rebaja": 0.54},
    {"desde": 30.0,   "hasta": 50.0,   "tasa": 0.08,  "rebaja": 1.74},
    {"desde": 50.0,   "hasta": 70.0,   "tasa": 0.135, "rebaja": 4.49},
    {"desde": 70.0,   "hasta": 90.0,   "tasa": 0.23,  "rebaja": 11.14},
    {"desde": 90.0,   "hasta": 120.0,  "tasa": 0.304, "rebaja": 17.80},
    {"desde": 120.0,  "hasta": 150.0,  "tasa": 0.35,  "rebaja": 23.32},
    {"desde": 150.0,  "hasta": float("inf"), "tasa": 0.40, "rebaja": 30.82},
]


class CalculadoraIGC:
    """Calculadora del Impuesto Global Complementario con tabla inyectable."""

    def __init__(self, tramos: list[dict] | None = None, uta: float | None = None):
        self.tramos = tramos or TRAMOS_IGC
        self.uta = uta or UTA

    def calcular_base_imponible(self, sueldo_bruto_anual: float, tasa_cotizaciones: float | None = None) -> float:
        tasa = tasa_cotizaciones if tasa_cotizaciones is not None else TASA_COTIZACIONES
        cotizaciones = sueldo_bruto_anual * tasa
        return sueldo_bruto_anual - cotizaciones

    def calcular_impuesto(self, base_imponible: float) -> tuple[float, float]:
        renta_uta = base_imponible / self.uta

        for tramo in self.tramos:
            if tramo["desde"] <= renta_uta < tramo["hasta"]:
                tasa_marginal = tramo["tasa"]
                impuesto_uta = renta_uta * tramo["tasa"] - tramo["rebaja"]
                return max(impuesto_uta * self.uta, 0), tasa_marginal

        ultimo = self.tramos[-1]
        tasa_marginal = ultimo["tasa"]
        impuesto_uta = renta_uta * ultimo["tasa"] - ultimo["rebaja"]
        return max(impuesto_uta * self.uta, 0), tasa_marginal


# --- Instancia por defecto ---
_calculadora_default = CalculadoraIGC()


# --- Wrappers de retrocompatibilidad ---

def obtener_tramos() -> list[dict]:
    """Retorna la tabla de tramos IGC."""
    return TRAMOS_IGC


def aplicar(renta_anual: float) -> tuple[float, float]:
    """Calcula el impuesto IGC para una renta anual en pesos.

    Args:
        renta_anual: Renta imponible anual en pesos chilenos.

    Returns:
        Tupla (impuesto_pesos, tasa_marginal).
    """
    return _calculadora_default.calcular_impuesto(renta_anual)
