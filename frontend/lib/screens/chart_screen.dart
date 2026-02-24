import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../core/models.dart';
import '../state/simulation_provider.dart';

final _nf = NumberFormat('#,###', 'es_CL');

class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({super.key});

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(simulationProvider);
    final state = asyncState.value;
    final result = state?.result;
    final list = result?.proyeccionAnual ?? [];

    if (list.isNotEmpty && _ctrl.status != AnimationStatus.completed) {
      _ctrl.forward();
    }
    if (list.isEmpty && _ctrl.status == AnimationStatus.completed) {
      _ctrl.reset();
    }

    if (list.isEmpty) {
      return Center(
        child: state?.loading == true ? _LoadingState() : _EmptyState(),
      );
    }

    final last = list.last;
    final maxY = _maxY(list);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) => Opacity(
          opacity: _anim.value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - _anim.value)),
            child: child,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Proyeccion',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              'Capital acumulado a jubilacion',
              style: GoogleFonts.inter(fontSize: 14, color: kTextMuted),
            ),
            const SizedBox(height: 20),

            // Hero Metrics
            Row(
              children: [
                Expanded(
                  child: _HeroMetricCard(
                    label: 'APV',
                    value: last.capitalApv,
                    color: kChartApv,
                    icon: Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroMetricCard(
                    label: 'ETF',
                    value: last.capitalAhorroTradicional,
                    color: kChartEtf,
                    icon: Icons.show_chart_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DifferenceChip(
              apv: last.capitalApv,
              etf: last.capitalAhorroTradicional,
            ),
            const SizedBox(height: 24),

            // Chart
            _ChartContainer(
              maxY: maxY,
              list: list,
            ),
            const SizedBox(height: 20),

            // Legend
            _ModernLegend(),
          ],
        ),
      ),
    );
  }

  double _maxY(List<ProyeccionAnualItem> list) {
    double m = 0;
    for (final e in list) {
      if (e.colchon > m) m = e.colchon;
      if (e.capitalAhorroTradicional > m) m = e.capitalAhorroTradicional;
      if (e.capitalApv > m) m = e.capitalApv;
    }
    return m > 0 ? m : 1;
  }
}

// ── Hero Metric Card ────────────────────────────────────────────────

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _shortMoney(value),
              key: ValueKey(value.round()),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${_nf.format(value.round())}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: kTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _shortMoney(double v) {
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.round()}';
  }
}

// ── Difference Chip ─────────────────────────────────────────────────

class _DifferenceChip extends StatelessWidget {
  const _DifferenceChip({required this.apv, required this.etf});
  final double apv;
  final double etf;

  @override
  Widget build(BuildContext context) {
    final diff = apv - etf;
    final isPositive = diff > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [kAccent.withValues(alpha: 0.1), kAccent.withValues(alpha: 0.05)]
              : [kAccent3.withValues(alpha: 0.1), kAccent3.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isPositive ? kAccent : kAccent3).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 16,
            color: isPositive ? kAccent : kAccent3,
          ),
          const SizedBox(width: 8),
          Text(
            'APV genera \$${_nf.format(diff.abs().round())} ${isPositive ? "mas" : "menos"} que ETF',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPositive ? kAccent : kAccent3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart Container ─────────────────────────────────────────────────

class _ChartContainer extends StatelessWidget {
  const _ChartContainer({required this.maxY, required this.list});
  final double maxY;
  final List<ProyeccionAnualItem> list;

  @override
  Widget build(BuildContext context) {
    final spotsColchon =
        list.map((e) => FlSpot(e.anioProyeccion.toDouble(), e.colchon)).toList();
    final spotsEtf = list
        .map((e) => FlSpot(e.anioProyeccion.toDouble(), e.capitalAhorroTradicional))
        .toList();
    final spotsApv =
        list.map((e) => FlSpot(e.anioProyeccion.toDouble(), e.capitalApv)).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 20, 16, 12),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderGlass),
      ),
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (v) => FlLine(
                color: kBorderGlass,
                strokeWidth: 0.5,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (v, meta) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _shortFormat(v),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: list.length > 20 ? 5 : 2,
                  getTitlesWidget: (v, meta) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'A${v.round()}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: list.length.toDouble() + 1,
            minY: 0,
            maxY: maxY * 1.06,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => kBgCardLight,
                tooltipBorder: const BorderSide(color: kBorderGlass),
                tooltipRoundedRadius: 12,
                getTooltipItems: (spots) => spots.map((spot) {
                  Color color;
                  String label;
                  switch (spot.barIndex) {
                    case 0:
                      color = kChartColchon;
                      label = 'Sin inv.';
                      break;
                    case 1:
                      color = kChartEtf;
                      label = 'ETF';
                      break;
                    default:
                      color = kChartApv;
                      label = 'APV';
                  }
                  return LineTooltipItem(
                    '$label: \$${_nf.format(spot.y.round())}',
                    GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              _line(spotsColchon, kChartColchon, dashed: true),
              _line(spotsEtf, kChartEtf, fillAlpha: 0.08),
              _line(spotsApv, kChartApv, fillAlpha: 0.15),
            ],
          ),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  LineChartBarData _line(
    List<FlSpot> spots,
    Color color, {
    bool dashed = false,
    double fillAlpha = 0,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: dashed ? 2 : 2.5,
      isStrokeCapRound: true,
      dashArray: dashed ? [6, 4] : null,
      dotData: const FlDotData(show: false),
      belowBarData: fillAlpha > 0
          ? BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: fillAlpha),
                  color.withValues(alpha: 0.0),
                ],
              ),
            )
          : BarAreaData(show: false),
    );
  }

  String _shortFormat(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(0)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.round().toString();
  }
}

// ── Modern Legend ────────────────────────────────────────────────────

class _ModernLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _LegendDot(color: kChartApv, label: 'APV', dashed: false),
        _LegendDot(color: kChartEtf, label: 'ETF', dashed: false),
        _LegendDot(color: kChartColchon, label: 'Sin inversion', dashed: true),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, required this.dashed});
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          SizedBox(
            width: 16,
            child: Row(
              children: [
                Container(width: 5, height: 3, color: color),
                const SizedBox(width: 2),
                Container(width: 5, height: 3, color: color),
              ],
            ),
          )
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: kTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Loading & Empty States ──────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: kAccent,
            backgroundColor: kBgCardLight,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Calculando proyeccion...',
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
            color: kAccent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.insights_rounded,
            size: 48,
            color: kAccent,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Ajusta los datos para ver tu proyeccion',
          style: GoogleFonts.inter(fontSize: 14, color: kTextMuted),
        ),
      ],
    );
  }
}
