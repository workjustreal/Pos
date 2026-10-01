import 'package:flutter/material.dart';
import 'package:kacee_pos/components/aurora_background.dart';

class Background extends StatelessWidget {
  final Widget child;
  const Background({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(child: child);
  }
}
