import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/routes.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KACEEPOS 2.0',
      theme: ThemeData(
        fontFamily: 'Kanit',
        primaryColor: kcPrimaryColor,
        scaffoldBackgroundColor: kcInkColor,
        colorScheme: const ColorScheme.dark(
          primary: kcPrimaryColor,
          secondary: kcAccentPink,
          surface: kcSurfaceColor,
          background: kcInkColor,
        ),
      ),
      routes: routes,
    );
    // flutter build apk --target-platform android-arm,android-arm64 --split-per-abi
    // flutter build apk --build-name=1.0 --build-number=1
  }
}