import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/history_storage.dart';
import '../core/models.dart';

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<SavedSimulation>>(
  HistoryNotifier.new,
);

class HistoryNotifier extends AsyncNotifier<List<SavedSimulation>> {
  @override
  Future<List<SavedSimulation>> build() async {
    return loadHistory();
  }

  Future<void> addFromState(UserInput input, TotalesSimulacion totales, {double? capitalNetoApv}) async {
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    final entry = SavedSimulation(
      id: id,
      createdAtIso: DateTime.now().toIso8601String(),
      inputJson: input.toJson(),
      mejorRegimen: totales.mejorRegimen,
      ahorroFiscalAnual: totales.regimenB.ahorroFiscal,
      capitalNetoApv: capitalNetoApv ?? totales.ahorroTradicional?.capitalNeto,
    );
    await saveToHistory(entry);
    state = AsyncData(await loadHistory());
  }

  Future<void> remove(String id) async {
    await removeFromHistory(id);
    state = AsyncData(await loadHistory());
  }

  Future<void> refresh() async {
    state = AsyncData(await loadHistory());
  }
}
