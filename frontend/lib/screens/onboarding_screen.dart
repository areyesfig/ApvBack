import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app.dart';
import '../state/onboarding_provider.dart';
import 'home_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.savings_rounded,
      title: 'Régimen A',
      body: 'Bonificación estatal del 15% sobre tu ahorro APV, con tope de 6 UTM anuales. Ideal si tu renta es más baja.',
    ),
    _OnboardingPage(
      icon: Icons.account_balance_rounded,
      title: 'Régimen B',
      body: 'Tu aporte APV se descuenta de la base imponible del Impuesto Global Complementario. Suele convenir más si ganas más.',
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome_rounded,
      title: 'Mix y pestañas',
      body: 'Datos: ajusta sueldo, edad y aportes. Proyección: gráfico de capital a jubilación. Resumen: devolución SII y mejor régimen.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kAccent.withValues(alpha: 0.2), kAccent2.withValues(alpha: 0.1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(p.icon, size: 56, color: kAccent),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          p.title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p.body,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.5,
                            color: kTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Row(
                children: [
                  ...List.generate(_pages.length, (i) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: _page == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i ? kAccent : kTextMuted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _page == _pages.length - 1 ? _finish : () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    icon: Icon(_page == _pages.length - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded),
                    label: Text(_page == _pages.length - 1 ? 'Empezar' : 'Siguiente'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: kBgDeep,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}
