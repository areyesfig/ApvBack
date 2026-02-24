import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/history_storage.dart';

final onboardingDoneProvider = FutureProvider<bool>((ref) => getOnboardingDone());

Future<void> completeOnboarding() => setOnboardingDone();
