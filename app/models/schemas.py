from pydantic import BaseModel, Field


# --- Modelos existentes (retrocompatibilidad) ---

class CalculoAPVRequest(BaseModel):
    sueldo_bruto_mensual: float = Field(..., gt=0, description="Sueldo bruto mensual en pesos chilenos")
    aporte_apv_mensual: float = Field(0, ge=0, description="Aporte APV mensual en pesos chilenos")


class CalculoAPVResponse(BaseModel):
    ahorro_fiscal_anual: float
    impuesto_sin_apv: float
    impuesto_con_apv: float
    base_imponible_pre: float
    base_imponible_post: float
    tasa_marginal: float
    aporte_apv_anual_efectivo: float
    tope_apv_anual: float


class ProyeccionRequest(BaseModel):
    aporte_mensual: float = Field(..., gt=0, description="Aporte mensual en pesos chilenos")
    meses: int = Field(..., gt=0, le=600, description="Cantidad de meses a proyectar")
    tasa_rentabilidad_anual: float = Field(0.05, ge=0, le=1, description="Tasa de rentabilidad anual")


class MesProyeccion(BaseModel):
    mes: int
    aporte_acumulado: float
    rentabilidad_acumulada: float
    capital_total: float


class ProyeccionResponse(BaseModel):
    proyeccion: list[MesProyeccion]
    capital_final: float
    total_aportes: float
    rentabilidad_total: float


class ParametrosResponse(BaseModel):
    ano_tributario: int
    uta: float
    uf: float
    utm: float
    limite_apv_uf: int
    limite_apv_pesos: float
    tasa_cotizaciones: float
    tramos_igc: list[dict]


# --- Nuevos modelos Fase 1 ---

class UserInput(BaseModel):
    sueldo_bruto_mensual: float = Field(..., gt=0, description="Sueldo bruto mensual en pesos chilenos")
    edad_actual: int = Field(..., ge=18, le=80, description="Edad actual del contribuyente")
    edad_jubilacion: int = Field(65, ge=50, le=80, description="Edad objetivo de jubilación")
    ahorro_mensual_apv: float = Field(0, ge=0, description="Aporte APV mensual en pesos chilenos")
    perfil_riesgo: float = Field(0.05, ge=0, le=0.30, description="Retorno anual esperado (ej: 0.05 = 5%)")
    ahorro_mensual_normal: float = Field(0, ge=0, description="Ahorro mensual inversión normal (ETF) en pesos")


class TaxParameters(BaseModel):
    uf: float
    utm: float
    uta: float
    tasa_cotizaciones: float
    tramos_igc: list[dict]


class ResultadoRegimenA(BaseModel):
    ahorro_apv_anual: float
    bonificacion_estatal: float
    tope_bonificacion: float
    bonificacion_efectiva: float


class ResultadoRegimenB(BaseModel):
    ahorro_apv_anual: float
    aporte_apv_efectivo: float
    tope_apv_anual: float
    base_imponible_sin_apv: float
    base_imponible_con_apv: float
    impuesto_sin_apv: float
    impuesto_con_apv: float
    ahorro_fiscal: float
    tasa_marginal: float


class ResultadoMix(BaseModel):
    monto_regimen_a: float
    monto_regimen_b: float
    beneficio_regimen_a: float
    beneficio_regimen_b: float
    beneficio_total: float
    explicacion: str


class ProyeccionJubilacion(BaseModel):
    edad_actual: int
    edad_jubilacion: int
    meses_ahorro: int
    aporte_mensual: float
    tasa_anual: float
    capital_final: float
    total_aportes: float
    rentabilidad_total: float
    impuesto_rescate: float
    capital_neto: float


class ComparacionAPVvsNormal(BaseModel):
    apv: ProyeccionJubilacion
    normal: ProyeccionJubilacion
    ventaja_apv: float


class SimulacionCompleta(BaseModel):
    regimen_a: ResultadoRegimenA
    regimen_b: ResultadoRegimenB
    mix: ResultadoMix
    mejor_regimen: str
    proyeccion_apv: ProyeccionJubilacion | None = None
    proyeccion_normal: ProyeccionJubilacion | None = None
    ventaja_apv_proyeccion: float | None = None


# --- Fase 2: Simulación APV con proyección año a año ---

class ProyeccionAnualItem(BaseModel):
    anio_proyeccion: int
    edad: int
    capital_apv: float
    capital_ahorro_tradicional: float
    aporte_acumulado_apv: float
    aporte_acumulado_normal: float


class TotalesSimulacionAPV(BaseModel):
    regimen_a: ResultadoRegimenA
    regimen_b: ResultadoRegimenB
    mix: ResultadoMix
    mejor_regimen: str
    ahorro_tradicional: ProyeccionJubilacion | None = None


class SimulacionAPVResponse(BaseModel):
    proyeccion_anual: list[ProyeccionAnualItem]
    totales: TotalesSimulacionAPV
