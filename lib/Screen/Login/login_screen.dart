import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Login/components/body.dart';
import 'package:kacee_pos/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kcBackgroundColor,
      body:  Body(),
    );
  }
}
