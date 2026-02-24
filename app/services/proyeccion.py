"""Proyección de interés compuesto para aportes APV e inversión normal."""

import numpy_financial as npf

from app.config import TASA_IMPUESTO_LIR107


def proyectar(
    aporte_mensual: float,
    meses: int,
    tasa_rentabilidad_anual: float,
) -> dict:
    """Genera proyección mes a mes de capital acumulado.

    Args:
        aporte_mensual: Aporte mensual en pesos.
        meses: Cantidad de meses a proyectar.
        tasa_rentabilidad_anual: Tasa de rentabilidad anual (ej: 0.05 = 5%).

    Returns:
        Diccionario con la proyección detallada.
    """
    tasa_mensual = (1 + tasa_rentabilidad_anual) ** (1 / 12) - 1

    registros = []
    for mes in range(1, meses + 1):
        capital_total = -npf.fv(tasa_mensual, mes, aporte_mensual, 0)
        aporte_acumulado = aporte_mensual * mes
        rentabilidad_acumulada = capital_total - aporte_acumulado

        registros.append({
            "mes": mes,
            "aporte_acumulado": round(aporte_acumulado),
            "rentabilidad_acumulada": round(rentabilidad_acumulada),
            "capital_total": round(capital_total),
        })

    ultimo = registros[-1]

    return {
        "proyeccion": registros,
        "capital_final": ultimo["capital_total"],
        "total_aportes": ultimo["aporte_acumulado"],
        "rentabilidad_total": ultimo["rentabilidad_acumulada"],
    }


def proyectar_jubilacion(
    ahorro_mensual: float,
    edad_actual: int,
    edad_jubilacion: int,
    tasa_anual: float,
    es_apv: bool = True,
) -> dict:
    """Proyecta el capital acumulado al momento de jubilación.

    Args:
        ahorro_mensual: Aporte mensual en pesos.
        edad_actual: Edad actual del contribuyente.
        edad_jubilacion: Edad objetivo de jubilación.
        tasa_anual: Tasa de rentabilidad anual.
        es_apv: True para APV (sin impuesto al rescate), False para inversión
                 normal con descuento LIR 107 (10% sobre ganancia de capital).

    Returns:
        Diccionario con proyección a jubilación.
    """
    meses = (edad_jubilacion - edad_actual) * 12
    tasa_mensual = (1 + tasa_anual) ** (1 / 12) - 1

    capital_final = float(-npf.fv(tasa_mensual, meses, ahorro_mensual, 0))
    total_aportes = ahorro_mensual * meses
    rentabilidad_total = capital_final - total_aportes

    if es_apv:
        impuesto_rescate = 0.0
    else:
        impuesto_rescate = round(rentabilidad_total * TASA_IMPUESTO_LIR107)

    capital_neto = round(capital_final - impuesto_rescate)

    return {
        "edad_actual": edad_actual,
        "edad_jubilacion": edad_jubilacion,
        "meses_ahorro": meses,
        "aporte_mensual": round(ahorro_mensual),
        "tasa_anual": tasa_anual,
        "capital_final": round(capital_final),
        "total_aportes": round(total_aportes),
        "rentabilidad_total": round(rentabilidad_total),
        "impuesto_rescate": round(impuesto_rescate),
        "capital_neto": capital_neto,
    }


def proyectar_jubilacion_anual(
    ahorro_mensual_apv: float,
    ahorro_mensual_normal: float,
    edad_actual: int,
    edad_jubilacion: int,
    tasa_anual: float,
) -> list[dict]:
    """Genera proyección año a año para graficar: capital APV y capital ahorro tradicional.

    Returns:
        Lista de dicts por año: anio, edad, capital_apv, capital_ahorro_tradicional,
        aporte_acumulado_apv, aporte_acumulado_normal.
    """
    tasa_mensual = (1 + tasa_anual) ** (1 / 12) - 1
    anos = edad_jubilacion - edad_actual
    if anos <= 0:
        return []

    registros = []
    for anio_num in range(1, anos + 1):
        meses = anio_num * 12
        edad = edad_actual + anio_num

        capital_apv = 0.0
        if ahorro_mensual_apv > 0:
            capital_apv = float(-npf.fv(tasa_mensual, meses, ahorro_mensual_apv, 0))

        capital_normal_bruto = 0.0
        if ahorro_mensual_normal > 0:
            capital_normal_bruto = float(-npf.fv(tasa_mensual, meses, ahorro_mensual_normal, 0))

        aporte_acum_apv = ahorro_mensual_apv * meses
        aporte_acum_normal = ahorro_mensual_normal * meses
        renta_normal = capital_normal_bruto - aporte_acum_normal
        impuesto_normal = renta_normal * TASA_IMPUESTO_LIR107 if ahorro_mensual_normal > 0 else 0.0
        capital_tradicional = capital_normal_bruto - impuesto_normal

        registros.append({
            "anio_proyeccion": anio_num,
            "edad": edad,
            "capital_apv": round(capital_apv),
            "capital_ahorro_tradicional": round(capital_tradicional),
            "aporte_acumulado_apv": round(aporte_acum_apv),
            "aporte_acumulado_normal": round(aporte_acum_normal),
        })
    return registros


def comparar_apv_vs_normal(
    ahorro_mensual_apv: float,
    ahorro_mensual_normal: float,
    edad_actual: int,
    edad_jubilacion: int,
    tasa_anual: float,
) -> dict:
    """Compara proyección APV vs inversión normal (ETF con LIR 107).

    Returns:
        Diccionario con ambas proyecciones y la ventaja del APV.
    """
    proy_apv = proyectar_jubilacion(
        ahorro_mensual=ahorro_mensual_apv,
        edad_actual=edad_actual,
        edad_jubilacion=edad_jubilacion,
        tasa_anual=tasa_anual,
        es_apv=True,
    )
    proy_normal = proyectar_jubilacion(
        ahorro_mensual=ahorro_mensual_normal,
        edad_actual=edad_actual,
        edad_jubilacion=edad_jubilacion,
        tasa_anual=tasa_anual,
        es_apv=False,
    )

    ventaja = proy_apv["capital_neto"] - proy_normal["capital_neto"]

    return {
        "apv": proy_apv,
        "normal": proy_normal,
        "ventaja_apv": ventaja,
    }
