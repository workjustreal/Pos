import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

// Building blocks for the A3 layout: a thin top bar, then a fixed-width side
// panel (the "spotlight" column) next to the main content.

/// Top bar: orange dot + KACEEPOS wordmark, an optional section name
/// ("/ ชำระเงิน"), then right-aligned [actions] and [info] text.
class KcTopBar extends StatelessWidget {
  final String? section;
  final String? info;
  final List<Widget> actions;
  // Hidden staff action: fires after holding the logo for 2 seconds.
  final VoidCallback? onLogoLongPress;
  const KcTopBar({
    Key? key,
    this.section,
    this.info,
    this.actions = const [],
    this.onLogoLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: kcSurfaceColor,
        border: Border(bottom: BorderSide(color: kcStrokeColor)),
      ),
      child: Row(
        children: [
          _logo(),
          if (section != null) ...[
            const SizedBox(width: 10),
            Text(
              '/ $section',
              style: const TextStyle(
                  fontFamily: 'Kanit', fontSize: 16, color: kcTextMuted),
            ),
          ],
          const Spacer(),
          for (final a in actions) ...[a, const SizedBox(width: 8)],
          if (info != null) ...[
            const SizedBox(width: 8),
            Text(
              info!,
              softWrap: false,
              style: const TextStyle(
                  fontFamily: 'Kanit', fontSize: 13, color: kcTextMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _logo() {
    const logo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KcDot(size: 10),
        SizedBox(width: 10),
        Text(
          'KACEEPOS',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
            color: kcTextPrimary,
          ),
        ),
      ],
    );
    if (onLogoLongPress == null) return logo;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
              duration: const Duration(seconds: 2)),
          (r) => r.onLongPress = onLogoLongPress,
        ),
      },
      child: logo,
    );
  }
}

/// Side panel + main content. The side panel takes ~32% of the width
/// (clamped so it stays usable on both 10" and 15.6" kiosks).
class KcSplitLayout extends StatelessWidget {
  final Widget side;
  final Widget main;
  final Color sideColor;
  const KcSplitLayout({
    Key? key,
    required this.side,
    required this.main,
    this.sideColor = kcSurfaceColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sideWidth = (constraints.maxWidth * 0.32).clamp(320.0, 480.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: sideWidth,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sideColor,
              border: const Border(right: BorderSide(color: kcStrokeColor)),
            ),
            child: side,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: main,
            ),
          ),
        ],
      );
    });
  }
}

class KcDot extends StatelessWidget {
  final double size;
  final Color color;
  const KcDot({Key? key, this.size = 8, this.color = kcAccentOrange})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Small grey caption that sits above a card ("เพิ่งสแกน", "สรุปการชำระเงิน").
class KcSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const KcSectionLabel(this.text, {Key? key, this.trailing}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: kcLabelStyle)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Label on the left, value on the right ("จำนวน ........ 10 ชิ้น").
class KcInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const KcInfoRow(this.label, this.value, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Kanit', fontSize: 14, color: kcTextPrimary)),
        ],
      ),
    );
  }
}

/// Solid orange button — the one primary action on a screen.
class KcPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  const KcPrimaryButton({
    Key? key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 64,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: kcAccentOrange,
        borderRadius: BorderRadius.circular(kcRadiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(kcRadiusMd),
          onTap: onTap,
          splashColor: Colors.white24,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin-bordered secondary button (header actions, cancel, back to home).
class KcOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry padding;
  const KcOutlineButton({
    Key? key,
    required this.label,
    this.icon,
    this.onTap,
    this.color = kcTextSecondary,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kcSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kcRadiusSm),
        side: const BorderSide(color: kcStrokeColorStrong),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(kcRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontFamily: 'Kanit', fontSize: 14, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin progress bar used for countdowns and the receipt print status.
/// [value] null = indeterminate.
class KcProgressBar extends StatelessWidget {
  final double? value;
  final Color color;
  const KcProgressBar({Key? key, this.value, this.color = kcAccentOrange})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: const Color(0xFFF1F1F1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
