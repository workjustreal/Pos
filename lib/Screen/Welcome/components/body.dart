import 'package:flutter/material.dart';
import 'package:kacee_pos/Screen/Welcome/components/background.dart';
import 'package:kacee_pos/Screen/login/login_screen.dart';
import 'package:kacee_pos/components/a3_layout.dart';
import 'package:kacee_pos/constants.dart';
import 'package:page_transition/page_transition.dart';

class Body extends StatelessWidget {
  const Body({Key? key}) : super(key: key);

  void _start(BuildContext context) {
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: const LoginScreen(),
        inheritTheme: true,
        ctx: context,
      ),
    );
  }

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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(64, 32, 32, 32),
                      // Designed at a fixed size and scaled to fit, so the
                      // text grows with the screen instead of staying small.
                      // 0.85 = fill 85% of the column, not all of it.
                      child: FractionallySizedBox(
                        widthFactor: 0.85,
                        heightFactor: 0.85,
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          child: _heroText(context),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 24, 24, 24),
                      child: _ShowcasePanel(),
                    ),
                  ),
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _heroText(BuildContext context) {
    return SizedBox(
      width: 640,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 48, height: 4, color: kcAccentOrange),
              const SizedBox(width: 14),
              const Text(
                "ระบบชำระเงินด้วยตนเอง",
                style: TextStyle(
                  fontFamily: 'Kanit',
                  color: kcAccentOrange,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "SELF\n"),
                TextSpan(
                  text: "CHECKOUT",
                  style: TextStyle(color: kcAccentOrange),
                ),
              ],
              style: TextStyle(
                fontFamily: 'Kanit',
                fontWeight: FontWeight.w500,
                fontSize: 122,
                height: 0.95,
                letterSpacing: 1,
                color: kcTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "สแกน • ชำระ • รับใบเสร็จ",
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 32,
              color: kcTextSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "เลือกซื้อสินค้าและชำระเงินได้ด้วยตัวเอง\nรวดเร็ว ปลอดภัย ไม่ต้องรอคิว",
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 22,
              color: kcTextMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 320,
            child: KcPrimaryButton(
              label: "เริ่มใช้งาน",
              icon: Icons.arrow_forward_rounded,
              height: 76,
              onTap: () => _start(context),
            ),
          ),
        ],
      ),
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

/// Right-hand showcase: a soft orange panel with a mock of the checkout
/// flow (cart card, QR card, scan and receipt chips). Built from widgets
/// rather than a bitmap so it stays sharp at any screen size.
class _ShowcasePanel extends StatelessWidget {
  const _ShowcasePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kcAccentTint,
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Two faint rings for depth.
          Positioned(
            right: -120,
            top: -120,
            child: _ring(420),
          ),
          Positioned(
            left: -160,
            bottom: -200,
            child: _ring(520),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 720,
                  height: 620,
                  child: Stack(
                    children: [
                      Positioned(
                          left: 40, top: 70, child: _cartCard()),
                      Positioned(
                          right: 20, top: 190, child: _qrCard()),
                      Positioned(
                        left: 0,
                        top: 0,
                        child: _chip(
                          icon: Icons.qr_code_scanner_rounded,
                          color: kcAccentOrange,
                          title: 'สแกนบาร์โค้ด',
                          subtitle: 'สินค้าเข้าตะกร้าทันที',
                        ),
                      ),
                      Positioned(
                        left: 90,
                        bottom: 0,
                        child: _chip(
                          icon: Icons.receipt_long_rounded,
                          color: kcSuccessColor,
                          title: 'รับใบเสร็จ',
                          subtitle: 'พิมพ์อัตโนมัติหลังชำระเงิน',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kcAccentOrange.withOpacity(0.12), width: 2),
      ),
    );
  }

  static const _cardBorder = Color(0xFFF3DED7);

  BoxDecoration _cardDecoration([double radius = 20]) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _cardBorder),
      );

  Widget _cartCard() {
    Widget row(String name, String qty, String price, {bool hi = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: hi ? kcAccentTint : null,
          border: const Border(bottom: BorderSide(color: kcStrokeColorSoft)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontFamily: 'Kanit', fontSize: 17, color: kcTextPrimary)),
            ),
            Text(qty,
                style: const TextStyle(
                    fontFamily: 'Kanit', fontSize: 15, color: kcTextMuted)),
            const SizedBox(width: 24),
            SizedBox(
              width: 64,
              child: Text(price,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: kcTextPrimary)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 400,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              KcDot(),
              SizedBox(width: 8),
              Text('ตะกร้าของคุณ',
                  style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: kcTextPrimary)),
              Spacer(),
              Text('4 รายการ',
                  style: TextStyle(
                      fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted)),
            ],
          ),
          const SizedBox(height: 12),
          row('น้ำดื่ม 600ml', 'x2', '14.00'),
          row('มาม่า ต้มยำกุ้ง', 'x5', '30.00'),
          row('ขนมปัง', 'x1', '25.00'),
          row('นมจืด 830ml', 'x1', '52.00', hi: true),
          const SizedBox(height: 16),
          const Text('ยอดรวม',
              style: TextStyle(
                  fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted)),
          const Text('฿ 121.00',
              style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 38,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  color: kcTextPrimary)),
          const SizedBox(height: 14),
          Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kcAccentOrange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('ชำระเงิน',
                style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _qrCard() {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(24),
      child: Column(
        children: [
          // A QR glyph, not a real code — nothing here should be scannable.
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              color: kcSurfaceColorLo,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                size: 150, color: kcTextPrimary),
          ),
          const SizedBox(height: 14),
          const Text('สแกนจ่ายผ่าน QR',
              style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: kcTextPrimary)),
          const Text('ได้ทุกแอปธนาคาร',
              style: TextStyle(
                  fontFamily: 'Kanit', fontSize: 15, color: kcTextMuted)),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 22, 12),
      decoration: _cardDecoration(18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: kcTextPrimary)),
              Text(subtitle,
                  style: const TextStyle(
                      fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
