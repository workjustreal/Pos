import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Pos/components/background.dart';
import 'package:kacee_pos/Screen/Pos/main_screen.dart';
import 'package:kacee_pos/components/rounded_button.dart';
import 'package:kacee_pos/components/rounded_button_home.dart';
import 'package:kacee_pos/constants.dart';

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
    _startTimer();
  }

  Future<bool> showExitPopup() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('แจ้งเตือน'),
            content: const Text('คุณต้องการกลับไปแก้ไขรายการสินค้าใช่หรือไม่?'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.white),
                    backgroundColor:
                        MaterialStateProperty.all<Color>(Colors.green),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            side: const BorderSide(color: Colors.green)))),
                child: const Text('ไม่'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.white),
                    backgroundColor:
                        MaterialStateProperty.all<Color>(Colors.red),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            side: const BorderSide(color: Colors.red)))),
                child: const Text('ใช่'),
              ),
            ],
          ),
        ) ??
        false;
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
      setState(() {
        _currentSecond = timer.tick;
        if (timer.tick >= _maxSeconds) {
          timer.cancel();
          setState(() {
            Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (BuildContext context) {
              return const MainScreen();
            }), (r) {
              return false;
            });
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return WillPopScope(
      onWillPop: showExitPopup,
      child: Scaffold(
        backgroundColor: kcDarkColor,
        body: Background(
          child: SingleChildScrollView(
            child: Opacity(
              opacity: 1,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            SizedBox(height: size.height * 0.25),
                            RoundedButtonHome(press: () {}),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 20,
                        child: Column(children: [
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.only(top: 300),
                            child: Column(
                              children: [
                                SizedBox(height: size.height * 0.01),
                                const Text(
                                  "KACEE ขอบคุณท่านที่มาใช้บริการ",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w200,
                                      fontSize: 20,
                                      color: Colors.white),
                                ),
                                SizedBox(height: size.height * 0.01),
                                const Text(
                                  "THANK YOU",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w200,
                                      fontSize: 30,
                                      color: Colors.white),
                                ),
                                SizedBox(height: size.height * 0.04),
                                RoundedButton(
                                  text: "กลับสู่หน้าหลัก $_timerText",
                                  press: () {
                                    Navigator.pushAndRemoveUntil(context,
                                        MaterialPageRoute(
                                            builder: (BuildContext context) {
                                      return const MainScreen();
                                    }), (r) {
                                      return false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
