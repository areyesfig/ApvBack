/// Entrada del usuario para la simulación (alineado con backend UserInput).
class UserInput {
  UserInput({
    required this.sueldoBrutoMensual,
    required this.edadActual,
    this.edadJubilacion = 65,
    this.ahorroMensualApv = 0,
    this.perfilRiesgo = 0.05,
    this.ahorroMensualNormal = 0,
  });

  final double sueldoBrutoMensual;
  final int edadActual;
  final int edadJubilacion;
  final double ahorroMensualApv;
  final double perfilRiesgo;
  final double ahorroMensualNormal;

  Map<String, dynamic> toJson() => {
        'sueldo_bruto_mensual': sueldoBrutoMensual,
        'edad_actual': edadActual,
        'edad_jubilacion': edadJubilacion,
        'ahorro_mensual_apv': ahorroMensualApv,
        'perfil_riesgo': perfilRiesgo,
        'ahorro_mensual_normal': ahorroMensualNormal,
      };
}

/// Un año de la proyección (para gráficos).
class ProyeccionAnualItem {
  ProyeccionAnualItem({
    required this.anioProyeccion,
    required this.edad,
    required this.capitalApv,
    required this.capitalAhorroTradicional,
    required this.aporteAcumuladoApv,
    required this.aporteAcumuladoNormal,
  });

  factory ProyeccionAnualItem.fromJson(Map<String, dynamic> j) {
    return ProyeccionAnualItem(
      anioProyeccion: (j['anio_proyeccion'] as num).toInt(),
      edad: (j['edad'] as num).toInt(),
      capitalApv: (j['capital_apv'] as num).toDouble(),
      capitalAhorroTradicional: (j['capital_ahorro_tradicional'] as num).toDouble(),
      aporteAcumuladoApv: (j['aporte_acumulado_apv'] as num).toDouble(),
      aporteAcumuladoNormal: (j['aporte_acumulado_normal'] as num).toDouble(),
    );
  }

  final int anioProyeccion;
  final int edad;
  final double capitalApv;
  final double capitalAhorroTradicional;
  final double aporteAcumuladoApv;
  final double aporteAcumuladoNormal;

  /// Ahorro "bajo el colchón": solo aportes, sin rentabilidad.
  double get colchon => aporteAcumuladoApv + aporteAcumuladoNormal;
}

/// Totales de la simulación (Régimen A, B, Mix, ahorro tradicional).
class TotalesSimulacion {
  TotalesSimulacion({
    required this.regimenA,
    required this.regimenB,
    required this.mix,
    required this.mejorRegimen,
    this.ahorroTradicional,
  });

  factory TotalesSimulacion.fromJson(Map<String, dynamic> j) {
    return TotalesSimulacion(
      regimenA: RegimenAResult.fromJson(j['regimen_a'] as Map<String, dynamic>),
      regimenB: RegimenBResult.fromJson(j['regimen_b'] as Map<String, dynamic>),
      mix: MixResult.fromJson(j['mix'] as Map<String, dynamic>),
      mejorRegimen: j['mejor_regimen'] as String,
      ahorroTradicional: j['ahorro_tradicional'] != null
          ? ProyeccionJubilacionResult.fromJson(j['ahorro_tradicional'] as Map<String, dynamic>)
          : null,
    );
  }

  final RegimenAResult regimenA;
  final RegimenBResult regimenB;
  final MixResult mix;
  final String mejorRegimen;
  final ProyeccionJubilacionResult? ahorroTradicional;
}

class RegimenAResult {
  RegimenAResult({required this.bonificacionEfectiva, required this.topeBonificacion});
  factory RegimenAResult.fromJson(Map<String, dynamic> j) => RegimenAResult(
        bonificacionEfectiva: (j['bonificacion_efectiva'] as num).toDouble(),
        topeBonificacion: (j['tope_bonificacion'] as num).toDouble(),
      );
  final double bonificacionEfectiva;
  final double topeBonificacion;
}

class RegimenBResult {
  RegimenBResult({
    required this.ahorroFiscal,
    required this.aporteApvEfectivo,
    required this.topeApvAnual,
    required this.impuestoSinApv,
    required this.impuestoConApv,
  });
  factory RegimenBResult.fromJson(Map<String, dynamic> j) => RegimenBResult(
        ahorroFiscal: (j['ahorro_fiscal'] as num).toDouble(),
        aporteApvEfectivo: (j['aporte_apv_efectivo'] as num).toDouble(),
        topeApvAnual: (j['tope_apv_anual'] as num).toDouble(),
        impuestoSinApv: (j['impuesto_sin_apv'] as num).toDouble(),
        impuestoConApv: (j['impuesto_con_apv'] as num).toDouble(),
      );
  final double ahorroFiscal;
  final double aporteApvEfectivo;
  final double topeApvAnual;
  final double impuestoSinApv;
  final double impuestoConApv;
}

class MixResult {
  MixResult({required this.beneficioTotal, required this.explicacion});
  factory MixResult.fromJson(Map<String, dynamic> j) => MixResult(
        beneficioTotal: (j['beneficio_total'] as num).toDouble(),
        explicacion: j['explicacion'] as String,
      );
  final double beneficioTotal;
  final String explicacion;
}

class ProyeccionJubilacionResult {
  ProyeccionJubilacionResult({required this.capitalNeto, required this.impuestoRescate});
  factory ProyeccionJubilacionResult.fromJson(Map<String, dynamic> j) => ProyeccionJubilacionResult(
        capitalNeto: (j['capital_neto'] as num).toDouble(),
        impuestoRescate: (j['impuesto_rescate'] as num).toDouble(),
      );
  final double capitalNeto;
  final double impuestoRescate;
}

/// Respuesta completa de POST /simulate/apv.
class SimulacionAPVResponse {
  SimulacionAPVResponse({required this.proyeccionAnual, required this.totales});

  factory SimulacionAPVResponse.fromJson(Map<String, dynamic> j) {
    final list = j['proyeccion_anual'] as List<dynamic>;
    return SimulacionAPVResponse(
      proyeccionAnual: list.map((e) => ProyeccionAnualItem.fromJson(e as Map<String, dynamic>)).toList(),
      totales: TotalesSimulacion.fromJson(j['totales'] as Map<String, dynamic>),
    );
  }

  final List<ProyeccionAnualItem> proyeccionAnual;
  final TotalesSimulacion totales;
}

/// Perfil de riesgo con etiqueta y tasa anual (0.04 = 4%).
enum PerfilRiesgo {
  conservador('Conservador', 0.04),
  moderado('Moderado', 0.07),
  agresivo('Agresivo', 0.10);

  const PerfilRiesgo(this.label, this.tasaAnual);
  final String label;
  final double tasaAnual;
}
