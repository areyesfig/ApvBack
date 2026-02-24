"""Recomendación de régimen APV y aporte sugerido según sueldo y edad."""

from app.services.calculadora_apv import simular_regimenes
from app.services.indicadores import get_indicadores
from app.config import LIMITE_APV_UF


def generar_recomendacion(
    sueldo_bruto_mensual: float,
    edad_actual: int,
    edad_jubilacion: int,
    ahorro_mensual_apv: float = 0,
) -> dict:
    """Genera recomendación de régimen APV y aporte sugerido.

    Si ahorro_mensual_apv > 0 se evalúa ese aporte; si no, se sugiere 10% del sueldo
    bruto mensual (con tope 600 UF anuales).

    Returns:
        Dict con mejor_regimen, tope_apv_pesos, aporte_sugerido_mensual,
        beneficio_anual_estimado, mensaje.
    """
    ind = get_indicadores()
    tope_apv_pesos = LIMITE_APV_UF * ind["uf"]
    tope_mensual = tope_apv_pesos / 12

    # Sugerencia: 10% del sueldo bruto mensual, cap al tope anual
    sugerido = min(sueldo_bruto_mensual * 0.10, tope_mensual)
    if sugerido < 0:
        sugerido = 0

    aporte_a_evaluar = ahorro_mensual_apv if ahorro_mensual_apv > 0 else sugerido
    if aporte_a_evaluar <= 0:
        resultado = simular_regimenes(sueldo_bruto_mensual, 1)  # 1 peso para tener estructura
        mejor = resultado["mejor_regimen"]
        beneficio = 0.0
        mensaje = (
            f"Con tu sueldo bruto, el tope APV es ${tope_apv_pesos:,.0f} al año (600 UF). "
            f"Recomendamos {mejor}. Aportar aunque sea un monto bajo te da beneficio tributario."
        )
        return {
            "mejor_regimen": mejor,
            "tope_apv_pesos": tope_apv_pesos,
            "aporte_sugerido_mensual": round(sugerido),
            "beneficio_anual_estimado": beneficio,
            "mensaje": mensaje,
        }

    resultado = simular_regimenes(sueldo_bruto_mensual, aporte_a_evaluar)
    mejor = resultado["mejor_regimen"]
    if mejor == "Régimen A":
        beneficio = resultado["regimen_a"]["bonificacion_efectiva"]
    elif mejor == "Régimen B":
        beneficio = resultado["regimen_b"]["ahorro_fiscal"]
    else:
        beneficio = resultado["mix"]["beneficio_total"]

    if ahorro_mensual_apv > 0:
        mensaje = (
            f"Aportando ${aporte_a_evaluar:,.0f}/mes, tu mejor opción es {mejor}. "
            f"Beneficio tributario estimado: ${beneficio:,.0f} al año. "
            f"Tope APV: ${tope_apv_pesos:,.0f}/año (600 UF)."
        )
    else:
        mensaje = (
            f"Te sugerimos aportar ${aporte_a_evaluar:,.0f}/mes (≈10% de tu sueldo, dentro del tope). "
            f"Con eso, {mejor} te daría un beneficio de ${beneficio:,.0f} al año. "
            f"Tope APV: ${tope_apv_pesos:,.0f}/año (600 UF)."
        )

    return {
        "mejor_regimen": mejor,
        "tope_apv_pesos": tope_apv_pesos,
        "aporte_sugerido_mensual": round(sugerido),
        "beneficio_anual_estimado": round(beneficio),
        "mensaje": mensaje,
    }
