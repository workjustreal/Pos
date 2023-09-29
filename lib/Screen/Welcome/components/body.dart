import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Welcome/components/background.dart';
import 'package:kacee_pos/Screen/login/login_screen.dart';
import 'package:kacee_pos/components/rounded_button.dart';
import 'package:page_transition/page_transition.dart';

class Body extends StatelessWidget {
  const Body({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Background(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "KACEE SELF CHECKOUT",
              style: TextStyle(
                  fontWeight: FontWeight.w200,
                  fontSize: 35,
                  color: Colors.white),
            ),
            SizedBox(height: size.height * 0.1),
            Container(
              alignment: Alignment.center,
              child: Image.asset(
                "assets/images/welcome.png",
              ),
            ),
            SizedBox(height: size.height * 0.1),
            RoundedButton(
              text: "เริ่มใช้งาน",
              press: () {
                Navigator.push(
                  context,
                  PageTransition(
                      type: PageTransitionType.fade,
                      child: const LoginScreen(),
                      inheritTheme: true,
                      ctx: context),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
