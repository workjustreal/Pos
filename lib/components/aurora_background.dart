import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

/// Atmospheric ink-black backdrop with two soft aurora blobs (orange + pink)
/// in opposite corners. Reused across every screen so the app feels cohesive.
class AuroraBackground extends StatelessWidget {
  final Widget child;
  final bool dimmer;
  const AuroraBackground({
    Key? key,
    required this.child,
    this.dimmer = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kcInkColor, kcInkColorSoft, kcInkColor],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Aurora blob — top-left (orange)
          Positioned(
            top: -160,
            left: -120,
            child: _Blob(
              size: 460,
              color: kcAccentOrange.withOpacity(dimmer ? 0.10 : 0.18),
            ),
          ),
          // Aurora blob — bottom-right (pink)
          Positioned(
            bottom: -180,
            right: -140,
            child: _Blob(
              size: 520,
              color: kcAccentPink.withOpacity(dimmer ? 0.08 : 0.16),
            ),
          ),
          // Subtle vertical sheen down the middle
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.02),
                      Colors.transparent,
                      Colors.black.withOpacity(0.15),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({Key? key, required this.size, required this.color})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// Reusable frosted glass card surface.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final List<BoxShadow>? boxShadow;
  const GlassCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = kcRadiusLg,
    this.boxShadow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: kcGlassGradient,
        color: kcSurfaceColor.withOpacity(0.55),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kcStrokeColor, width: 1),
        boxShadow: boxShadow ?? kcShadowSoft,
      ),
      child: child,
    );
  }
}
