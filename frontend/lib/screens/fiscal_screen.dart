import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../core/models.dart';
import '../state/history_provider.dart';
import '../state/parametros_provider.dart';
import '../state/simulation_provider.dart';
import 'pdf_export.dart';

final _nf = NumberFormat('#,###', 'es_CL');

void _share(TotalesSimulacion totales, UserInput input) {
  final rb = totales.regimenB;
  final text = 'Simulación APV Chile\n'
      'Mejor régimen: ${totales.mejorRegimen}\n'
      'Ahorro fiscal anual: \$${_nf.format(rb.ahorroFiscal.round())}\n'
      'Sueldo bruto: \$${_nf.format(input.sueldoBrutoMensual.round())}/mes · Aporte APV: \$${_nf.format(input.ahorroMensualApv.round())}/mes\n'
      'Generado con APV Simulator';
  Share.share(text);
}

class FiscalScreen extends ConsumerWidget {
  const FiscalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(simulationProvider);
    final state = asyncState.value;
    final result = state?.result;
    final totales = result?.totales;
    final input = state?.input;
    final parametrosAsync = ref.watch(parametrosProvider);
    final isOffline = state?.isFromOfflineCache ?? false;

    if (totales == null || input == null) {
      return Center(
        child: state?.loading == true ? _LoadingState() : _EmptyState(),
      );
    }

    final rb = totales.regimenB;
    final ra = totales.regimenA;
    final aporteAnual = input.ahorroMensualApv * 12;
    final lastItem = result?.proyeccionAnual.isNotEmpty == true ? result!.proyeccionAnual.last : null;
    final capitalNetoApv = lastItem != null ? (lastItem.capitalApv + lastItem.capitalAhorroTradicional) : totales.ahorroTradicional?.capitalNeto;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        if (isOffline) _OfflineBanner(),
        if (parametrosAsync.valueOrNull != null) _IndicadoresRow(parametros: parametrosAsync.value!),
        // Header
        Semantics(
          header: true,
          child: Text(
            'Resumen fiscal',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
              letterSpacing: -0.8,
            ),
          ),
        ),
        Text(
          'Beneficios tributarios anuales',
          style: GoogleFonts.inter(fontSize: 14, color: kTextMuted),
        ),
        const SizedBox(height: 12),
        _ActionButtons(
          onSave: () => ref.read(historyProvider.notifier).addFromState(input, totales, capitalNetoApv: capitalNetoApv),
          onShare: () => _share(totales, input),
          onPdf: () => PdfExport.exportAndShare(context, input, totales, result!),
        ),
        const SizedBox(height: 20),

        // Hero: Devolucion SII
        _RefundHeroCard(
          aporteAnual: aporteAnual,
          devolucion: rb.ahorroFiscal,
        ),
        const SizedBox(height: 16),

        // Detalle impuestos
        _TaxDetailCard(rb: rb),
        const SizedBox(height: 16),

        // Limites
        _LimitesCard(rb: rb, ra: ra),
        const SizedBox(height: 16),

        // Régimen elegido (si no es auto)
        if (totales.regimenElegido != 'auto' && totales.beneficioRegimenElegido != null)
          _RegimenElegidoCard(
            regimenElegido: totales.regimenElegido,
            beneficio: totales.beneficioRegimenElegido!,
            mejorRegimen: totales.mejorRegimen,
          ),
        if (totales.regimenElegido != 'auto' && totales.beneficioRegimenElegido != null)
          const SizedBox(height: 16),
        // Mejor opcion
        _BestOptionCard(totales: totales),
      ],
    );
  }
}

// ── Offline banner ──────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kAccent3.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent3.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: kAccent3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Datos de la última vez que tuviste conexión',
              style: GoogleFonts.inter(fontSize: 12, color: kAccent3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Indicadores (UF actualizado) ────────────────────────────────────

class _IndicadoresRow extends StatelessWidget {
  const _IndicadoresRow({required this.parametros});
  final ParametrosModel parametros;

  @override
  Widget build(BuildContext context) {
    String subtitle = 'UF = \$${_nf.format(parametros.uf.round())}';
    if (parametros.indicadoresActualizadoEn != null) {
      try {
        final d = DateTime.parse(parametros.indicadoresActualizadoEn!);
        subtitle += ' (actualizado al ${DateFormat('dd/MM/yyyy').format(d)})';
      } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 12, color: kTextMuted),
      ),
    );
  }
}

// ── Action buttons (Guardar, Compartir, PDF) ─────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onSave, required this.onShare, required this.onPdf});
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Guardar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccent,
              side: BorderSide(color: kAccent.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Compartir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccent2,
              side: BorderSide(color: kAccent2.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextPrimary,
              side: const BorderSide(color: kBorderGlass),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Refund Hero Card ────────────────────────────────────────────────

class _RefundHeroCard extends StatefulWidget {
  const _RefundHeroCard({required this.aporteAnual, required this.devolucion});
  final double aporteAnual;
  final double devolucion;

  @override
  State<_RefundHeroCard> createState() => _RefundHeroCardState();
}

class _RefundHeroCardState extends State<_RefundHeroCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _RefundHeroCard old) {
    super.didUpdateWidget(old);
    if (old.devolucion != widget.devolucion) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Transform.scale(
        scale: 0.95 + 0.05 * _anim.value,
        child: Opacity(opacity: _anim.value, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kAccent.withValues(alpha: 0.15),
              kAccent2.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kAccent.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: kAccent.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    size: 20,
                    color: kAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Operacion Renta',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'El SII te devuelve',
              style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                '\$${_nf.format(widget.devolucion.round())}',
                key: ValueKey(widget.devolucion.round()),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: kAccent,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: kBorderGlass,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inversion APV anual',
                  style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
                ),
                Text(
                  '\$${_nf.format(widget.aporteAnual.round())}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tasa efectiva de retorno',
                  style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.aporteAnual > 0
                        ? '${((widget.devolucion / widget.aporteAnual) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tax Detail Card ─────────────────────────────────────────────────

class _TaxDetailCard extends StatelessWidget {
  const _TaxDetailCard({required this.rb});
  final dynamic rb;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalle impuestos',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _TaxRow(
            label: 'Impuesto sin APV',
            value: rb.impuestoSinApv,
            color: kAccent3,
          ),
          const SizedBox(height: 10),
          _TaxRow(
            label: 'Impuesto con APV',
            value: rb.impuestoConApv,
            color: kAccent,
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: kBorderGlass),
          const SizedBox(height: 12),
          _TaxRow(
            label: 'Ahorro fiscal neto',
            value: rb.ahorroFiscal,
            color: kAccent,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _TaxRow extends StatelessWidget {
  const _TaxRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });
  final String label;
  final double value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: bold ? kTextPrimary : kTextSecondary,
          ),
        ),
        Text(
          '\$${_nf.format(value.round())}',
          style: GoogleFonts.spaceGrotesk(
            fontSize: bold ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Limites Card ────────────────────────────────────────────────────

class _LimitesCard extends StatelessWidget {
  const _LimitesCard({required this.rb, required this.ra});
  final dynamic rb;
  final dynamic ra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, size: 18, color: kAccent2),
              const SizedBox(width: 8),
              Text(
                'Limites de beneficio',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _GlowProgressBar(
            label: 'Regimen B: tope 600 UF',
            used: rb.aporteApvEfectivo,
            total: rb.topeApvAnual,
            color: kAccent2,
          ),
          const SizedBox(height: 16),
          _GlowProgressBar(
            label: 'Regimen A: tope 6 UTM',
            used: ra.bonificacionEfectiva,
            total: ra.topeBonificacion,
            color: kAccent,
          ),
        ],
      ),
    );
  }
}

class _GlowProgressBar extends StatefulWidget {
  const _GlowProgressBar({
    required this.label,
    required this.used,
    required this.total,
    required this.color,
  });
  final String label;
  final double used;
  final double total;
  final Color color;

  @override
  State<_GlowProgressBar> createState() => _GlowProgressBarState();
}

class _GlowProgressBarState extends State<_GlowProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _GlowProgressBar old) {
    super.didUpdateWidget(old);
    if (old.used != widget.used || old.total != widget.total) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.total > 0 ? (widget.used / widget.total).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kTextSecondary,
              ),
            ),
            Text(
              '$pct%',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            return Container(
              height: 8,
              decoration: BoxDecoration(
                color: kBgCardLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth * progress * _anim.value;
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: w,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.color,
                                widget.color.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          '\$${_nf.format(widget.used.round())} / \$${_nf.format(widget.total.round())}',
          style: GoogleFonts.inter(fontSize: 11, color: kTextMuted),
        ),
      ],
    );
  }
}

// ── Régimen elegido (cuando el usuario eligió A o B) ─────────────────

class _RegimenElegidoCard extends StatelessWidget {
  const _RegimenElegidoCard({
    required this.regimenElegido,
    required this.beneficio,
    required this.mejorRegimen,
  });
  final String regimenElegido;
  final double beneficio;
  final String mejorRegimen;

  @override
  Widget build(BuildContext context) {
    final label = regimenElegido == 'A' ? 'Régimen A' : 'Régimen B';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 20, color: kAccent),
              const SizedBox(width: 10),
              Text(
                'Tu régimen: $label',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Beneficio anual: \$${_nf.format(beneficio.round())}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'El óptimo para tu caso sería $mejorRegimen.',
            style: GoogleFonts.inter(fontSize: 12, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

// ── Best Option Card ────────────────────────────────────────────────

class _BestOptionCard extends StatelessWidget {
  const _BestOptionCard({required this.totales});
  final dynamic totales;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccent2.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kAccent2, Color(0xFF9B59FF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent2.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                'Mejor opcion para ti',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kAccent2.withValues(alpha: 0.12),
                  kAccent.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kAccent2.withValues(alpha: 0.3)),
            ),
            child: Text(
              totales.mejorRegimen,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kAccent2,
              ),
            ),
          ),
          if (totales.mix.explicacion.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              totales.mix.explicacion,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: kTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── States ──────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: kAccent,
            backgroundColor: kBgCardLight,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Calculando...',
          style: GoogleFonts.inter(fontSize: 14, color: kTextMuted),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kAccent2.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            size: 48,
            color: kAccent2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Ajusta tus datos para ver el resumen',
          style: GoogleFonts.inter(fontSize: 14, color: kTextMuted),
        ),
      ],
    );
  }
}
