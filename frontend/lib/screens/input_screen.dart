import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../core/models.dart';
import '../state/parametros_provider.dart';
import '../state/simulation_provider.dart';
import 'comparar_bottom_sheet.dart';

final _nf = NumberFormat('#,###', 'es_CL');

class InputScreen extends ConsumerWidget {
  const InputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(simulationProvider);
    final state = asyncState.value;
    final parametros = ref.watch(parametrosProvider).valueOrNull;
    final input = state?.input ??
        UserInput(
          sueldoBrutoMensual: 2500000,
          edadActual: 35,
          edadJubilacion: 65,
          ahorroMensualApv: 150000,
          perfilRiesgo: PerfilRiesgo.moderado.tasaAnual,
          ahorroMensualNormal: 100000,
        );

    final topeMensual = parametros != null ? parametros.limiteApvPesos / 12 : 0.0;
    final recomendado = topeMensual > 0
        ? (input.sueldoBrutoMensual * 0.10).clamp(0.0, topeMensual)
        : input.sueldoBrutoMensual * 0.10;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        // Header de sección
        _SectionHeader(
          title: 'Tu perfil financiero',
          subtitle: 'Ajusta los parametros para simular tu APV',
        ),
        const SizedBox(height: 16),

        // Sueldo
        _GlassInputCard(
          index: 0,
          icon: Icons.account_balance_wallet_rounded,
          iconGradient: const [kAccent, Color(0xFF00B880)],
          title: 'Sueldo bruto mensual',
          valueText: '\$${_nf.format(input.sueldoBrutoMensual.round())}',
          child: Semantics(
            label: 'Sueldo bruto mensual',
            value: '\$${_nf.format(input.sueldoBrutoMensual.round())}',
            slider: true,
            child: _GradientSlider(
              value: input.sueldoBrutoMensual,
              min: 500000,
              max: 15000000,
              divisions: 29,
              activeColor: kAccent,
              onChanged: (v) => ref.read(simulationProvider.notifier).setSueldo(v),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Edades en row
        Row(
          children: [
            Expanded(
              child: _GlassCompactCard(
                index: 1,
                icon: Icons.person_rounded,
                title: 'Edad actual',
                valueText: '${input.edadActual} anos',
                child: _GradientSlider(
                  value: input.edadActual.toDouble(),
                  min: 18,
                  max: 64,
                  divisions: 46,
                  activeColor: kAccent2,
                  onChanged: (v) =>
                      ref.read(simulationProvider.notifier).setEdadActual(v.round()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlassCompactCard(
                index: 2,
                icon: Icons.beach_access_rounded,
                title: 'Jubilacion',
                valueText: '${input.edadJubilacion} anos',
                child: _GradientSlider(
                  value: input.edadJubilacion.toDouble(),
                  min: 50,
                  max: 75,
                  divisions: 25,
                  activeColor: kAccent2,
                  onChanged: (v) =>
                      ref.read(simulationProvider.notifier).setEdadJubilacion(v.round()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Sugerencia de aporte (tope 600 UF)
        if (parametros != null)
          _TopeAportCard(
            topeAnual: parametros.limiteApvPesos,
            recomendadoMensual: recomendado,
            actualMensual: input.ahorroMensualApv,
          ),
        if (parametros != null) const SizedBox(height: 8),
        // APV mensual
        _GlassInputCard(
          index: 3,
          icon: Icons.savings_rounded,
          iconGradient: const [Color(0xFF6C63FF), Color(0xFF9B59FF)],
          title: 'Ahorro mensual APV',
          valueText: '\$${_nf.format(input.ahorroMensualApv.round())}',
            child: Semantics(
              label: 'Ahorro mensual APV',
              value: '\$${_nf.format(input.ahorroMensualApv.round())}',
              slider: true,
              child: _GradientSlider(
                value: input.ahorroMensualApv,
                min: 0,
                max: (parametros?.limiteApvPesos ?? 25000000) / 12,
                divisions: 30,
                activeColor: kAccent2,
                onChanged: (v) => ref.read(simulationProvider.notifier).setAhorroApv(v),
              ),
            ),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: 'Comparar escenarios: qué pasa si aporto más',
          child: OutlinedButton.icon(
            onPressed: () => CompararBottomSheet.show(context, ref, input),
            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
            label: const Text('¿Qué pasa si aporto más?'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccent2,
              side: BorderSide(color: kAccent2.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Régimen tributario (A, B o Automático)
        _RegimenSelectorCard(
          selected: input.regimenElegido,
          onSelected: (r) => ref.read(simulationProvider.notifier).setRegimenElegido(r),
        ),
        const SizedBox(height: 12),

        // Tipo de fondo AFP (A–E)
        _FondoSelectorCard(
          fondos: parametros?.fondos ?? [],
          selectedId: input.tipoFondo,
          onSelected: (id) => ref.read(simulationProvider.notifier).setTipoFondo(id),
        ),
        const SizedBox(height: 12),

        // ETF mensual
        _GlassInputCard(
          index: 4,
          icon: Icons.trending_up_rounded,
          iconGradient: const [kChartEtf, Color(0xFFFFBB5C)],
          title: 'Ahorro mensual ETF',
          valueText: '\$${_nf.format(input.ahorroMensualNormal.round())}',
          child: _GradientSlider(
            value: input.ahorroMensualNormal,
            min: 0,
            max: 1000000,
            divisions: 20,
            activeColor: kChartEtf,
            onChanged: (v) => ref.read(simulationProvider.notifier).setAhorroNormal(v),
          ),
        ),
        const SizedBox(height: 12),

        // Perfil de riesgo
        _RiskProfileCard(
          selectedTasa: input.perfilRiesgo,
          onSelected: (t) => ref.read(simulationProvider.notifier).setPerfilRiesgo(t),
        ),
        const SizedBox(height: 12),

        // Status indicator
        if (state?.loading == true) const _PulseLoadingBar(),
        if (state?.error != null) _ErrorChip(message: state!.error.toString()),
      ],
    );
  }
}

// ── Tope y sugerencia de aporte ─────────────────────────────────────

class _TopeAportCard extends StatelessWidget {
  const _TopeAportCard({
    required this.topeAnual,
    required this.recomendadoMensual,
    required this.actualMensual,
  });
  final double topeAnual;
  final double recomendadoMensual;
  final double actualMensual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kAccent2.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccent2.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Puedes aportar hasta \$${_nf.format(topeAnual.round())}/año en APV (600 UF)',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Sugerencia: \$${_nf.format(recomendadoMensual.round())}/mes (≈10% sueldo)',
            style: GoogleFonts.inter(fontSize: 11, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

// ── Selector Régimen A / B / Automático ─────────────────────────────

class _RegimenSelectorCard extends StatelessWidget {
  const _RegimenSelectorCard({required this.selected, required this.onSelected});
  final RegimenElegido selected;
  final ValueChanged<RegimenElegido> onSelected;

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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.balance_rounded, size: 18, color: kAccent),
              ),
              const SizedBox(width: 12),
              Text(
                'Régimen tributario',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: RegimenElegido.values.map((r) {
              final isSelected = selected == r;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: r != RegimenElegido.values.last ? 8 : 0),
                  child: Material(
                    color: isSelected ? kAccent.withValues(alpha: 0.15) : kBgCardLight,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => onSelected(r),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            r == RegimenElegido.auto ? 'Auto' : r == RegimenElegido.a ? 'A' : 'B',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? kAccent : kTextMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            selected.label,
            style: GoogleFonts.inter(fontSize: 11, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

// ── Selector tipo de fondo (A–E) ─────────────────────────────────────

class _FondoSelectorCard extends StatelessWidget {
  const _FondoSelectorCard({required this.fondos, required this.selectedId, required this.onSelected});
  final List<FondoInfo> fondos;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (fondos.isEmpty) return const SizedBox.shrink();
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kChartEtf.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pie_chart_rounded, size: 18, color: kChartEtf),
              ),
              const SizedBox(width: 12),
              Text(
                'Tipo de fondo AFP',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: fondos.map((f) {
                final isSelected = selectedId == f.id;
                return Padding(
                  padding: EdgeInsets.only(right: f.id != fondos.last.id ? 8 : 0),
                  child: Tooltip(
                    message: '${f.nombre}: ${f.descripcion} (${(f.tasaAnual * 100).round()}% retorno ref.)',
                    child: Material(
                      color: isSelected ? kChartEtf.withValues(alpha: 0.2) : kBgCardLight,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => onSelected(isSelected ? null : f.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Fondo ${f.id}',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? kChartEtf : kTextMuted,
                                ),
                              ),
                              Text(
                                '${(f.tasaAnual * 100).round()}%',
                                style: GoogleFonts.inter(fontSize: 11, color: kTextMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: kTextMuted,
          ),
        ),
      ],
    );
  }
}

// ── Glass Input Card ────────────────────────────────────────────────

class _GlassInputCard extends StatefulWidget {
  const _GlassInputCard({
    required this.index,
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.valueText,
    required this.child,
  });
  final int index;
  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String valueText;
  final Widget child;

  @override
  State<_GlassInputCard> createState() => _GlassInputCardState();
}

class _GlassInputCardState extends State<_GlassInputCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeSlide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeSlide,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - _fadeSlide.value)),
        child: Opacity(opacity: _fadeSlide.value, child: child),
      ),
      child: Container(
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.iconGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: widget.iconGradient.first.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kTextSecondary,
                    ),
                  ),
                ),
                // Valor animado
                _AnimatedValueBadge(text: widget.valueText),
              ],
            ),
            const SizedBox(height: 16),
            widget.child,
          ],
        ),
      ),
    );
  }
}

// ── Compact Card (para edades side by side) ─────────────────────────

class _GlassCompactCard extends StatefulWidget {
  const _GlassCompactCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.valueText,
    required this.child,
  });
  final int index;
  final IconData icon;
  final String title;
  final String valueText;
  final Widget child;

  @override
  State<_GlassCompactCard> createState() => _GlassCompactCardState();
}

class _GlassCompactCardState extends State<_GlassCompactCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
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
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - _anim.value)),
        child: Opacity(opacity: _anim.value, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Icon(widget.icon, size: 16, color: kAccent2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.valueText,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            widget.child,
          ],
        ),
      ),
    );
  }
}

// ── Animated Value Badge ────────────────────────────────────────────

class _AnimatedValueBadge extends StatelessWidget {
  const _AnimatedValueBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kAccent.withValues(alpha: 0.2)),
        ),
        child: Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kAccent,
          ),
        ),
      ),
    );
  }
}

// ── Gradient Slider ─────────────────────────────────────────────────

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.activeColor,
    required this.onChanged,
  });
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: activeColor,
        inactiveTrackColor: kBgCardLight,
        thumbColor: activeColor,
        overlayColor: activeColor.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}


// ── Risk Profile Card ───────────────────────────────────────────────

class _RiskProfileCard extends StatelessWidget {
  const _RiskProfileCard({required this.selectedTasa, required this.onSelected});
  final double selectedTasa;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    PerfilRiesgo selected = PerfilRiesgo.moderado;
    for (final p in PerfilRiesgo.values) {
      if ((p.tasaAnual - selectedTasa).abs() < 0.001) selected = p;
    }

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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent3.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.speed_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                'Perfil de riesgo',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (int i = 0; i < PerfilRiesgo.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _RiskChip(
                    p: PerfilRiesgo.values[i],
                    isSelected: PerfilRiesgo.values[i] == selected,
                    onTap: () => onSelected(PerfilRiesgo.values[i].tasaAnual),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.p, required this.isSelected, required this.onTap});
  final PerfilRiesgo p;
  final bool isSelected;
  final VoidCallback onTap;

  Color get _chipColor {
    switch (p) {
      case PerfilRiesgo.conservador:
        return kAccent;
      case PerfilRiesgo.moderado:
        return kAccent2;
      case PerfilRiesgo.agresivo:
        return kAccent3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _chipColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : kBgCardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Text(
              p.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : kTextMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(p.tasaAnual * 100).round()}%',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading Bar ─────────────────────────────────────────────────────

class _PulseLoadingBar extends StatefulWidget {
  const _PulseLoadingBar();

  @override
  State<_PulseLoadingBar> createState() => _PulseLoadingBarState();
}

class _PulseLoadingBarState extends State<_PulseLoadingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: kBgCardLight,
          ),
          child: FractionallySizedBox(
            alignment: Alignment((_ctrl.value * 2) - 1, 0),
            widthFactor: 0.3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [kAccent, kAccent2],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kAccent.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Error Chip ──────────────────────────────────────────────────────

class _ErrorChip extends StatelessWidget {
  const _ErrorChip({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccent3.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccent3.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: kAccent3, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 12, color: kAccent3),
            ),
          ),
        ],
      ),
    );
  }
}
