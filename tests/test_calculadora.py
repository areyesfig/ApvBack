"""Tests para el motor de reglas fiscales APV."""

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.tabla_igc import aplicar, CalculadoraIGC
from app.services.calculadora_apv import (
    calcular_ahorro_regimen_b,
    simular_regimenes,
    EstrategiaRegimenA,
    EstrategiaRegimenB,
    EstrategiaOptimizada,
)
from app.services.proyeccion import proyectar_jubilacion, comparar_apv_vs_normal
from app.config import UTA, UTM, TOPE_BONIFICACION_A, TASA_BONIFICACION_A


client = TestClient(app)


# --- Tests tabla IGC ---

class TestTablaIGC:
    def test_tramo_exento(self):
        """Renta bajo 13.5 UTA debe pagar 0 impuesto."""
        renta = 10 * UTA
        impuesto, tasa = aplicar(renta)
        assert impuesto == 0
        assert tasa == 0.0

    def test_tramo_4_porciento(self):
        """Renta entre 13.5 y 30 UTA debe tributar al 4%."""
        renta = 20 * UTA
        impuesto, tasa = aplicar(renta)
        assert tasa == 0.04
        esperado = 0.26 * UTA
        assert abs(impuesto - esperado) < 1

    def test_tramo_8_porciento(self):
        """Renta entre 30 y 50 UTA debe tributar al 8%."""
        renta = 40 * UTA
        impuesto, tasa = aplicar(renta)
        assert tasa == 0.08
        esperado = (40 * 0.08 - 1.74) * UTA
        assert abs(impuesto - esperado) < 1

    def test_tramo_alto(self):
        """Renta sobre 150 UTA debe tributar al 40%."""
        renta = 200 * UTA
        impuesto, tasa = aplicar(renta)
        assert tasa == 0.40
        esperado = (200 * 0.40 - 30.82) * UTA
        assert abs(impuesto - esperado) < 1


class TestCalculadoraIGCClase:
    def test_calcular_base_imponible(self):
        """Verifica descuento de cotizaciones."""
        calc = CalculadoraIGC()
        base = calc.calcular_base_imponible(12_000_000, 0.205)
        assert base == 12_000_000 * (1 - 0.205)

    def test_calcular_impuesto_consistente(self):
        """Clase y función wrapper deben dar el mismo resultado."""
        calc = CalculadoraIGC()
        renta = 40 * UTA
        imp_clase, tasa_clase = calc.calcular_impuesto(renta)
        imp_func, tasa_func = aplicar(renta)
        assert imp_clase == imp_func
        assert tasa_clase == tasa_func


# --- Tests calculadora APV ---

class TestCalculadoraAPV:
    def test_ahorro_positivo(self):
        """Contribuyente con APV debe tener ahorro fiscal positivo."""
        resultado = calcular_ahorro_regimen_b(
            sueldo_bruto_mensual=3_000_000,
            aporte_apv_mensual=200_000,
        )
        assert resultado["ahorro_fiscal_anual"] > 0
        assert resultado["impuesto_sin_apv"] > resultado["impuesto_con_apv"]

    def test_sin_apv_ahorro_cero(self):
        """Sin aporte APV el ahorro fiscal debe ser 0."""
        resultado = calcular_ahorro_regimen_b(
            sueldo_bruto_mensual=3_000_000,
            aporte_apv_mensual=0,
        )
        assert resultado["ahorro_fiscal_anual"] == 0

    def test_tope_600_uf(self):
        """El aporte APV efectivo no debe superar 600 UF."""
        resultado = calcular_ahorro_regimen_b(
            sueldo_bruto_mensual=10_000_000,
            aporte_apv_mensual=5_000_000,
        )
        assert resultado["aporte_apv_anual_efectivo"] == resultado["tope_apv_anual"]

    def test_sueldo_bajo_exento(self):
        """Sueldo bajo (tramo exento) no genera ahorro fiscal."""
        resultado = calcular_ahorro_regimen_b(
            sueldo_bruto_mensual=500_000,
            aporte_apv_mensual=50_000,
        )
        assert resultado["ahorro_fiscal_anual"] == 0
        assert resultado["tasa_marginal"] == 0.0


# --- Tests Régimen A ---

class TestRegimenA:
    def test_bonificacion_15_porciento(self):
        """Régimen A otorga 15% de bonificación sobre el ahorro."""
        calc = CalculadoraIGC()
        base = calc.calcular_base_imponible(2_000_000 * 12)
        estrategia = EstrategiaRegimenA()
        resultado = estrategia.calcular(base, 1_200_000, calc)
        assert resultado["bonificacion_efectiva"] == round(1_200_000 * 0.15)

    def test_tope_6_utm(self):
        """La bonificación no puede superar 6 UTM."""
        calc = CalculadoraIGC()
        base = calc.calcular_base_imponible(5_000_000 * 12)
        # Ahorro muy alto para forzar tope
        ahorro_alto = 10_000_000
        estrategia = EstrategiaRegimenA()
        resultado = estrategia.calcular(base, ahorro_alto, calc)
        assert resultado["bonificacion_efectiva"] == round(TOPE_BONIFICACION_A)
        assert resultado["bonificacion_efectiva"] <= 6 * UTM

    def test_sueldo_bajo_bonificacion_directa(self):
        """Régimen A beneficia incluso a quien está exento de IGC."""
        calc = CalculadoraIGC()
        base = calc.calcular_base_imponible(500_000 * 12)
        estrategia = EstrategiaRegimenA()
        resultado = estrategia.calcular(base, 600_000, calc)
        assert resultado["bonificacion_efectiva"] > 0


# --- Tests Mix ---

class TestMixOptimizado:
    def test_mix_mayor_o_igual_a_individual(self):
        """El beneficio del mix debe ser >= al mejor régimen individual."""
        resultado = simular_regimenes(
            sueldo_bruto_mensual=3_000_000,
            ahorro_apv_mensual=300_000,
        )
        beneficio_a = resultado["regimen_a"]["bonificacion_efectiva"]
        beneficio_b = resultado["regimen_b"]["ahorro_fiscal"]
        beneficio_mix = resultado["mix"]["beneficio_total"]
        assert beneficio_mix >= max(beneficio_a, beneficio_b)

    def test_mix_sueldo_alto_prioriza_b(self):
        """Con tasa marginal alta, mix prioriza Régimen B."""
        resultado = simular_regimenes(
            sueldo_bruto_mensual=8_000_000,
            ahorro_apv_mensual=500_000,
        )
        assert resultado["mix"]["monto_regimen_b"] >= resultado["mix"]["monto_regimen_a"]

    def test_mix_sueldo_bajo_prioriza_a(self):
        """Con tasa marginal baja, mix prioriza Régimen A."""
        resultado = simular_regimenes(
            sueldo_bruto_mensual=1_200_000,
            ahorro_apv_mensual=100_000,
        )
        assert resultado["mix"]["monto_regimen_a"] >= resultado["mix"]["monto_regimen_b"]

    def test_mejor_regimen_determinado(self):
        """simular_regimenes debe indicar el mejor régimen."""
        resultado = simular_regimenes(
            sueldo_bruto_mensual=3_000_000,
            ahorro_apv_mensual=200_000,
        )
        assert resultado["mejor_regimen"] in ("Régimen A", "Régimen B", "Mix")


# --- Tests proyección jubilación ---

class TestProyeccionJubilacion:
    def test_capital_crece(self):
        """Capital final debe superar total de aportes."""
        resultado = proyectar_jubilacion(
            ahorro_mensual=200_000,
            edad_actual=30,
            edad_jubilacion=65,
            tasa_anual=0.05,
            es_apv=True,
        )
        assert resultado["capital_final"] > resultado["total_aportes"]
        assert resultado["meses_ahorro"] == 420

    def test_apv_sin_impuesto_rescate(self):
        """APV no cobra impuesto al rescate."""
        resultado = proyectar_jubilacion(
            ahorro_mensual=200_000,
            edad_actual=30,
            edad_jubilacion=65,
            tasa_anual=0.05,
            es_apv=True,
        )
        assert resultado["impuesto_rescate"] == 0
        assert resultado["capital_neto"] == resultado["capital_final"]

    def test_normal_descuenta_lir107(self):
        """Inversión normal descuenta 10% sobre ganancia de capital."""
        resultado = proyectar_jubilacion(
            ahorro_mensual=200_000,
            edad_actual=30,
            edad_jubilacion=65,
            tasa_anual=0.05,
            es_apv=False,
        )
        assert resultado["impuesto_rescate"] > 0
        assert resultado["capital_neto"] < resultado["capital_final"]
        # Impuesto = 10% de la ganancia (tolerancia ±1 por redondeo)
        expected_tax = round(resultado["rentabilidad_total"] * 0.10)
        assert abs(resultado["impuesto_rescate"] - expected_tax) <= 1

    def test_comparacion_apv_vs_normal(self):
        """APV tiene ventaja sobre inversión normal (mismo monto, sin impuesto)."""
        comp = comparar_apv_vs_normal(
            ahorro_mensual_apv=200_000,
            ahorro_mensual_normal=200_000,
            edad_actual=30,
            edad_jubilacion=65,
            tasa_anual=0.05,
        )
        assert comp["ventaja_apv"] > 0
        assert comp["apv"]["capital_neto"] > comp["normal"]["capital_neto"]


# --- Tests endpoints API ---

class TestAPI:
    def test_calcular_apv_endpoint(self):
        response = client.post("/api/v1/calcular-apv", json={
            "sueldo_bruto_mensual": 3_000_000,
            "aporte_apv_mensual": 200_000,
        })
        assert response.status_code == 200
        data = response.json()
        assert "ahorro_fiscal_anual" in data
        assert data["ahorro_fiscal_anual"] > 0

    def test_proyeccion_endpoint(self):
        response = client.post("/api/v1/proyeccion", json={
            "aporte_mensual": 200_000,
            "meses": 12,
            "tasa_rentabilidad_anual": 0.05,
        })
        assert response.status_code == 200
        data = response.json()
        assert len(data["proyeccion"]) == 12
        assert data["capital_final"] > 200_000 * 12

    def test_parametros_endpoint(self):
        response = client.get("/api/v1/parametros")
        assert response.status_code == 200
        data = response.json()
        assert "uta" in data
        assert "utm" in data
        assert "tramos_igc" in data
        assert len(data["tramos_igc"]) == 8

    def test_simular_endpoint(self):
        response = client.post("/api/v1/simular", json={
            "sueldo_bruto_mensual": 3_000_000,
            "edad_actual": 30,
            "edad_jubilacion": 65,
            "ahorro_mensual_apv": 200_000,
            "perfil_riesgo": 0.05,
            "ahorro_mensual_normal": 200_000,
        })
        assert response.status_code == 200
        data = response.json()
        assert "regimen_a" in data
        assert "regimen_b" in data
        assert "mix" in data
        assert "mejor_regimen" in data
        assert "proyeccion_apv" in data
        assert "proyeccion_normal" in data
        assert data["ventaja_apv_proyeccion"] > 0

    def test_simular_solo_apv(self):
        """Simular con solo APV (sin inversión normal)."""
        response = client.post("/api/v1/simular", json={
            "sueldo_bruto_mensual": 2_000_000,
            "edad_actual": 35,
            "edad_jubilacion": 65,
            "ahorro_mensual_apv": 150_000,
            "perfil_riesgo": 0.06,
            "ahorro_mensual_normal": 0,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["proyeccion_apv"] is not None
        assert data["proyeccion_normal"] is None
        assert data["ventaja_apv_proyeccion"] is None

    def test_simulate_apv_endpoint(self):
        """POST /api/v1/simulate/apv devuelve proyección año a año y totales."""
        response = client.post("/api/v1/simulate/apv", json={
            "sueldo_bruto_mensual": 3_000_000,
            "edad_actual": 30,
            "edad_jubilacion": 65,
            "ahorro_mensual_apv": 200_000,
            "perfil_riesgo": 0.05,
            "ahorro_mensual_normal": 200_000,
        })
        assert response.status_code == 200
        data = response.json()
        assert "proyeccion_anual" in data
        assert "totales" in data
        totales = data["totales"]
        assert "regimen_a" in totales
        assert "regimen_b" in totales
        assert "mix" in totales
        assert "mejor_regimen" in totales
        assert "ahorro_tradicional" in totales
        assert totales["ahorro_tradicional"] is not None
        anos = 65 - 30
        assert len(data["proyeccion_anual"]) == anos
        primer_anio = data["proyeccion_anual"][0]
        assert primer_anio["anio_proyeccion"] == 1
        assert primer_anio["edad"] == 31
        assert "capital_apv" in primer_anio
        assert "capital_ahorro_tradicional" in primer_anio
