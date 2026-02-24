"""Calculadora de ahorro tributario APV - Régimen A, B y Mix optimizado."""

from abc import ABC, abstractmethod

from app.config import (
    TASA_COTIZACIONES,
    LIMITE_APV_PESOS,
    TASA_BONIFICACION_A,
    TOPE_BONIFICACION_A,
    UTM,
)
from app.services.tabla_igc import CalculadoraIGC, aplicar


class EstrategiaAPV(ABC):
    @abstractmethod
    def calcular(self, base_imponible: float, ahorro_apv_anual: float, calculadora: CalculadoraIGC) -> dict:
        pass


class EstrategiaRegimenA(EstrategiaAPV):
    """Régimen A: Bonificación estatal del 15% sobre el ahorro APV, con tope de 6 UTM."""

    def calcular(self, base_imponible: float, ahorro_apv_anual: float, calculadora: CalculadoraIGC) -> dict:
        bonificacion_bruta = ahorro_apv_anual * TASA_BONIFICACION_A
        bonificacion_efectiva = min(bonificacion_bruta, TOPE_BONIFICACION_A)

        return {
            "ahorro_apv_anual": round(ahorro_apv_anual),
            "bonificacion_estatal": round(bonificacion_bruta),
            "tope_bonificacion": round(TOPE_BONIFICACION_A),
            "bonificacion_efectiva": round(bonificacion_efectiva),
        }


class EstrategiaRegimenB(EstrategiaAPV):
    """Régimen B: El aporte APV se descuenta de la base imponible del IGC."""

    def calcular(self, base_imponible: float, ahorro_apv_anual: float, calculadora: CalculadoraIGC) -> dict:
        aporte_efectivo = min(ahorro_apv_anual, LIMITE_APV_PESOS)
        base_con_apv = max(0, base_imponible - aporte_efectivo)

        impuesto_sin, tasa_marginal = calculadora.calcular_impuesto(base_imponible)
        impuesto_con, _ = calculadora.calcular_impuesto(base_con_apv)
        ahorro_fiscal = impuesto_sin - impuesto_con

        return {
            "ahorro_apv_anual": round(ahorro_apv_anual),
            "aporte_apv_efectivo": round(aporte_efectivo),
            "tope_apv_anual": LIMITE_APV_PESOS,
            "base_imponible_sin_apv": round(base_imponible),
            "base_imponible_con_apv": round(base_con_apv),
            "impuesto_sin_apv": round(impuesto_sin),
            "impuesto_con_apv": round(impuesto_con),
            "ahorro_fiscal": round(ahorro_fiscal),
            "tasa_marginal": tasa_marginal,
        }


class EstrategiaOptimizada(EstrategiaAPV):
    """Mix optimizado: distribuye el ahorro entre Régimen A y B para maximizar beneficio."""

    def calcular(self, base_imponible: float, ahorro_apv_anual: float, calculadora: CalculadoraIGC) -> dict:
        _, tasa_marginal = calculadora.calcular_impuesto(base_imponible)

        max_util_a = TOPE_BONIFICACION_A / TASA_BONIFICACION_A
        tope_b = LIMITE_APV_PESOS
        estrategia_a = EstrategiaRegimenA()
        estrategia_b = EstrategiaRegimenB()

        def _evaluar(ma: float, mb: float) -> float:
            ra = estrategia_a.calcular(base_imponible, ma, calculadora)
            rb = estrategia_b.calcular(base_imponible, mb, calculadora)
            return ra["bonificacion_efectiva"] + rb["ahorro_fiscal"]

        # Escenario 1: Todo a A
        s1_a = min(ahorro_apv_anual, max_util_a)
        s1_b = min(ahorro_apv_anual - s1_a, tope_b)
        b1 = _evaluar(s1_a, s1_b)

        # Escenario 2: Todo a B, resto a A
        s2_b = min(ahorro_apv_anual, tope_b)
        s2_a = min(ahorro_apv_anual - s2_b, max_util_a)
        b2 = _evaluar(s2_a, s2_b)

        # Escenario 3: Solo A
        s3_a = min(ahorro_apv_anual, max_util_a)
        b3 = _evaluar(s3_a, 0)

        # Escenario 4: Solo B
        s4_b = min(ahorro_apv_anual, tope_b)
        b4 = _evaluar(0, s4_b)

        escenarios = [
            (s1_a, s1_b, b1, "Se prioriza Régimen A hasta tope, resto a Régimen B"),
            (s2_a, s2_b, b2, "Se prioriza Régimen B hasta tope, resto a Régimen A"),
            (s3_a, 0, b3, "Todo a Régimen A (bonificación directa es más conveniente)"),
            (0, s4_b, b4, "Todo a Régimen B (rebaja tributaria es más conveniente)"),
        ]

        mejor = max(escenarios, key=lambda x: x[2])
        monto_a, monto_b, _, explicacion = mejor

        resultado_a = estrategia_a.calcular(base_imponible, monto_a, calculadora)
        resultado_b = estrategia_b.calcular(base_imponible, monto_b, calculadora)
        beneficio_a = resultado_a["bonificacion_efectiva"]
        beneficio_b = resultado_b["ahorro_fiscal"]

        return {
            "monto_regimen_a": round(monto_a),
            "monto_regimen_b": round(monto_b),
            "beneficio_regimen_a": round(beneficio_a),
            "beneficio_regimen_b": round(beneficio_b),
            "beneficio_total": round(beneficio_a + beneficio_b),
            "explicacion": explicacion,
        }


def simular_regimenes(sueldo_bruto_mensual: float, ahorro_apv_mensual: float) -> dict:
    """Ejecuta las 3 estrategias y retorna comparación completa.

    Args:
        sueldo_bruto_mensual: Sueldo bruto mensual en pesos.
        ahorro_apv_mensual: Aporte APV mensual en pesos.

    Returns:
        Diccionario con resultados de Régimen A, B, Mix y mejor régimen.
    """
    calculadora = CalculadoraIGC()
    sueldo_anual = sueldo_bruto_mensual * 12
    base_imponible = calculadora.calcular_base_imponible(sueldo_anual)
    ahorro_anual = ahorro_apv_mensual * 12

    resultado_a = EstrategiaRegimenA().calcular(base_imponible, ahorro_anual, calculadora)
    resultado_b = EstrategiaRegimenB().calcular(base_imponible, ahorro_anual, calculadora)
    resultado_mix = EstrategiaOptimizada().calcular(base_imponible, ahorro_anual, calculadora)

    beneficio_a = resultado_a["bonificacion_efectiva"]
    beneficio_b = resultado_b["ahorro_fiscal"]
    beneficio_mix = resultado_mix["beneficio_total"]

    mejor = max(
        [("Régimen A", beneficio_a), ("Régimen B", beneficio_b), ("Mix", beneficio_mix)],
        key=lambda x: x[1],
    )

    return {
        "regimen_a": resultado_a,
        "regimen_b": resultado_b,
        "mix": resultado_mix,
        "mejor_regimen": mejor[0],
    }


# --- Wrapper de retrocompatibilidad ---

def calcular_ahorro_regimen_b(sueldo_bruto_mensual: float, aporte_apv_mensual: float) -> dict:
    """Calcula el ahorro fiscal anual por APV Régimen B (retrocompatible)."""
    calculadora = CalculadoraIGC()
    sueldo_anual = sueldo_bruto_mensual * 12
    base_imponible = calculadora.calcular_base_imponible(sueldo_anual)
    ahorro_anual = aporte_apv_mensual * 12

    resultado = EstrategiaRegimenB().calcular(base_imponible, ahorro_anual, calculadora)

    return {
        "ahorro_fiscal_anual": resultado["ahorro_fiscal"],
        "impuesto_sin_apv": resultado["impuesto_sin_apv"],
        "impuesto_con_apv": resultado["impuesto_con_apv"],
        "base_imponible_pre": resultado["base_imponible_sin_apv"],
        "base_imponible_post": resultado["base_imponible_con_apv"],
        "tasa_marginal": resultado["tasa_marginal"],
        "aporte_apv_anual_efectivo": resultado["aporte_apv_efectivo"],
        "tope_apv_anual": resultado["tope_apv_anual"],
    }
