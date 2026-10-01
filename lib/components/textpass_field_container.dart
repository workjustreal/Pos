import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

/// White input box with a 1px stroke. Fills the width its parent gives it.
class TextFieldContainer extends StatelessWidget {
  final Widget child;
  const TextFieldContainer({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      width: double.infinity,
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(kcRadiusMd),
        border: Border.all(color: kcStrokeColorStrong, width: 1),
      ),
      child: child,
    );
  }
}
