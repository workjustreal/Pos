import 'package:flutter/material.dart';
import 'package:kacee_pos/components/a3_dialog.dart';
import 'package:kacee_pos/constants.dart';

/// Single-button information dialog ("แจ้งเตือน" + message + ตกลง).
class AlertDailogBox extends StatelessWidget {
  final String title;
  final String content;
  final Color color, textColor;

  const AlertDailogBox({
    Key? key,
    required this.title,
    required this.content,
    this.color = kcPrimaryColor,
    this.textColor = kcTextPrimary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return KcDialog(
      icon: Icons.info_outline_rounded,
      iconColor: color,
      title: title,
      message: content,
      actions: [
        KcDialogButton(
          label: 'ตกลง',
          primary: true,
          color: color,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
