import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TfcColors {
  static const Color background = Color(0xFF030406); // Darker base background
  static const Color surfaceDim = Color(0xFF0C0E12); // Deep premium navy-dark surface
  static const Color surfaceContainer = Color(0xFF13171E); 
  static const Color surfaceContainerHigh = Color(0xFF1B202A);
  
  static const Color primary = Color(0xFF00F5D4); // Electric Cyan
  static const Color onPrimary = Color(0xFF00382F);
  static const Color primaryContainer = Color(0xFFD7FFF3);
  
  static const Color secondary = Color(0xFFFFB1C2); // Soft Magenta
  static const Color onSecondary = Color(0xFF66002B);
  
  static const Color onSurface = Color(0xFFE2E2E8);
  static const Color onSurfaceVariant = Color(0xFF8E9BA5); // Cooler grey tint
  static const Color outline = Color(0xFF4A5568); // Slate grey outline
  
  static const Color error = Color(0xFFFFB4AB);
  static const Color success = Color(0xFF00F5D4);
  static const Color warning = Color(0xFFFFB1C2);
}

class TfcTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: TfcColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: TfcColors.primary,
        onPrimary: TfcColors.onPrimary,
        secondary: TfcColors.secondary,
        onSecondary: TfcColors.onSecondary,
        surface: TfcColors.surfaceDim,
        onSurface: TfcColors.onSurface,
        error: TfcColors.error,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TfcColors.surfaceDim.withValues(alpha: 0.92),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 44,
          fontWeight: FontWeight.bold,
          color: TfcColors.primaryContainer,
          letterSpacing: -0.02,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: TfcColors.primary,
          letterSpacing: -0.01,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: TfcColors.onSurface,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: TfcColors.onSurface,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: TfcColors.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: TfcColors.primary,
          letterSpacing: 0.05,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF13171E).withValues(alpha: 0.8), // Dark inputs as requested
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        labelStyle: GoogleFonts.inter(color: TfcColors.onSurfaceVariant),
        floatingLabelStyle: GoogleFonts.inter(color: TfcColors.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1C222E), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1C222E), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TfcColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// =============================================================================
// GLOBAL GLASS BACKGROUND
// =============================================================================

class TfcGlassBackground extends StatelessWidget {
  final Widget child;

  const TfcGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TfcColors.background,
      ),
      child: Stack(
        children: [
          // Radial Top Glow
          Positioned(
            top: -150,
            left: MediaQuery.sizeOf(context).width * 0.25,
            child: Container(
              width: 600,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TfcColors.primary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Subtle Centered Watermark Logo (non-intrusive)
          Center(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.04,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: MediaQuery.sizeOf(context).width * 0.45,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

// =============================================================================
// INTERACTIVE GLOW WIDGET - Hover effect for neon glow
// =============================================================================

class InteractiveGlowWidget extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final VoidCallback? onTap;

  const InteractiveGlowWidget({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  State<InteractiveGlowWidget> createState() => _InteractiveGlowWidgetState();
}

class _InteractiveGlowWidgetState extends State<InteractiveGlowWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                    ? TfcColors.primary.withValues(alpha: 0.15) 
                    : Colors.transparent,
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: AnimatedScale(
            scale: _isHovered ? 1.015 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// GLASS CARD
// =============================================================================

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final Color borderColor;
  final Color fillColor;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 0,
    this.borderRadius = 12,
    this.borderColor = const Color(0xFF1E2633), // Subtle solid border color
    this.fillColor = const Color(0xFF0F1217), // Deep dark surface matching design
    this.shadow,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(24),
      child: child,
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: shadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: blur > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: content,
              )
            : content,
      ),
    );
  }
}

// =============================================================================
// GLASS SIDEBAR
// =============================================================================

class GlassSidebar extends StatelessWidget {
  final Widget child;
  final double width;

  const GlassSidebar({
    super.key,
    required this.child,
    this.width = 260,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF06080A), // Extremely deep flat dark sidebar matching theme
        border: Border(
          right: BorderSide(
            color: Color(0xFF14181F),
            width: 1,
          ),
        ),
      ),
      child: child,
    );
  }
}

// =============================================================================
// GLASS BOTTOM NAV BAR
// =============================================================================

class GlassBottomNavBar extends StatelessWidget {
  final Widget child;

  const GlassBottomNavBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF06080A),
        border: Border(
          top: BorderSide(
            color: Color(0xFF14181F),
            width: 1,
          ),
        ),
      ),
      child: child,
    );
  }
}

// =============================================================================
// GLASS APP BAR
// =============================================================================

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;

  const GlassAppBar({super.key, this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF06080A),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF14181F),
            width: 1,
          ),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: title,
        actions: actions,
      ),
    );
  }
}
