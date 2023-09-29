import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Welcome/components/background.dart';

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
              "MAIN",
              style: TextStyle(fontWeight: FontWeight.w200, fontSize: 40,color: Colors.white),
            ),
            SizedBox(height: size.height * 0.1),
          ],
        ),
      ),
    );
  }
}
