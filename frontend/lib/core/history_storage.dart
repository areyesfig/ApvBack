import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Una simulación guardada (inputs + resumen para listado).
class SavedSimulation {
  SavedSimulation({
    required this.id,
    required this.createdAtIso,
    required this.inputJson,
    required this.mejorRegimen,
    required this.ahorroFiscalAnual,
    this.capitalNetoApv,
  });

  final String id;
  final String createdAtIso;
  final Map<String, dynamic> inputJson;
  final String mejorRegimen;
  final double ahorroFiscalAnual;
  final double? capitalNetoApv;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAtIso': createdAtIso,
        'inputJson': inputJson,
        'mejorRegimen': mejorRegimen,
        'ahorroFiscalAnual': ahorroFiscalAnual,
        'capitalNetoApv': capitalNetoApv,
      };

  static SavedSimulation fromJson(Map<String, dynamic> j) {
    return SavedSimulation(
      id: j['id'] as String,
      createdAtIso: j['createdAtIso'] as String,
      inputJson: Map<String, dynamic>.from(j['inputJson'] as Map),
      mejorRegimen: j['mejorRegimen'] as String,
      ahorroFiscalAnual: (j['ahorroFiscalAnual'] as num).toDouble(),
      capitalNetoApv: (j['capitalNetoApv'] as num?)?.toDouble(),
    );
  }
}

const _keyHistory = 'apv_simulations_history';
const _maxSimulations = 20;

Future<List<SavedSimulation>> loadHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyHistory);
  if (raw == null) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SavedSimulation.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveToHistory(SavedSimulation entry) async {
  final list = await loadHistory();
  final updated = [entry, ...list.where((e) => e.id != entry.id)].take(_maxSimulations).toList();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _keyHistory,
    jsonEncode(updated.map((e) => e.toJson()).toList()),
  );
}

Future<void> removeFromHistory(String id) async {
  final list = await loadHistory();
  final updated = list.where((e) => e.id != id).toList();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _keyHistory,
    jsonEncode(updated.map((e) => e.toJson()).toList()),
  );
}

const _keyOnboardingDone = 'apv_onboarding_done';

Future<bool> getOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyOnboardingDone) ?? false;
}

Future<void> setOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyOnboardingDone, true);
}

const _keyLastSimulation = 'apv_offline_last_simulation';
const _keyLastParametros = 'apv_offline_last_parametros';

Future<void> setOfflineCacheSimulation(String jsonBody) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyLastSimulation, jsonBody);
}

Future<String?> getOfflineCacheSimulation() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyLastSimulation);
}

Future<void> setOfflineCacheParametros(String jsonBody) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyLastParametros, jsonBody);
}

Future<String?> getOfflineCacheParametros() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keyLastParametros);
}
