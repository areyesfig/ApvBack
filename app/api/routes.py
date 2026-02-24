"""Endpoints del motor de reglas fiscales APV."""

from fastapi import APIRouter

from app.models.schemas import (
    CalculoAPVRequest,
    CalculoAPVResponse,
    ProyeccionRequest,
    ProyeccionResponse,
    ParametrosResponse,
    UserInput,
    SimulacionCompleta,
    SimulacionAPVResponse,
)
from app.services.calculadora_apv import calcular_ahorro_regimen_b, simular_regimenes
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
def calcular_apv(req: CalculoAPVRequest):
    resultado = calcular_ahorro_regimen_b(
        sueldo_bruto_mensual=req.sueldo_bruto_mensual,
        aporte_apv_mensual=req.aporte_apv_mensual,
    )
    return resultado


@router.post("/proyeccion", response_model=ProyeccionResponse)
def proyeccion(req: ProyeccionRequest):
    resultado = proyectar(
        aporte_mensual=req.aporte_mensual,
        meses=req.meses,
        tasa_rentabilidad_anual=req.tasa_rentabilidad_anual,
    )
    return resultado


@router.get("/parametros", response_model=ParametrosResponse)
def parametros():
    ind = get_indicadores()
    limite_apv_pesos = LIMITE_APV_UF * ind["uf"]
    return {
        "ano_tributario": ANO_TRIBUTARIO,
        "uta": ind["uta"],
        "uf": ind["uf"],
        "utm": ind["utm"],
        "limite_apv_uf": LIMITE_APV_UF,
        "limite_apv_pesos": limite_apv_pesos,
        "tasa_cotizaciones": TASA_COTIZACIONES,
        "tramos_igc": obtener_tramos(),
    }


@router.post("/simular", response_model=SimulacionCompleta)
def simular(req: UserInput):
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


@router.post("/simulate/apv", response_model=SimulacionAPVResponse)
def simulate_apv(req: UserInput):
    """Simulación APV con proyección año a año para graficar y totales (Régimen A, B, Mix, Ahorro Tradicional)."""
    resultado = simular_regimenes(
        sueldo_bruto_mensual=req.sueldo_bruto_mensual,
        ahorro_apv_mensual=req.ahorro_mensual_apv,
    )

    proyeccion_anual = proyectar_jubilacion_anual(
        ahorro_mensual_apv=req.ahorro_mensual_apv,
        ahorro_mensual_normal=req.ahorro_mensual_normal,
        edad_actual=req.edad_actual,
        edad_jubilacion=req.edad_jubilacion,
        tasa_anual=req.perfil_riesgo,
    )

    ahorro_tradicional = None
    if req.ahorro_mensual_normal > 0:
        ahorro_tradicional = proyectar_jubilacion(
            ahorro_mensual=req.ahorro_mensual_normal,
            edad_actual=req.edad_actual,
            edad_jubilacion=req.edad_jubilacion,
            tasa_anual=req.perfil_riesgo,
            es_apv=False,
        )

    return {
        "proyeccion_anual": proyeccion_anual,
        "totales": {
            "regimen_a": resultado["regimen_a"],
            "regimen_b": resultado["regimen_b"],
            "mix": resultado["mix"],
            "mejor_regimen": resultado["mejor_regimen"],
            "ahorro_tradicional": ahorro_tradicional,
        },
    }
