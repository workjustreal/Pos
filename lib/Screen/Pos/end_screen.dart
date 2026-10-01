import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kacee_pos/Screen/Pos/components/background.dart';
import 'package:kacee_pos/Screen/Pos/main_screen.dart';
import 'package:kacee_pos/components/a3_layout.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/services/printer_service.dart';
import 'package:kacee_pos/services/tts_service.dart';

class EndScreen extends StatefulWidget {
  // Summary of the order that was just paid, handed over by SecondScreen.
  final String? totalPrice;
  final String? totalQty;
  final String? orderNumber;
  // The receipt print started by SecondScreen; resolves to whether it
  // printed. Null = no print was started.
  final Future<bool>? printJob;
  const EndScreen({
    Key? key,
    this.totalPrice,
    this.totalQty,
    this.orderNumber,
    this.printJob,
  }) : super(key: key);
  @override
  State<EndScreen> createState() => _EndState();
}

class _EndState extends State<EndScreen> {
  final _maxSeconds = 10;
  int _currentSecond = 0;
  final _paidAt = DateTime.now();
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Spoken thank-you when the order is complete.
    TtsService().speak("ขอบคุณที่ใช้บริการ");
    _startTimer();
  }

  void _goHome() {
    _timer.cancel();
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false);
  }

  /// Back button: the sale is complete, so go straight to the cart screen.
  /// This screen is the only route on the stack — letting the pop through
  /// used to close the app.
  Future<bool> _onBackPressed() async {
    _goHome();
    return false;
  }

  void _startTimer() {
    const duration = Duration(seconds: 1);
    _timer = Timer.periodic(duration, (Timer timer) {
      if (!mounted) return;
      setState(() {
        _currentSecond = timer.tick;
      });
      if (timer.tick >= _maxSeconds) {
        _goHome();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondsLeft = (_maxSeconds - _currentSecond).clamp(0, _maxSeconds);
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        backgroundColor: kcInkColor,
        body: Background(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KcTopBar(
                  section: 'เสร็จสิ้น',
                  info: DateFormat('d MMM yyyy').format(_paidAt),
                ),
                Expanded(
                  child: KcSplitLayout(
                    side: _summaryPanel(),
                    main: _thankYou(secondsLeft),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KcSectionLabel('สรุปการชำระเงิน'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: kcSurfaceColor,
            borderRadius: BorderRadius.circular(kcRadiusMd),
            border: Border.all(color: kcStrokeColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: kcSuccessColor, size: 18),
                  SizedBox(width: 6),
                  Text('ชำระเงินแล้ว',
                      style: TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 13,
                          color: kcSuccessColor)),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '฿ ${widget.totalPrice ?? "—"}',
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 36,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                    color: kcTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              KcInfoRow('คำสั่งซื้อ', widget.orderNumber ?? '—'),
              KcInfoRow('จำนวน', '${widget.totalQty ?? "—"} ชิ้น'),
              KcInfoRow('เวลา', '${DateFormat('HH:mm').format(_paidAt)} น.'),
            ],
          ),
        ),
        const Spacer(),
        if (widget.printJob != null) _printStatus(widget.printJob!),
      ],
    );
  }

  Widget _printStatus(Future<bool> job) {
    return FutureBuilder<bool>(
      future: job,
      builder: (context, snap) {
        final done = snap.connectionState == ConnectionState.done;
        final ok = done && snap.data == true;
        final IconData icon;
        final Color color;
        final String title;
        String? detail;
        if (!done) {
          icon = Icons.print_outlined;
          color = kcAccentOrange;
          title = 'กำลังพิมพ์ใบเสร็จ';
        } else if (ok) {
          icon = Icons.check_circle_outline_rounded;
          color = kcSuccessColor;
          title = 'พิมพ์ใบเสร็จแล้ว';
        } else {
          icon = Icons.print_disabled_outlined;
          color = kcDangerColor;
          title = 'พิมพ์ใบเสร็จไม่สำเร็จ';
          detail = PrinterService().lastConnectError ??
              'กรุณาแจ้งพนักงานเพื่อพิมพ์ใบเสร็จอีกครั้ง';
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: done && !ok ? kcDangerTint : kcSurfaceColor,
            borderRadius: BorderRadius.circular(kcRadiusMd),
            border: Border.all(color: kcStrokeColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontFamily: 'Kanit',
                            fontSize: 15,
                            color: kcTextPrimary)),
                    if (!done) ...[
                      const SizedBox(height: 6),
                      const KcProgressBar(),
                    ],
                    if (detail != null)
                      Text(detail,
                          style: const TextStyle(
                              fontFamily: 'Kanit',
                              fontSize: 13,
                              color: kcTextSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _thankYou(int secondsLeft) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kcAccentOrange, width: 2),
            ),
            child: const Icon(Icons.check_rounded,
                size: 48, color: kcAccentOrange),
          ),
          const SizedBox(height: 24),
          const Text(
            'ขอบคุณที่ใช้บริการ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 40,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: kcTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'KACEE ขอบคุณท่านที่มาใช้บริการ',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Kanit', fontSize: 18, color: kcTextMuted),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: 300,
            child: KcProgressBar(
              value: secondsLeft / _maxSeconds,
              color: kcTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'กลับหน้าหลักใน $secondsLeft วินาที',
            style: const TextStyle(
                fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted),
          ),
          const SizedBox(height: 18),
          KcOutlineButton(
            label: 'เริ่มรายการใหม่',
            color: kcTextPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            onTap: _goHome,
          ),
        ],
      ),
    );
  }
}
