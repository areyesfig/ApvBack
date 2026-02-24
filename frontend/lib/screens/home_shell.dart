import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app.dart';
import 'input_screen.dart';
import 'chart_screen.dart';
import 'fiscal_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutExpo,
    );
  }

  static const _tabs = [
    _TabData(icon: Icons.tune_rounded, label: 'Datos'),
    _TabData(icon: Icons.insights_rounded, label: 'Proyeccion'),
    _TabData(icon: Icons.receipt_long_rounded, label: 'Resumen'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      body: Stack(
        children: [
          // Orbes de fondo animados
          const _BackgroundOrbs(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    onPageChanged: (i) => setState(() => _index = i),
                    children: const [
                      InputScreen(),
                      ChartScreen(),
                      FiscalScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Barra inferior con glass effect
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildGlassNavBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          // Logo con glow
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kAccent, Color(0xFF00B880)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: kAccent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: kBgDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'APV Simulator',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: kAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Regimen A, B y Mix',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: kTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassNavBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomPadding),
          decoration: BoxDecoration(
            color: kBgDeep.withValues(alpha: 0.85),
            border: const Border(
              top: BorderSide(color: kBorderGlass, width: 1),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: kBgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorderGlass),
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final isSelected = _index == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onTabTapped(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutExpo,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  kAccent.withValues(alpha: 0.15),
                                  kAccent.withValues(alpha: 0.05),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutExpo,
                            child: Icon(
                              _tabs[i].icon,
                              size: 22,
                              color: isSelected ? kAccent : kTextMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tabs[i].label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? kAccent : kTextMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: isSelected ? 20 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              color: kAccent,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: kAccent.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabData {
  const _TabData({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Orbes de fondo con gradientes suaves para dar profundidad.
class _BackgroundOrbs extends StatelessWidget {
  const _BackgroundOrbs();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  kAccent.withValues(alpha: 0.08),
                  kAccent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 300,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  kAccent2.withValues(alpha: 0.06),
                  kAccent2.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  kChartEtf.withValues(alpha: 0.04),
                  kChartEtf.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
