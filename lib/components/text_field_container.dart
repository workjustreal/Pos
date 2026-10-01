import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

class TextFieldContainer extends StatelessWidget {
  final Widget child;
  const TextFieldContainer({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      width: size.width * 0.28,
      decoration: BoxDecoration(
        color: kcSurfaceColorHi.withOpacity(0.85),
        borderRadius: BorderRadius.circular(kcRadiusPill),
        border: Border.all(color: kcStrokeColor, width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
