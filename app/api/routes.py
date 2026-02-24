"""Endpoints del motor de reglas fiscales APV."""

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, Response

from app.limiter import limiter
from app.services.export_excel import generar_excel_simulacion
from app.models.schemas import (
    CalculoAPVRequest,
    CalculoAPVResponse,
    ProyeccionRequest,
    ProyeccionResponse,
    ParametrosResponse,
    UserInput,
    SimulacionCompleta,
    SimulacionAPVResponse,
    RecomendacionRequest,
    RecomendacionResponse,
    CompararEscenariosRequest,
    CompararEscenariosResponse,
    TASAS_FONDO,
)
from app.services.calculadora_apv import calcular_ahorro_regimen_b, simular_regimenes
from app.services.recomendacion import generar_recomendacion
from app.services.proyeccion import (
    proyectar,
    proyectar_jubilacion,
    comparar_apv_vs_normal,
    proyectar_jubilacion_anual,
)
from app.services.tabla_igc import obtener_tramos
from app.services.indicadores import get_indicadores
from app.config import (
    ANO_TRIBUTARIO,
    LIMITE_APV_UF,
    TASA_COTIZACIONES,
)

router = APIRouter(prefix="/api/v1")


@router.post("/calcular-apv", response_model=CalculoAPVResponse)
@limiter.limit("40/minute")
def calcular_apv(request: Request, req: CalculoAPVRequest):
    resultado = calcular_ahorro_regimen_b(
        sueldo_bruto_mensual=req.sueldo_bruto_mensual,
        aporte_apv_mensual=req.aporte_apv_mensual,
    )
    return resultado


@router.post("/proyeccion", response_model=ProyeccionResponse)
@limiter.limit("40/minute")
def proyeccion(request: Request, req: ProyeccionRequest):
    resultado = proyectar(
        aporte_mensual=req.aporte_mensual,
        meses=req.meses,
        tasa_rentabilidad_anual=req.tasa_rentabilidad_anual,
    )
    return resultado


# Cache público 1 hora para parametros (indicadores UF/UTM cambian poco)
PARAMETROS_CACHE_MAX_AGE = 3600


@router.get("/parametros", response_model=ParametrosResponse)
@limiter.limit("30/minute")
def parametros(request: Request):
    ind = get_indicadores()
    limite_apv_pesos = LIMITE_APV_UF * ind["uf"]
    tramos = obtener_tramos()
    # JSON no admite inf; el último tramo tiene hasta=inf → se envía null
    tramos_json = [
        {**t, "hasta": t["hasta"] if t["hasta"] != float("inf") else None}
        for t in tramos
    ]
    fondos_list = [
        {"id": "A", "nombre": "Fondo A", "descripcion": "Mayor riesgo, mayor retorno esperado", "tasa_anual": TASAS_FONDO["A"]},
        {"id": "B", "nombre": "Fondo B", "descripcion": "Riesgo alto", "tasa_anual": TASAS_FONDO["B"]},
        {"id": "C", "nombre": "Fondo C", "descripcion": "Riesgo equilibrado", "tasa_anual": TASAS_FONDO["C"]},
        {"id": "D", "nombre": "Fondo D", "descripcion": "Riesgo bajo", "tasa_anual": TASAS_FONDO["D"]},
        {"id": "E", "nombre": "Fondo E", "descripcion": "Más conservador", "tasa_anual": TASAS_FONDO["E"]},
    ]
    payload = {
        "ano_tributario": ANO_TRIBUTARIO,
        "uta": ind["uta"],
        "uf": ind["uf"],
        "utm": ind["utm"],
        "limite_apv_uf": LIMITE_APV_UF,
        "limite_apv_pesos": limite_apv_pesos,
        "tasa_cotizaciones": TASA_COTIZACIONES,
        "tramos_igc": tramos_json,
        "indicadores_actualizado_en": ind.get("indicadores_actualizado_en"),
        "fondos": fondos_list,
    }
    return JSONResponse(
        content=payload,
        headers={"Cache-Control": f"public, max-age={PARAMETROS_CACHE_MAX_AGE}"},
    )


@router.post("/simular", response_model=SimulacionCompleta)
@limiter.limit("20/minute")
def simular(request: Request, req: UserInput):
    resultado = simular_regimenes(
        sueldo_bruto_mensual=req.sueldo_bruto_mensual,
        ahorro_apv_mensual=req.ahorro_mensual_apv,
    )

    # Proyecciones opcionales (si hay ahorro APV o normal)
    proyeccion_apv = None
    proyeccion_normal = None
    ventaja = None

    if req.ahorro_mensual_apv > 0:
        proyeccion_apv = proyectar_jubilacion(
            ahorro_mensual=req.ahorro_mensual_apv,
            edad_actual=req.edad_actual,
            edad_jubilacion=req.edad_jubilacion,
            tasa_anual=req.perfil_riesgo,
            es_apv=True,
        )

    if req.ahorro_mensual_normal > 0:
        proyeccion_normal = proyectar_jubilacion(
            ahorro_mensual=req.ahorro_mensual_normal,
            edad_actual=req.edad_actual,
            edad_jubilacion=req.edad_jubilacion,
            tasa_anual=req.perfil_riesgo,
            es_apv=False,
        )

    if proyeccion_apv and proyeccion_normal:
        ventaja = proyeccion_apv["capital_neto"] - proyeccion_normal["capital_neto"]

    return {
        **resultado,
        "proyeccion_apv": proyeccion_apv,
        "proyeccion_normal": proyeccion_normal,
        "ventaja_apv_proyeccion": ventaja,
    }


def _beneficio_regimen_elegido(resultado: dict, regimen_elegido: str) -> float:
    """Devuelve el beneficio anual del régimen elegido (A, B o el mejor del Mix)."""
    if regimen_elegido == "A":
        return resultado["regimen_a"]["bonificacion_efectiva"]
    if regimen_elegido == "B":
        return resultado["regimen_b"]["ahorro_fiscal"]
    # auto: beneficio del mejor régimen
    mejor = resultado["mejor_regimen"]
    if mejor == "Régimen A":
        return resultado["regimen_a"]["bonificacion_efectiva"]
    if mejor == "Régimen B":
        return resultado["regimen_b"]["ahorro_fiscal"]
    return resultado["mix"]["beneficio_total"]


@router.post("/simulate/apv", response_model=SimulacionAPVResponse)
@limiter.limit("20/minute")
def simulate_apv(request: Request, req: UserInput):
    """Simulación APV con proyección año a año para graficar y totales (Régimen A, B, Mix, Ahorro Tradicional)."""
    resultado = simular_regimenes(
        sueldo_bruto_mensual=req.sueldo_bruto_mensual,
        ahorro_apv_mensual=req.ahorro_mensual_apv,
    )
    tasa = req.tasa_proyeccion()

    proyeccion_anual = proyectar_jubilacion_anual(
        ahorro_mensual_apv=req.ahorro_mensual_apv,
        ahorro_mensual_normal=req.ahorro_mensual_normal,
        edad_actual=req.edad_actual,
        edad_jubilacion=req.edad_jubilacion,
        tasa_anual=tasa,
    )

    ahorro_tradicional = None
    if req.ahorro_mensual_normal > 0:
        ahorro_tradicional = proyectar_jubilacion(
            ahorro_mensual=req.ahorro_mensual_normal,
            edad_actual=req.edad_actual,
            edad_jubilacion=req.edad_jubilacion,
            tasa_anual=tasa,
            es_apv=False,
        )

    beneficio_elegido = _beneficio_regimen_elegido(resultado, req.regimen_elegido)

    return {
        "proyeccion_anual": proyeccion_anual,
        "totales": {
            "regimen_a": resultado["regimen_a"],
            "regimen_b": resultado["regimen_b"],
            "mix": resultado["mix"],
            "mejor_regimen": resultado["mejor_regimen"],
            "ahorro_tradicional": ahorro_tradicional,
            "regimen_elegido": req.regimen_elegido,
            "beneficio_regimen_elegido": beneficio_elegido,
        },
    }


@router.post("/export/excel")
@limiter.limit("10/minute")
def export_excel(request: Request, req: UserInput):
    """Genera un Excel con datos de entrada, totales por régimen y proyección año a año."""
    content = generar_excel_simulacion(
        sueldo_bruto_mensual=req.sueldo_bruto_mensual,
        edad_actual=req.edad_actual,
        edad_jubilacion=req.edad_jubilacion,
        ahorro_mensual_apv=req.ahorro_mensual_apv,
        perfil_riesgo=req.perfil_riesgo,
        ahorro_mensual_normal=req.ahorro_mensual_normal,
    )
    return Response(
        content=content,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=simulacion_apv.xlsx"},
    )


@router.post("/recomendacion", response_model=RecomendacionResponse)
@limiter.limit("30/minute")
def recomendacion(request: Request, req: RecomendacionRequest):
    """Recomendación de régimen APV y aporte sugerido según sueldo y edad."""
    return generar_recomendacion(
        sueldo_bruto_mensual=req.sueldo_bruto_mensual,
        edad_actual=req.edad_actual,
        edad_jubilacion=req.edad_jubilacion,
        ahorro_mensual_apv=req.ahorro_mensual_apv,
    )


@router.post("/comparar", response_model=CompararEscenariosResponse)
@limiter.limit("20/minute")
def comparar_escenarios(request: Request, req: CompararEscenariosRequest):
    """Compara dos escenarios (ej. distinto aporte APV) y devuelve diferencias en ahorro fiscal y capital proyectado."""
    a = req.escenario_a
    b = req.escenario_b

    res_a = simular_regimenes(a.sueldo_bruto_mensual, a.ahorro_mensual_apv)
    res_b = simular_regimenes(b.sueldo_bruto_mensual, b.ahorro_mensual_apv)

    proy_a = None
    proy_b = None
    if a.ahorro_mensual_apv > 0:
        proy_a = proyectar_jubilacion(
            ahorro_mensual=a.ahorro_mensual_apv,
            edad_actual=a.edad_actual,
            edad_jubilacion=a.edad_jubilacion,
            tasa_anual=a.perfil_riesgo,
            es_apv=True,
        )
    if b.ahorro_mensual_apv > 0:
        proy_b = proyectar_jubilacion(
            ahorro_mensual=b.ahorro_mensual_apv,
            edad_actual=b.edad_actual,
            edad_jubilacion=b.edad_jubilacion,
            tasa_anual=b.perfil_riesgo,
            es_apv=True,
        )

    beneficio_a = _beneficio_anual(res_a)
    beneficio_b = _beneficio_anual(res_b)
    diferencia_ahorro_fiscal = beneficio_b - beneficio_a

    capital_neto_a = proy_a["capital_neto"] if proy_a else None
    capital_neto_b = proy_b["capital_neto"] if proy_b else None
    diferencia_capital = (capital_neto_b - capital_neto_a) if (capital_neto_a is not None and capital_neto_b is not None) else None

    if diferencia_ahorro_fiscal > 0:
        msg = f"El escenario B ahorra ${diferencia_ahorro_fiscal:,.0f} más al año en impuestos."
    elif diferencia_ahorro_fiscal < 0:
        msg = f"El escenario A ahorra ${-diferencia_ahorro_fiscal:,.0f} más al año en impuestos."
    else:
        msg = "Ambos escenarios tienen el mismo beneficio tributario anual."
    if diferencia_capital is not None and diferencia_capital != 0:
        msg += f" A jubilación, la diferencia en capital APV sería ${diferencia_capital:,.0f}."

    return {
        "escenario_a": {"simulacion": res_a, "proyeccion_apv": proy_a},
        "escenario_b": {"simulacion": res_b, "proyeccion_apv": proy_b},
        "diferencia_ahorro_fiscal": round(diferencia_ahorro_fiscal),
        "diferencia_capital_neto_apv": round(diferencia_capital) if diferencia_capital is not None else None,
        "mensaje": msg,
    }


def _beneficio_anual(resultado: dict) -> float:
    """Extrae el beneficio anual (ahorro fiscal o bonificación) del mejor régimen."""
    mejor = resultado["mejor_regimen"]
    if mejor == "Régimen A":
        return resultado["regimen_a"]["bonificacion_efectiva"]
    if mejor == "Régimen B":
        return resultado["regimen_b"]["ahorro_fiscal"]
    return resultado["mix"]["beneficio_total"]
