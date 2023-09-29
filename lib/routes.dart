import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Login/login_screen.dart';
import 'package:kacee_pos/Screen/Welcome/welcome_screen.dart';

final routes = {
  '/': (BuildContext context) => const WelcomeScreen(),
  '/home': (BuildContext context) => const WelcomeScreen(),
  '/login': (BuildContext context) => const LoginScreen(),
};
