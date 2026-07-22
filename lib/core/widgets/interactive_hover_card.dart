import 'package:flutter/material.dart';

class InteractiveHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? glowColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;

  const InteractiveHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.glowColor,
    this.padding,
    this.margin,
    this.backgroundColor,
  });

  @override
  State<InteractiveHoverCard> createState() => _InteractiveHoverCardState();
}

class _InteractiveHoverCardState extends State<InteractiveHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? BorderRadius.circular(16);
    final themeGlow = widget.glowColor ?? const Color(0xFF6C5CE7);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: widget.margin,
          padding: widget.padding,
          transform: _isHovered ? (Matrix4.identity()..translate(0.0, -4.0, 0.0)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? const Color(0xFF1E1E38).withValues(alpha: 0.75),
            borderRadius: effectiveBorderRadius,
            border: Border.all(
              color: _isHovered ? themeGlow.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.12),
              width: _isHovered ? 1.8 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: themeGlow.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
