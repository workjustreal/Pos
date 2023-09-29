import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Welcome/components/body.dart';
import 'package:kacee_pos/constants.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kcBackgroundColor,
      body: Body(),
    );
  }
}
