// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kacee_pos/Screen/Pos/main_screen.dart';
import 'package:kacee_pos/components/a3_layout.dart';
import 'package:kacee_pos/components/rounded_text_input.dart';
import 'package:kacee_pos/constants.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kacee_pos/network_utils/api.dart';
import 'package:kacee_pos/Screen/Login/components/background.dart';
import 'package:kacee_pos/components/rounded_password_input.dart';
import 'package:kacee_pos/components/dailog_container.dart';
import 'package:kacee_pos/model/user_login.dart';

class Body extends StatefulWidget {
  const Body({Key? key}) : super(key: key);

  @override
  State<Body> createState() => _LoginState();
}

class _LoginState extends State<Body> {
  bool _isLoading = false;
  String? _lastShop, _lastMachine;
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
    }
    // Ignore taps while a login is in flight — a double-tap used to push
    // two MainScreens.
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
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
      if (!mounted) return;

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse != null) {
          final user = jsonResponse['data']['user'];
          await sharedPreferences.setString(
              "token", jsonResponse['data']['token']);
          await sharedPreferences.setString("id", user['id'].toString());
          await sharedPreferences.setString(
              "shop_code", user['shop_code'].toString());
          await sharedPreferences.setString(
              "machine_code", user['machine_code'].toString());
          await sharedPreferences.setString(
              "mac_printer", (user['mac_printer'] ?? '').toString());
          if (!mounted) return;
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
        var message = "ไม่พบข้อมูลสิทธิผู้ใช้งาน";
        _showAlertDialog(context, message);
      }
    } catch (e) {
      // ignore: avoid_print
      print('_signIn error: $e');
      if (mounted) {
        _showAlertDialog(
            context, "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาลองอีกครั้ง");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLastMachine();
  }

  /// Shop / machine from the previous login, shown in the side panel so
  /// staff can confirm which kiosk this is before signing in.
  Future<void> _loadLastMachine() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lastShop = prefs.getString("shop_code");
      _lastMachine = prefs.getString("machine_code");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Background(
      child: SafeArea(
        child: KcSplitLayout(
          sideColor: kcInkColorSoft,
          side: _brandPanel(),
          main: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _form(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            KcDot(size: 12),
            SizedBox(width: 10),
            Text(
              'KACEEPOS',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 26,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                color: kcTextPrimary,
              ),
            ),
          ],
        ),
        const Text('Self checkout 2.0',
            style: TextStyle(
                fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted)),
        const Spacer(),
        const KcSectionLabel('ข้อมูลเครื่อง'),
        KcInfoRow('สาขา', _lastShop ?? '—'),
        KcInfoRow('เครื่อง', _lastMachine ?? '—'),
        const KcInfoRow('เวอร์ชัน', '2.0.0'),
      ],
    );
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('เข้าสู่ระบบ', style: kcHeadlineStyle),
        const SizedBox(height: 4),
        const Text('สำหรับพนักงานเปิดเครื่อง',
            style: TextStyle(
                fontFamily: 'Kanit', fontSize: 15, color: kcTextMuted)),
        const SizedBox(height: 28),
        const Text('ชื่อผู้ใช้', style: kcLabelStyle),
        const SizedBox(height: 6),
        RoundedInputField(
          hintText: 'Username',
          icon: iconA,
          onChanged: (value) {
            userlogin.email = value;
          },
        ),
        const SizedBox(height: 16),
        const Text('รหัสผ่าน', style: kcLabelStyle),
        const SizedBox(height: 6),
        RoundedPasswordField(
          maxLength: 12,
          onChanged: (value) {
            userlogin.password = value;
          },
        ),
        const SizedBox(height: 28),
        KcPrimaryButton(
          label: _isLoading ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ',
          height: 58,
          onTap: _isLoading
              ? null
              : () => _signIn(
                  userlogin.email,
                  userlogin.password,
                  userlogin.is_role,
                  userlogin.order_date,
                  userlogin.status_date),
        ),
      ],
    );
  }
}
