// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:kacee_pos/Screen/Pos/main_screen.dart';
import 'package:kacee_pos/components/rounded_text_input.dart';
import 'package:kacee_pos/constants.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kacee_pos/network_utils/api.dart';
import 'package:kacee_pos/Screen/login/components/background.dart';
import 'package:kacee_pos/components/rounded_password_input.dart';
import 'package:kacee_pos/components/rounded_button.dart';
import 'package:kacee_pos/components/dailog_container.dart';
import 'package:kacee_pos/model/user_login.dart';

class Body extends StatefulWidget {
  const Body({Key? key}) : super(key: key);

  @override
  State<Body> createState() => _LoginState();
}

class _LoginState extends State<Body> {
  // ignore: unused_field
  bool _isLoading = false;
  final now = DateTime.now();
  Userlogin userlogin = Userlogin(
      email: 'pos03',
      password: '',
      is_role: '1',
      order_date: '',
      status_date: '1');

  void _showAlertDialog(BuildContext context, String message) {
    AlertDailogBox alert = AlertDailogBox(
      title: "แจ้งเตือน",
      content: message,
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void _signIn(String email, String password, String is_role, String order_date,
      String status_date) async {
    if (password.isEmpty || email.isEmpty) {
      var message = "กรุณาใส่ข้อมูลให้ครบถ้วน";
      return _showAlertDialog(context, message);
    } else {
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      // Map data = {'email': '550097', 'password': 'k'};
      Map data = {
        'email': 'pos03',
        'password': password,
        'is_role': '1',
        'order_date': DateFormat('yyyy-MM-dd').format(now),
        'status_date': '1'
      };
      var response = await Network().getLogin(data);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        // var id = jsonResponse['data']['id'];
        if (jsonResponse != null) {
          setState(() {
            _isLoading = false;
          });
          sharedPreferences.setString("token", jsonResponse['data']['token']);
          sharedPreferences.setString(
              "id", jsonResponse['data']['user']['id'].toString());
          sharedPreferences.setString(
              "shop_code", jsonResponse['data']['user']['shop_code']);
          sharedPreferences.setString("machine_code", jsonResponse['data']['user']['machine_code']);
          sharedPreferences.setString(
              "mac_printer", jsonResponse['data']['user']['mac_printer']);
          Navigator.push(
            context,
            PageTransition(
                type: PageTransitionType.fade,
                child: const MainScreen(),
                inheritTheme: true,
                ctx: context),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        var message = "ไม่พบข้อมูลสิทธิผู้ใช้งาน";
        _showAlertDialog(context, message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Background(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "ยินดีต้อนรับเข้าสู่ ระบบชำระเงิน",
              style: TextStyle(
                  fontWeight: FontWeight.w200,
                  fontSize: 30,
                  color: Colors.white),
            ),
            SizedBox(height: size.height * 0.05),
            // SvgPicture.asset(
            //   "assets/icons/login.svg",
            //   height: size.height * 0.40,
            // ),
            Image.asset("assets/icons/login.png",scale: 1.4,),
            SizedBox(height: size.height * 0.05),
            RoundedInputField(
              hintText: 'Username',
              icon: iconA,
              onChanged: (value) {
                userlogin.email = value;
              },
            ),
            SizedBox(height: size.height * 0.01),
            RoundedPasswordField(
              maxLength: 12,
              onChanged: (value) {
                userlogin.password = value;
              },
            ),
            SizedBox(height: size.height * 0.03),
            RoundedButton(
              text: "เข้าสู่ระบบ",
              press: () async {
                _signIn(userlogin.email, userlogin.password, userlogin.is_role,
                    userlogin.order_date, userlogin.status_date);
              },
            ),
          ],
        ),
      ),
    );
  }
}
