import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

/// White dialog shell: tinted icon, title, message, then a row of buttons.
class KcDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;
  const KcDialog({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.iconColor = kcAccentOrange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kcSurfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kcRadiusLg),
        side: const BorderSide(color: kcStrokeColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 16),
              Text(title, style: kcTitleStyle),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 15,
                  height: 1.5,
                  color: kcTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Button for [KcDialog]. [primary] = solid fill, otherwise outlined.
class KcDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final Color color;
  const KcDialogButton({
    Key? key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.color = kcAccentOrange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? color : kcSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kcRadiusSm),
        side: primary
            ? BorderSide.none
            : const BorderSide(color: kcStrokeColorStrong),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(kcRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 16,
              fontWeight: primary ? FontWeight.w500 : FontWeight.w400,
              color: primary ? Colors.white : kcTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Yes/no dialog. Resolves to true only when the confirm button is pressed.
/// [destructive] paints the confirm button red (cancel order, clear cart).
Future<bool> showKcConfirm(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.help_outline_rounded,
  String cancelLabel = 'ยกเลิก',
  String confirmLabel = 'ตกลง',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => KcDialog(
      icon: icon,
      iconColor: destructive ? kcDangerColor : kcAccentOrange,
      title: title,
      message: message,
      actions: [
        KcDialogButton(
          label: cancelLabel,
          onTap: () => Navigator.of(ctx).pop(false),
        ),
        KcDialogButton(
          label: confirmLabel,
          primary: true,
          color: destructive ? kcDangerColor : kcAccentOrange,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
