import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/Screen/Pos/main_screen.dart';

class AlertDailogBoxWarning extends StatelessWidget {
  final String title;
  final String content;
  final Color color, textColor;
  final Function tap;
  // final VoidCallback continueCallBack;

  const AlertDailogBoxWarning({
    Key? key,
    required this.title,
    required this.content,
    required this.tap,
    // required this.continueCallBack,
    this.color = kcPrimaryColor,
    this.textColor = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: AlertDialog(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20.0))),
          titlePadding: const EdgeInsets.all(0),
          title: Container(
            decoration: const BoxDecoration(
              color: kcSecondaryColor,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.0),
                  topRight: Radius.circular(10.0),
                  bottomLeft: Radius.circular(0.0),
                  bottomRight: Radius.circular(0.0)),
            ),
            height: 50,
            child: Container(
              margin: const EdgeInsets.only(top: 12.0),
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          content: Text(
            content,
            style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontFamily: 'Kanit',
                height: 2.5),
          ),
          actions: <Widget>[
            InkWell(
              onTap: () => tap(),
              child: Container(
                width: 100,
                padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
                child: const Text(
                  "ชำระเงินอีกครั้ง",
                  style: TextStyle(color: Colors.black, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            InkWell(
              onTap: () => tap(),
              child: Container(
                width: 100,
                padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
                child: const Text(
                  "ยกเลิกคำสั่งซิ้อ",
                  style: TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ));
  }
}
