// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
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
      email: 'pos01',
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
      Map data = {
        'email': 'pos01',
        'password': password,
        'is_role': '1',
        'order_date': DateFormat('yyyy-MM-dd').format(now),
        'status_date': '1'
      };
      var response = await Network().getLogin(data);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse != null) {
          setState(() {
            _isLoading = false;
          });
          sharedPreferences.setString("token", jsonResponse['data']['token']);
          sharedPreferences.setString(
              "id", jsonResponse['data']['user']['id'].toString());
          sharedPreferences.setString(
              "shop_code", jsonResponse['data']['user']['shop_code']);
          sharedPreferences.setString(
              "machine_code", jsonResponse['data']['user']['machine_code']);
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
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
              decoration: BoxDecoration(
                gradient: kcGlassGradient,
                color: kcSurfaceColor.withOpacity(0.6),
                borderRadius: BorderRadius.circular(kcRadiusXl),
                border: Border.all(color: kcStrokeColor, width: 1),
                boxShadow: kcShadowSoft,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: kcBrandGradientSoft,
                      borderRadius: BorderRadius.circular(kcRadiusPill),
                      border:
                          Border.all(color: kcAccentOrange.withOpacity(0.3)),
                    ),
                    child: const Text(
                      "เข้าสู่ระบบ",
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        color: kcAccentOrange,
                        fontSize: 12,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "ยินดีต้อนรับ",
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontWeight: FontWeight.w300,
                      fontSize: 32,
                      color: kcTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "ระบบชำระเงินด้วยตัวเอง",
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 14,
                      color: kcTextSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),
                  Image.asset(
                    "assets/icons/login.png",
                    height: size.height * 0.22,
                  ),
                  SizedBox(height: size.height * 0.02),
                  RoundedInputField(
                    hintText: 'Username',
                    icon: iconA,
                    onChanged: (value) {
                      userlogin.email = value;
                    },
                  ),
                  RoundedPasswordField(
                    maxLength: 12,
                    onChanged: (value) {
                      userlogin.password = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  RoundedButton(
                    text: "เข้าสู่ระบบ",
                    press: () async {
                      _signIn(
                          userlogin.email,
                          userlogin.password,
                          userlogin.is_role,
                          userlogin.order_date,
                          userlogin.status_date);
                    },
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
