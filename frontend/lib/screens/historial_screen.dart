import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../core/models.dart';
import '../state/history_provider.dart';
import '../state/simulation_provider.dart';

final _nf = NumberFormat('#,###', 'es_CL');

class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistorialScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: kBgDeep,
      appBar: AppBar(
        title: const Text('Mis simulaciones'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: asyncList.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: kTextMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay simulaciones guardadas',
                    style: GoogleFonts.inter(fontSize: 15, color: kTextMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En Resumen, pulsa "Guardar" para añadir una',
                    style: GoogleFonts.inter(fontSize: 13, color: kTextMuted),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              final date = _formatDate(s.createdAtIso);
              return Dismissible(
                key: Key(s.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: kAccent3.withValues(alpha: 0.2),
                  child: const Icon(Icons.delete_rounded, color: kAccent3),
                ),
                onDismissed: (_) => ref.read(historyProvider.notifier).remove(s.id),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      final input = UserInput.fromJson(s.inputJson);
                      await ref.read(simulationProvider.notifier).loadInput(input);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.savings_rounded, color: kAccent, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.mejorRegimen,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ahorro fiscal \$${_nf.format(s.ahorroFiscalAnual.round())}/año · $date',
                                  style: GoogleFonts.inter(fontSize: 13, color: kTextMuted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: kTextMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
          ),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: GoogleFonts.inter(color: kAccent3)),
        ),
      ),
    );
  }

  static String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy HH:mm').format(d);
    } catch (_) {
      return iso;
    }
  }
}
