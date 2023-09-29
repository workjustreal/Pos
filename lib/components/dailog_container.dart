import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kacee_pos/constants.dart';

class AlertDailogBox extends StatelessWidget {
  final String title;
  final String content;
  final Color color, textColor;
  // final VoidCallback continueCallBack;

  const AlertDailogBox({
    Key? key,
    required this.title,
    required this.content,
    // required this.continueCallBack,
    this.color = kcPrimaryColor,
    this.textColor = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: AlertDialog(
          shape: const RoundedRectangleBorder( borderRadius: BorderRadius.all(Radius.circular(20.0))),
          title: Text(
            title,
            style:
                TextStyle(color: color, fontSize: 20, fontFamily: 'Kanit',),
          ),
          content: Text(
            content,
            style:
                TextStyle(color: textColor, fontSize: 15, fontFamily: 'Kanit', height: 2.5),
          ),
          actions: <Widget>[
            InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                width: 270,
                padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                decoration: const BoxDecoration(
                  color: kcPrimaryColor,
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20.0),
                      bottomRight: Radius.circular(20.0)),
                ),
                child: const Text("ตกลง",
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ));
  }
}
