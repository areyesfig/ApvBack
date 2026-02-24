import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../core/models.dart';
import '../state/simulation_provider.dart';

final _nf = NumberFormat('#,###', 'es_CL');

class CompararBottomSheet extends ConsumerStatefulWidget {
  const CompararBottomSheet({super.key, required this.input});
  final UserInput input;

  static Future<void> show(BuildContext context, WidgetRef ref, UserInput input) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CompararBottomSheet(input: input),
    );
  }

  @override
  ConsumerState<CompararBottomSheet> createState() => _CompararBottomSheetState();
}

class _CompararBottomSheetState extends ConsumerState<CompararBottomSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final base = widget.input;
    final escenarioA = base.toJson();
    final escenarioB = UserInput(
      sueldoBrutoMensual: base.sueldoBrutoMensual,
      edadActual: base.edadActual,
      edadJubilacion: base.edadJubilacion,
      ahorroMensualApv: (base.ahorroMensualApv + 100000).clamp(0.0, 5000000),
      perfilRiesgo: base.perfilRiesgo,
      ahorroMensualNormal: base.ahorroMensualNormal,
    ).toJson();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final data = await client.compararEscenarios(escenarioA, escenarioB);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: kBorderGlass)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kTextMuted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '¿Qué pasa si aporto más?',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparando tu aporte actual vs +\$100.000/mes APV',
            style: GoogleFonts.inter(fontSize: 13, color: kTextMuted),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
                ),
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAccent3.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: kAccent3)),
            )
          else if (_data != null)
            _CompararContent(data: _data!, input: widget.input),
        ],
      ),
    );
  }
}

class _CompararContent extends StatelessWidget {
  const _CompararContent({required this.data, required this.input});
  final Map<String, dynamic> data;
  final UserInput input;

  @override
  Widget build(BuildContext context) {
    final escA = data['escenario_a'] as Map<String, dynamic>?;
    final escB = data['escenario_b'] as Map<String, dynamic>?;
    final diffFiscal = (data['diferencia_ahorro_fiscal'] as num?)?.toDouble() ?? 0.0;
    final diffCapital = (data['diferencia_capital_neto_apv'] as num?)?.toDouble();
    final mensaje = data['mensaje'] as String? ?? '';

    final simA = escA?['simulacion'] as Map<String, dynamic>?;
    final simB = escB?['simulacion'] as Map<String, dynamic>?;
    final beneficioA = _beneficio(simA);
    final beneficioB = _beneficio(simB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                title: 'Actual',
                subtitle: '\$${_nf.format(input.ahorroMensualApv.round())}/mes',
                value: '\$${_nf.format(beneficioA.round())}',
                label: 'Ahorro fiscal/año',
                color: kAccent2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniCard(
                title: '+ \$100k/mes',
                subtitle: '\$${_nf.format((input.ahorroMensualApv + 100000).round())}/mes',
                value: '\$${_nf.format(beneficioB.round())}',
                label: 'Ahorro fiscal/año',
                color: kAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kAccent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diferencia',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${_nf.format(diffFiscal.round())} más al año en impuestos ahorrados',
                style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
              ),
              if (diffCapital != null && diffCapital != 0) ...[
                const SizedBox(height: 4),
                Text(
                  'A jubilación: \$${_nf.format(diffCapital.round())} más en capital proyectado',
                  style: GoogleFonts.inter(fontSize: 12, color: kTextMuted),
                ),
              ],
            ],
          ),
        ),
        if (mensaje.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(mensaje, style: GoogleFonts.inter(fontSize: 12, color: kTextMuted)),
        ],
      ],
    );
  }

  static double _beneficio(Map<String, dynamic>? sim) {
    if (sim == null) return 0;
    final mejor = sim['mejor_regimen'] as String?;
    if (mejor == 'Régimen A') {
      final ra = sim['regimen_a'] as Map<String, dynamic>?;
      return (ra?['bonificacion_efectiva'] as num?)?.toDouble() ?? 0;
    }
    if (mejor == 'Régimen B') {
      final rb = sim['regimen_b'] as Map<String, dynamic>?;
      return (rb?['ahorro_fiscal'] as num?)?.toDouble() ?? 0;
    }
    final mix = sim['mix'] as Map<String, dynamic>?;
    return (mix?['beneficio_total'] as num?)?.toDouble() ?? 0;
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.label,
    required this.color,
  });
  final String title;
  final String subtitle;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBgDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: kTextMuted)),
        ],
      ),
    );
  }
}
