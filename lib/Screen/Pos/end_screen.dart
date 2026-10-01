import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Pos/components/background.dart';
import 'package:kacee_pos/Screen/Pos/main_screen.dart';
import 'package:kacee_pos/components/rounded_button.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/services/tts_service.dart';

class EndScreen extends StatefulWidget {
  const EndScreen({Key? key}) : super(key: key);
  @override
  State<EndScreen> createState() => _EndState();
}

class _EndState extends State<EndScreen> {
  final ScrollController scollBarController = ScrollController();
  final _maxSeconds = 10;
  int _currentSecond = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Spoken thank-you when the order is complete.
    TtsService().speak("ขอบคุณที่ใช้บริการ");
    _startTimer();
  }

  void _goHome() {
    _timer.cancel();
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false);
  }

  /// Back button: the sale is complete, so go straight to the cart screen.
  /// This screen is the only route on the stack — letting the pop through
  /// used to close the app.
  Future<bool> _onBackPressed() async {
    _goHome();
    return false;
  }

  String get _timerText {
    const secondsPerMinute = 60;
    final secondsLeft = _maxSeconds - _currentSecond;

    final formattedMinutesLeft =
        (secondsLeft ~/ secondsPerMinute).toString().padLeft(2, '0');
    final formattedSecondsLeft =
        (secondsLeft % secondsPerMinute).toString().padLeft(2, '0');

    return '$formattedMinutesLeft : $formattedSecondsLeft';
  }

  void _startTimer() {
    const duration = Duration(seconds: 1);
    _timer = Timer.periodic(duration, (Timer timer) {
      if (!mounted) return;
      setState(() {
        _currentSecond = timer.tick;
      });
      if (timer.tick >= _maxSeconds) {
        _goHome();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        backgroundColor: kcInkColor,
        body: Background(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Success badge with halo
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            kcAccentOrange.withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: kcBrandGradient,
                            boxShadow: kcShadowGlow,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: kcSurfaceColorHi.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(kcRadiusPill),
                        border: Border.all(color: kcStrokeColor),
                      ),
                      child: const Text(
                        "ชำระเงินสำเร็จ",
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          color: kcSuccessColor,
                          fontSize: 12,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          kcBrandGradient.createShader(bounds),
                      child: const Text(
                        "THANK  YOU",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontWeight: FontWeight.w600,
                          fontSize: 56,
                          height: 1.0,
                          letterSpacing: 4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "KACEE ขอบคุณท่านที่มาใช้บริการ",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 18,
                        color: kcTextSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 36),
                    RoundedButton(
                      text: "กลับสู่หน้าหลัก  $_timerText",
                      press: _goHome,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "ระบบจะกลับหน้าหลักอัตโนมัติ",
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 12,
                        color: kcTextMuted.withOpacity(0.7),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
