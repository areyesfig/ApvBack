import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/models.dart';

/// Debounce en ms antes de llamar al backend.
const kSimulationDebounceMs = 500;

/// Estado de la simulación: inputs + resultado (o loading/error).
class SimulationState {
  const SimulationState({
    required this.input,
    this.result,
    this.loading = false,
    this.error,
  });

  final UserInput input;
  final SimulacionAPVResponse? result;
  final bool loading;
  final String? error;

  SimulationState copyWith({
    UserInput? input,
    SimulacionAPVResponse? result,
    bool? loading,
    String? error,
  }) {
    return SimulationState(
      input: input ?? this.input,
      result: result ?? this.result,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

/// Notifier que escucha cambios en los inputs, hace debounce y llama a la API.
class SimulationNotifier extends AsyncNotifier<SimulationState> {
  Timer? _debounceTimer;

  @override
  Future<SimulationState> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    final initial = SimulationState(input: _defaultInput());
    Future.microtask(() => refresh());
    return initial;
  }

  static UserInput _defaultInput() => UserInput(
        sueldoBrutoMensual: 2500000,
        edadActual: 35,
        edadJubilacion: 65,
        ahorroMensualApv: 150000,
        perfilRiesgo: PerfilRiesgo.moderado.tasaAnual,
        ahorroMensualNormal: 100000,
      );

  /// Actualiza solo los inputs (sin llamar API todavía).
  void updateInput(UserInput input) {
    _debounceTimer?.cancel();
    state = AsyncData(SimulationState(
      input: input,
      result: state.value?.result,
      loading: state.value?.loading ?? false,
      error: null,
    ));
    _debounceTimer = Timer(const Duration(milliseconds: kSimulationDebounceMs), () {
      _fetch(state.value!.input);
    });
  }

  /// Actualiza un campo y dispara debounce.
  void setSueldo(double v) => _update((i) => UserInput(
        sueldoBrutoMensual: v,
        edadActual: i.edadActual,
        edadJubilacion: i.edadJubilacion,
        ahorroMensualApv: i.ahorroMensualApv,
        perfilRiesgo: i.perfilRiesgo,
        ahorroMensualNormal: i.ahorroMensualNormal,
      ));
  void setEdadActual(int v) => _update((i) => UserInput(
        sueldoBrutoMensual: i.sueldoBrutoMensual,
        edadActual: v,
        edadJubilacion: i.edadJubilacion,
        ahorroMensualApv: i.ahorroMensualApv,
        perfilRiesgo: i.perfilRiesgo,
        ahorroMensualNormal: i.ahorroMensualNormal,
      ));
  void setEdadJubilacion(int v) => _update((i) => UserInput(
        sueldoBrutoMensual: i.sueldoBrutoMensual,
        edadActual: i.edadActual,
        edadJubilacion: v,
        ahorroMensualApv: i.ahorroMensualApv,
        perfilRiesgo: i.perfilRiesgo,
        ahorroMensualNormal: i.ahorroMensualNormal,
      ));
  void setAhorroApv(double v) => _update((i) => UserInput(
        sueldoBrutoMensual: i.sueldoBrutoMensual,
        edadActual: i.edadActual,
        edadJubilacion: i.edadJubilacion,
        ahorroMensualApv: v,
        perfilRiesgo: i.perfilRiesgo,
        ahorroMensualNormal: i.ahorroMensualNormal,
      ));
  void setAhorroNormal(double v) => _update((i) => UserInput(
        sueldoBrutoMensual: i.sueldoBrutoMensual,
        edadActual: i.edadActual,
        edadJubilacion: i.edadJubilacion,
        ahorroMensualApv: i.ahorroMensualApv,
        perfilRiesgo: i.perfilRiesgo,
        ahorroMensualNormal: v,
      ));
  void setPerfilRiesgo(double tasaAnual) => _update((i) => UserInput(
        sueldoBrutoMensual: i.sueldoBrutoMensual,
        edadActual: i.edadActual,
        edadJubilacion: i.edadJubilacion,
        ahorroMensualApv: i.ahorroMensualApv,
        perfilRiesgo: tasaAnual,
        ahorroMensualNormal: i.ahorroMensualNormal,
      ));

  void _update(UserInput Function(UserInput) fn) {
    final current = state.value?.input ?? _defaultInput();
    updateInput(fn(current));
  }

  Future<void> _fetch(UserInput input) async {
    state = AsyncData(SimulationState(
      input: input,
      result: state.value?.result,
      loading: true,
      error: null,
    ));
    try {
      final client = ref.read(apiClientProvider);
      final data = await client.simulateApv(input.toJson());
      final result = SimulacionAPVResponse.fromJson(data);
      state = AsyncData(SimulationState(input: input, result: result, loading: false, error: null));
    } catch (e, st) {
      state = AsyncData(SimulationState(
        input: input,
        result: state.value?.result,
        loading: false,
        error: e.toString(),
      ));
    }
  }

  /// Fuerza una petición inmediata (sin debounce).
  Future<void> refresh() async {
    _debounceTimer?.cancel();
    final input = state.value?.input ?? _defaultInput();
    await _fetch(input);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final simulationProvider = AsyncNotifierProvider<SimulationNotifier, SimulationState>(() => SimulationNotifier());
