import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/history_storage.dart';
import '../core/models.dart';
import 'simulation_provider.dart';

final parametrosProvider = AsyncNotifierProvider<ParametrosNotifier, ParametrosModel?>(ParametrosNotifier.new);

class ParametrosNotifier extends AsyncNotifier<ParametrosModel?> {
  @override
  Future<ParametrosModel?> build() async {
    final client = ref.read(apiClientProvider);
    try {
      final data = await client.getParametros();
      final model = ParametrosModel.fromJson(data);
      await setOfflineCacheParametros(jsonEncode(data));
      return model;
    } catch (_) {
      final cached = await getOfflineCacheParametros();
      if (cached != null) {
        try {
          return ParametrosModel.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        } catch (_) {}
      }
      return null;
    }
  }

  Future<void> refresh() async {
    final client = ref.read(apiClientProvider);
    try {
      final data = await client.getParametros();
      final model = ParametrosModel.fromJson(data);
      await setOfflineCacheParametros(jsonEncode(data));
      state = AsyncData(model);
    } catch (_) {
      final cached = await getOfflineCacheParametros();
      if (cached != null) {
        try {
          state = AsyncData(ParametrosModel.fromJson(jsonDecode(cached) as Map<String, dynamic>));
        } catch (_) {}
      }
    }
  }
}
