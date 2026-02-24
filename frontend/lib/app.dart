import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/root_screen.dart';

// ── Paleta Dark Premium ──────────────────────────────────────────────
const kBgDeep = Color(0xFF0A0E1A);
const kBgCard = Color(0xFF131825);
const kBgCardLight = Color(0xFF1A2035);
const kSurfaceGlass = Color(0x1AFFFFFF); // 10% white
const kBorderGlass = Color(0x1AFFFFFF);

const kAccent = Color(0xFF00E5A0); // verde neón
const kAccentSoft = Color(0xFF00C98D);
const kAccent2 = Color(0xFF6C63FF); // púrpura vibrante
const kAccent3 = Color(0xFFFF6B6B); // coral cálido

const kTextPrimary = Color(0xFFF0F2F5);
const kTextSecondary = Color(0xFF8B95A5);
const kTextMuted = Color(0xFF5A6577);

const kChartApv = Color(0xFF00E5A0);
const kChartEtf = Color(0xFFFF9F43);
const kChartColchon = Color(0xFF5A6577);

class ApvApp extends StatelessWidget {
  const ApvApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: kBgDeep,
      ),
    );

    return MaterialApp(
      title: 'APV Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBgDeep,
        colorScheme: const ColorScheme.dark(
          primary: kAccent,
          onPrimary: kBgDeep,
          secondary: kAccent2,
          surface: kBgCard,
          onSurface: kTextPrimary,
          onSurfaceVariant: kTextSecondary,
          outline: kBorderGlass,
          error: kAccent3,
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          ThemeData.dark().textTheme,
        ).copyWith(
          headlineLarge: GoogleFonts.spaceGrotesk(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: kTextPrimary,
          ),
          headlineMedium: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: kTextPrimary,
          ),
          titleLarge: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: kTextPrimary,
          ),
          titleMedium: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 15,
            color: kTextPrimary,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 13,
            color: kTextSecondary,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 11,
            color: kTextMuted,
          ),
          labelLarge: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: kTextPrimary,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: kBgCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kBorderGlass, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
        ),
        dividerColor: kBorderGlass,
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kAccent,
          linearTrackColor: kBgCardLight,
        ),
      ),
      home: const RootScreen(),
    );
  }
}

class ApvChartColors {
  static const colchon = kChartColchon;
  static const etf = kChartEtf;
  static const apv = kChartApv;
}
