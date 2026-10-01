import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Welcome/components/background.dart';
import 'package:kacee_pos/Screen/login/login_screen.dart';
import 'package:kacee_pos/components/rounded_button.dart';
import 'package:kacee_pos/constants.dart';
import 'package:page_transition/page_transition.dart';

class Body extends StatelessWidget {
  const Body({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Background(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(64, 32, 64, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: _heroText(context)),
                    const SizedBox(width: 32),
                    Expanded(flex: 5, child: _heroImage()),
                  ],
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kcSurfaceColorHi.withOpacity(0.6),
            borderRadius: BorderRadius.circular(kcRadiusPill),
            border: Border.all(color: kcStrokeColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bolt_rounded, size: 16, color: kcAccentOrange),
              SizedBox(width: 6),
              Text(
                "KACEEPOS  2.0",
                style: TextStyle(
                  color: kcTextSecondary,
                  fontSize: 12,
                  fontFamily: 'Kanit',
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kcSurfaceColorHi.withOpacity(0.55),
            borderRadius: BorderRadius.circular(kcRadiusPill),
            border: Border.all(color: kcStrokeColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.circle, color: kcSuccessColor, size: 8),
              SizedBox(width: 8),
              Text(
                "พร้อมให้บริการ",
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12,
                  color: kcTextSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroText(BuildContext context) {
    // Responsive: shrink hero + drop description on short landscapes
    // (e.g. Sunmi D2s Lite at ~600px usable height). Big screens still
    // get the full 96px banner feel.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final headlineSize = compact ? 64.0 : 96.0;
        final spaceBeforeHeadline = compact ? 14.0 : 20.0;
        final spaceAfterHeadline = compact ? 12.0 : 18.0;
        final spaceBeforeButton = compact ? 24.0 : 40.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eyebrow line
            Row(
              children: [
                Container(
                  width: 36,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: kcBrandGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "ระบบชำระเงินด้วยตนเอง",
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    color: kcAccentOrange,
                    fontSize: 14,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            SizedBox(height: spaceBeforeHeadline),
            // Big hero headline — two lines reading like a landscape banner
            ShaderMask(
              shaderCallback: (bounds) =>
                  kcBrandGradient.createShader(bounds),
              child: Text(
                "SELF\nCHECKOUT",
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontWeight: FontWeight.w600,
                  fontSize: headlineSize,
                  height: 0.95,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: spaceAfterHeadline),
            const Text(
              "สแกน • ชำระ • รับใบเสร็จ",
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 20,
                color: kcTextSecondary,
                letterSpacing: 5,
                fontWeight: FontWeight.w300,
              ),
            ),
            // Description shown only when there's vertical room.
            if (!compact) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: 460,
                child: Text(
                  "เลือกซื้อสินค้าและชำระเงินได้ด้วยตัวเอง รวดเร็ว ปลอดภัย ไม่ต้องรอคิว",
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 14,
                    color: kcTextMuted,
                    height: 1.6,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
            SizedBox(height: spaceBeforeButton),
            Row(
              children: [
                RoundedButton(
                  text: "เริ่มใช้งาน",
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
                const SizedBox(width: 20),
                Row(
                  children: const [
                    Icon(Icons.touch_app_rounded,
                        color: kcTextMuted, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "หรือแตะที่หน้าจอเพื่อเริ่ม",
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 12,
                        color: kcTextMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _heroImage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = constraints.maxHeight < constraints.maxWidth
            ? constraints.maxHeight
            : constraints.maxWidth;
        final imageBoxSize = (maxSize * 0.85).clamp(280.0, 620.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer atmospheric halo
            Container(
              width: imageBoxSize + 80,
              height: imageBoxSize + 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kcAccentOrange.withOpacity(0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Decorative ring
            Container(
              width: imageBoxSize + 20,
              height: imageBoxSize + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: kcAccentOrange.withOpacity(0.18),
                  width: 1,
                ),
              ),
            ),
            // Inner dashed-style accent
            Container(
              width: imageBoxSize - 12,
              height: imageBoxSize - 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: kcStrokeColor,
                  width: 1,
                ),
              ),
            ),
            // The hero image
            SizedBox(
              width: imageBoxSize,
              height: imageBoxSize,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Image.asset(
                  "assets/images/welcome.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Floating pink accent dot
            Positioned(
              top: 12,
              right: imageBoxSize * 0.18,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kcAccentPink,
                  boxShadow: [
                    BoxShadow(
                      color: kcAccentPink.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            // Floating amber accent dot
            Positioned(
              bottom: 20,
              left: imageBoxSize * 0.10,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kcAccentAmber,
                  boxShadow: [
                    BoxShadow(
                      color: kcAccentAmber.withOpacity(0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text(
          "© KACEE  •  Self-checkout terminal",
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 11,
            color: kcTextFaint,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          "v2.0.0",
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 11,
            color: kcTextFaint,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
