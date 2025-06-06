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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      width: size.width * 0.25,
      decoration: BoxDecoration(
        color: kcPrimaryLightColor,
        borderRadius: BorderRadius.circular(29),
      ),
      child: child
    );
  }
}
