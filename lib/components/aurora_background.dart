import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

/// Plain white backdrop shared by every screen. The name is kept from the
/// old dark "Aurora" theme so the per-screen Background widgets don't change.
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
    return Container(color: kcInkColor, child: child);
  }
}

/// Flat white card with a 1px light-grey stroke.
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
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kcStrokeColor, width: 1),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}
