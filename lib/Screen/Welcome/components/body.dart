import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Welcome/components/background.dart';
import 'package:kacee_pos/Screen/login/login_screen.dart';
import 'package:kacee_pos/components/a3_layout.dart';
import 'package:kacee_pos/components/rounded_button.dart';
import 'package:kacee_pos/constants.dart';
import 'package:page_transition/page_transition.dart';

class Body extends StatelessWidget {
  const Body({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Background(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KcTopBar(
              actions: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KcDot(color: kcSuccessDotColor),
                    SizedBox(width: 8),
                    Text(
                      "พร้อมให้บริการ",
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 13,
                        color: kcSuccessColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(64, 24, 64, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: _heroText(context)),
                    const SizedBox(width: 48),
                    Expanded(flex: 5, child: _heroImage()),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _heroText(BuildContext context) {
    // Responsive: shrink hero + drop description on short landscapes
    // (e.g. Sunmi D2s Lite at ~600px usable height).
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 560;
        final headlineSize = compact ? 60.0 : 88.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 36, height: 3, color: kcAccentOrange),
                const SizedBox(width: 10),
                const Text(
                  "ระบบชำระเงินด้วยตนเอง",
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    color: kcAccentOrange,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 12 : 18),
            Text.rich(
              TextSpan(
                children: const [
                  TextSpan(text: "SELF\n"),
                  TextSpan(
                    text: "CHECKOUT",
                    style: TextStyle(color: kcAccentOrange),
                  ),
                ],
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontWeight: FontWeight.w500,
                  fontSize: headlineSize,
                  height: 0.95,
                  letterSpacing: 1,
                  color: kcTextPrimary,
                ),
              ),
            ),
            SizedBox(height: compact ? 12 : 18),
            const Text(
              "สแกน • ชำระ • รับใบเสร็จ",
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 20,
                color: kcTextSecondary,
                letterSpacing: 2,
              ),
            ),
            // Description shown only when there's vertical room.
            if (!compact) ...[
              const SizedBox(height: 10),
              const SizedBox(
                width: 460,
                child: Text(
                  "เลือกซื้อสินค้าและชำระเงินได้ด้วยตัวเอง รวดเร็ว ปลอดภัย ไม่ต้องรอคิว",
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 15,
                    color: kcTextMuted,
                    height: 1.6,
                  ),
                ),
              ),
            ],
            SizedBox(height: compact ? 24 : 36),
            RoundedButton(
              text: "เริ่มใช้งาน",
              width: 260,
              press: () {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.fade,
                    child: const LoginScreen(),
                    inheritTheme: true,
                    ctx: context,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _heroImage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide.clamp(240.0, 560.0);
        return Center(
          child: Container(
            width: side,
            height: side,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: kcSurfaceColorLo,
              borderRadius: BorderRadius.circular(kcRadiusXl),
              border: Border.all(color: kcStrokeColor),
            ),
            child: Image.asset(
              "assets/images/welcome.png",
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kcStrokeColor)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "© KACEE  •  Self-checkout terminal",
            style: TextStyle(
                fontFamily: 'Kanit', fontSize: 12, color: kcTextFaint),
          ),
          Text(
            "v2.0.0",
            style: TextStyle(
                fontFamily: 'Kanit', fontSize: 12, color: kcTextFaint),
          ),
        ],
      ),
    );
  }
}
