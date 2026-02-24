from typing import Literal

from pydantic import BaseModel, Field, model_validator


# --- Modelos existentes (retrocompatibilidad) ---

# Límites razonables para mitigar DoS por inputs extremos (Chile)
MAX_SUELDO_MENSUAL = 500_000_000
MAX_APORTE_MENSUAL = 100_000_000


class CalculoAPVRequest(BaseModel):
    sueldo_bruto_mensual: float = Field(..., gt=0, le=MAX_SUELDO_MENSUAL, description="Sueldo bruto mensual en pesos chilenos")
    aporte_apv_mensual: float = Field(0, ge=0, le=MAX_APORTE_MENSUAL, description="Aporte APV mensual en pesos chilenos")


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
    aporte_mensual: float = Field(..., gt=0, le=MAX_APORTE_MENSUAL, description="Aporte mensual en pesos chilenos")
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


class FondoInfo(BaseModel):
    id: str  # A, B, C, D, E
    nombre: str
    descripcion: str
    tasa_anual: float


class ParametrosResponse(BaseModel):
    ano_tributario: int
    uta: float
    uf: float
    utm: float
    limite_apv_uf: int
    limite_apv_pesos: float
    tasa_cotizaciones: float
    tramos_igc: list[dict]
    indicadores_actualizado_en: str | None = None  # ISO UTC, para mostrar "UF vigente al dd/mm/yyyy"
    fondos: list[FondoInfo] = []  # Tipos de fondo AFP para selector


# --- Nuevos modelos Fase 1 ---

# Tasas de retorno histórico referencial por tipo de fondo AFP Chile (aproximadas)
TASAS_FONDO: dict[str, float] = {
    "A": 0.10,   # Mayor riesgo, mayor retorno esperado
    "B": 0.07,
    "C": 0.05,
    "D": 0.03,
    "E": 0.02,   # Más conservador
}


class UserInput(BaseModel):
    sueldo_bruto_mensual: float = Field(..., gt=0, le=MAX_SUELDO_MENSUAL, description="Sueldo bruto mensual en pesos chilenos")
    edad_actual: int = Field(..., ge=18, le=80, description="Edad actual del contribuyente")
    edad_jubilacion: int = Field(65, ge=50, le=80, description="Edad objetivo de jubilación")
    ahorro_mensual_apv: float = Field(0, ge=0, le=MAX_APORTE_MENSUAL, description="Aporte APV mensual en pesos chilenos")
    perfil_riesgo: float = Field(0.05, ge=0, le=0.30, description="Retorno anual esperado (ej: 0.05 = 5%)")
    ahorro_mensual_normal: float = Field(0, ge=0, le=MAX_APORTE_MENSUAL, description="Ahorro mensual inversión normal (ETF) en pesos")
    regimen_elegido: Literal["auto", "A", "B"] = Field("auto", description="Régimen tributario elegido: auto (mejor), A o B")
    tipo_fondo: Literal["A", "B", "C", "D", "E"] | None = Field(None, description="Tipo de fondo AFP para proyección (A=riesgoso, E=conservador). Si se envía, define la tasa de retorno.")

    @model_validator(mode="after")
    def edad_jubilacion_mayor_que_actual(self):
        if self.edad_jubilacion <= self.edad_actual:
            raise ValueError("edad_jubilacion debe ser mayor que edad_actual")
        return self

    def tasa_proyeccion(self) -> float:
        """Tasa anual para proyección: tipo_fondo si está definido, sino perfil_riesgo."""
        if self.tipo_fondo and self.tipo_fondo in TASAS_FONDO:
            return TASAS_FONDO[self.tipo_fondo]
        return self.perfil_riesgo


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
    regimen_elegido: str = "auto"  # "auto" | "A" | "B"
    beneficio_regimen_elegido: float | None = None  # Beneficio anual del régimen elegido


class SimulacionAPVResponse(BaseModel):
    proyeccion_anual: list[ProyeccionAnualItem]
    totales: TotalesSimulacionAPV


# --- Recomendación y comparación ---

class RecomendacionRequest(BaseModel):
    """Entrada mínima para obtener recomendación (sueldo y edad)."""
    sueldo_bruto_mensual: float = Field(..., gt=0, le=MAX_SUELDO_MENSUAL)
    edad_actual: int = Field(..., ge=18, le=80)
    edad_jubilacion: int = Field(65, ge=50, le=80)
    ahorro_mensual_apv: float = Field(0, ge=0, le=MAX_APORTE_MENSUAL)

    @model_validator(mode="after")
    def edad_jubilacion_mayor_que_actual(self):
        if self.edad_jubilacion <= self.edad_actual:
            raise ValueError("edad_jubilacion debe ser mayor que edad_actual")
        return self


class RecomendacionResponse(BaseModel):
    mejor_regimen: str
    tope_apv_pesos: float
    aporte_sugerido_mensual: float  # Sugerencia (ej. 10% sueldo con tope)
    beneficio_anual_estimado: float
    mensaje: str


class CompararEscenariosRequest(BaseModel):
    """Dos escenarios para comparar (ej. 100k vs 200k de APV)."""
    escenario_a: UserInput
    escenario_b: UserInput


class CompararEscenariosResponse(BaseModel):
    escenario_a: dict  # Resultado simulación A
    escenario_b: dict  # Resultado simulación B
    diferencia_ahorro_fiscal: float  # B - A (positivo si B ahorra más)
    diferencia_capital_neto_apv: float | None  # Si ambos tienen proyección APV
    mensaje: str
