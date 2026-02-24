import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../state/onboarding_provider.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

/// Pantalla raíz: onboarding la primera vez, luego HomeShell.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneAsync = ref.watch(onboardingDoneProvider);
    return doneAsync.when(
      data: (done) => done ? const HomeShell() : const OnboardingScreen(),
      loading: () => const Scaffold(
        backgroundColor: kBgDeep,
        body: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
          ),
        ),
      ),
      error: (_, __) => const HomeShell(),
    );
  }
}
