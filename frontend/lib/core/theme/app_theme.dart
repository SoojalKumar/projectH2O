import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hydra design system — editorial premium minimal.
///
/// Hairline edges over heavy shadows. Deep, restrained primary. Severity
/// colors only when they carry signal. Typography drives hierarchy. 4px grid.

class AppColors {
  // Brand — deeper, more sophisticated teal
  static const Color primary = Color(0xFF0E3A4A);
  static const Color primaryDark = Color(0xFF052631);
  static const Color primarySoft = Color(0xFFE8EEF1);
  static const Color accent = Color(0xFF3FBFA5);

  // Surfaces — cooler, cleaner
  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF1F4F7);
  static const Color surfaceDeep = Color(0xFF09131C);

  // Type — three-level hierarchy
  static const Color textPrimary = Color(0xFF0E1A24);
  static const Color textSecondary = Color(0xFF5C6B78);
  static const Color textTertiary = Color(0xFFA0ADB7);

  // Hairlines — barely visible, used for separation not decoration
  static const Color border = Color(0xFFE8ECEF);
  static const Color divider = Color(0xFFEEF2F4);

  // Severity — slightly muted, never neon
  static const Color success = Color(0xFF15936A);
  static const Color warning = Color(0xFFC27D15);
  static const Color danger = Color(0xFFC24343);

  // Data viz palette — coordinated for light surfaces
  static const Color chartSnow = Color(0xFF67B4D8);
  static const Color chartPrecip = Color(0xFF3FBFA5);
  static const Color chartReservoir = Color(0xFFD89230);
}

class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 36;
  static const double large = 48;
}

class AppRadius {
  static const double chip = 8;
  static const double button = 10;
  static const double input = 10;
  static const double card = 14;
  static const double cardLarge = 18;
  static const double hero = 20;
}

/// Editorial card decoration — 1px hairline + barely-there shadow.
const cardShadow = [
  BoxShadow(
    color: Color(0x05000000),
    blurRadius: 1,
    offset: Offset(0, 1),
  ),
  BoxShadow(
    color: Color(0x07000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

const heroShadow = [
  BoxShadow(
    color: Color(0x140E3A4A),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
];

/// Use this for any card that wants the hairline edge treatment.
const Border cardBorder = Border.fromBorderSide(
  BorderSide(color: AppColors.border, width: 1),
);

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    final textTheme = inter.copyWith(
      displayLarge: inter.displayLarge?.copyWith(
        fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -1.6, height: 1.0,
      ),
      displayMedium: inter.displayMedium?.copyWith(
        fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.2, height: 1.0,
      ),
      displaySmall: inter.displaySmall?.copyWith(
        fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.05,
      ),
      headlineMedium: inter.headlineMedium?.copyWith(
        fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2,
      ),
      titleMedium: inter.titleMedium?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1,
      ),
      titleSmall: inter.titleSmall?.copyWith(
        fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: -0.05,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.55,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.55,
        color: AppColors.textPrimary,
      ),
      bodySmall: inter.bodySmall?.copyWith(
        fontSize: 11.5, fontWeight: FontWeight.w400, height: 1.5,
        color: AppColors.textSecondary,
      ),
      labelLarge: inter.labelLarge?.copyWith(
        fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.1,
      ),
      labelMedium: inter.labelMedium?.copyWith(
        fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.6,
        color: AppColors.textTertiary,
      ),
      labelSmall: inter.labelSmall?.copyWith(
        fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.6,
        color: AppColors.textTertiary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleSpacing: AppSpace.lg,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary, size: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        indicatorColor: AppColors.primary.withOpacity(0.08),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium?.copyWith(
          fontSize: 11, color: AppColors.primary, letterSpacing: 0.4,
          fontWeight: FontWeight.w600,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return const IconThemeData(color: AppColors.textTertiary, size: 22);
        }),
      ),
      dividerColor: AppColors.divider,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearMinHeight: 3,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

/// Standard letter-spaced uppercase section heading.
class SectionLabel extends StatelessWidget {
  final String label;
  const SectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
      );
}
