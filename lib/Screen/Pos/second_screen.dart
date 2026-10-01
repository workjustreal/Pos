// ignore_for_file: non_constant_identifier_names, prefer_typing_uninitialized_variables, use_build_context_synchronously, depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:intl/intl.dart';
import 'package:kacee_pos/Screen/Pos/components/background.dart';
import 'package:kacee_pos/Screen/Pos/end_screen.dart';
import 'package:kacee_pos/Screen/Pos/main_screen.dart';
import 'package:kacee_pos/components/a3_dialog.dart';
import 'package:kacee_pos/components/a3_layout.dart';
import 'package:kacee_pos/components/dailog_container.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/model/product.dart';
import 'package:kacee_pos/network_utils/api.dart';
import 'package:kacee_pos/services/krungsri_payment_service.dart';
import 'package:kacee_pos/services/printer_service.dart';
import 'package:kacee_pos/services/tts_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecondScreen extends StatefulWidget {
  // Optional initial state passed from MainScreen so the QR screen can
  // render the cart immediately (no flash of empty list while the
  // order/get/ call round-trips, and resilient to weird backend responses
  // during the brief pre-create → callback window).
  final List<Product>? initialProducts;
  final String? initialTotalPrice;
  final String? initialTotalQty;
  final String? initialOrderNumber;
  final String? initialOrderId;
  const SecondScreen({
    Key? key,
    this.initialProducts,
    this.initialTotalPrice,
    this.initialTotalQty,
    this.initialOrderNumber,
    this.initialOrderId,
  }) : super(key: key);
  @override
  State<SecondScreen> createState() => _SecondState();
}

class _SecondState extends State<SecondScreen> {
  final ScrollController scollBarController = ScrollController();
  late List<Product>? productList;
  String? order_id, order_number, total_qty, total_price, qr, trx, machine_code;
  // Blocks a double-tap on "ชำระเงินอีกครั้ง" from creating two QRs.
  bool _isRetrying = false;

  final _maxSeconds = 180;
  int _currentSecond = 0;
  Timer? _timer; // 1-second tick for countdown UI + timeout trigger
  Timer? _pollTimer; // faster (500ms) tick dedicated to callback polling
  bool _isPolling = false;
  bool _finished = false;

  @override
  void initState() {
    // Seed from the values MainScreen handed us so the cart never visually
    // empties while we wait for order/get/ to come back. _loadSaleOrder
    // can still refresh these (and only overwrites the product list if the
    // server returns a non-empty items array).
    productList = widget.initialProducts;
    total_price = widget.initialTotalPrice;
    total_qty = widget.initialTotalQty;
    order_number = widget.initialOrderNumber;
    order_id = widget.initialOrderId;
    super.initState();
    _loadPaymentInfo();
    _loadSaleOrder();
    _startTimer();
    PrinterService().ensureConnected();
  }

  /// QR payload + trxId were stored by KrungsriPaymentService.precreate
  /// before navigating here. Load them independently of order/get so the
  /// QR still shows (and trans/detail can still be queried) when that
  /// call fails.
  Future<void> _loadPaymentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      qr = prefs.getString("qrcodeContent");
      trx = prefs.getString("trxId");
      machine_code = prefs.getString("machine_code");
    });
  }

  /// "ชำระเงินอีกครั้ง" — create a fresh QR for the same order and restart
  /// this screen with it.
  Future QRPayment() async {
    if (_isRetrying) return;
    final sum = (total_price ?? '0').replaceAll(',', '');
    if ((double.tryParse(sum) ?? 0) <= 0) {
      _showAlertDialog(context, "กรุณาเพิ่มสินค้าในตะกร้าก่อน");
      return;
    }

    _isRetrying = true;
    bool ok;
    try {
      ok = await KrungsriPaymentService.precreate(
          amount: sum, reference1: '$order_number');
    } catch (e) {
      // ignore: avoid_print
      print('QRPayment error: $e');
      ok = false;
    } finally {
      _isRetrying = false;
    }
    if (!mounted) return;
    if (!ok) {
      _showAlertDialog(context, 'ไม่สามรถเชื่อมต่อธนาคารได้! กรุณาติดต่อแอดมิน');
      return;
    }

    // Preserve cart state across the retry push (same order, same items).
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => SecondScreen(
          initialProducts:
              productList == null ? null : List<Product>.from(productList!),
          initialTotalPrice: total_price,
          initialTotalQty: total_qty,
          initialOrderNumber: order_number,
          initialOrderId: order_id,
        ),
      ),
      (_) => false,
    );
  }

  Future<void> _loadSaleOrder() async {
    try {
      final response = await Network().getSearchProduct('order/get');
      if (response.statusCode != 200) return;
      final jsonResponse = json.decode(response.body);
      // Same guard as main_screen — server can return 200 with missing data
      // on edge cases (no active order, auth refresh). Bail cleanly.
      final data = jsonResponse is Map ? jsonResponse['data'] : null;
      if (data == null || data is! Map) return;
      final List item = (data['items'] as List?) ?? const [];
      final products = item
          .map<Product>((m) => Product.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (!mounted) return;
      setState(() {
        order_id = data['order_id']?.toString() ?? order_id;
        order_number = data['order_number']?.toString() ?? order_number;
        total_qty = data['total_qty']?.toString() ?? total_qty;
        total_price = data['total_price']?.toString() ?? total_price;
        // Only overwrite the cart if the server returned actual items —
        // an empty array here would otherwise wipe the list MainScreen
        // already gave us during navigation.
        if (products.isNotEmpty) productList = products;
      });

      final prefs = await SharedPreferences.getInstance();
      saveLogs(order_id, prefs.getString("trxId"));

      // Pre-render the receipt image while the customer is still paying.
      // When the payment callback lands, PrinterService.printReceipt can
      // skip the HTTP fetch + isolate work and go straight to the BT write
      // — typically saves 1.5-2s off the post-payment print latency.
      // If the backend refuses to generate the receipt before payment
      // (e.g. returns 404), this silently no-ops and the live path runs.
      PrinterService().prefetchReceipt('order/receipt/${data['order_id']}');
    } catch (e) {
      // ignore: avoid_print
      print('_loadSaleOrder error: $e');
    }
  }

  Future saveLogs(String? order_id, trx) async {
    try {
      final response = await Network().pushTransfer('payment/log', {
        'oid': order_id,
        'tid': trx,
      });
      if (response.statusCode == 200) return;
    } catch (e) {
      // ignore: avoid_print
      print('saveLogs error: $e');
    }
    if (mounted) {
      _showAlertDialog(context, "ฐานข้อมูลมีปัญหา กรุณาติดต่อ ADMIN");
    }
  }

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

  /// Back button: "กลับไปแก้ไขรายการสินค้า" → return to the cart (order is
  /// kept, not cancelled). This screen is the only route on the stack, so
  /// letting the pop through used to close the app.
  Future<bool> _onBackPressed() async {
    if (_finished) return false;
    final goBack = await showExitPopup();
    if (!goBack || _finished || !mounted) return false;
    _finished = true;
    _timer?.cancel();
    _pollTimer?.cancel();
    PrinterService().clearCache();
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false);
    return false;
  }

  Future<bool> showExitPopup() {
    return showKcConfirm(
      context,
      icon: Icons.edit_note_rounded,
      title: 'แก้ไขรายการสินค้า',
      message: 'คุณต้องการกลับไปแก้ไขรายการสินค้าใช่หรือไม่?',
      cancelLabel: 'ไม่',
      confirmLabel: 'ใช่',
    );
  }

  Future<void> _checkCallback() async {
    if (_isPolling || _finished) return;
    _isPolling = true;
    try {
      final localStorage = await SharedPreferences.getInstance();
      final id = localStorage.getString("order_id");
      final response =
          await Network().getSearchProduct('payment/complete/$id');
      if (response.statusCode == 200) {
        _onPaymentSuccess();
      }
    } catch (_) {
      // swallow; next tick will retry
    } finally {
      _isPolling = false;
    }
  }

  void _onPaymentSuccess() {
    if (_finished || !mounted) return;
    _finished = true;
    _timer?.cancel();
    _pollTimer?.cancel();

    // Navigate IMMEDIATELY so the customer never waits on the printer.
    // Image decode/resize/raster runs in a background isolate inside
    // PrinterService — UI thread stays free, no 10-second freeze.
    // EndScreen gets the print future so it can show the real print status.
    final printJob = SharedPreferences.getInstance().then<bool>((prefs) {
      final oid = prefs.getString("order_id");
      if (oid == null) return false;
      return PrinterService().printReceipt('order/receipt/$oid');
    });
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EndScreen(
            totalPrice: total_price,
            totalQty: total_qty,
            orderNumber: order_number,
            printJob: printJob,
          ),
        ),
        (_) => false);
  }

  Future<void> checkcallbackdetail() async {
    if (_finished) return;
    try {
      final trxId = trx;
      if (trxId == null) return;
      if (!await KrungsriPaymentService.isPaid(trxId)) return;

      final localStorage = await SharedPreferences.getInstance();
      final id = localStorage.getString("order_id");
      final confirmResponse = await Network()
          .getSearchProduct('payment/detail/complete/$trxId/$id');
      if (confirmResponse.statusCode == 200) {
        _onPaymentSuccess();
      }
    } catch (_) {
      // swallow; retry loop will pick it up
    }
  }

  String get _timerText {
    const secondsPerMinute = 60;
    final secondsLeft = _maxSeconds - _currentSecond;

    final formattedMinutesLeft =
        (secondsLeft ~/ secondsPerMinute).toString().padLeft(2, '0');
    final formattedSecondsLeft =
        (secondsLeft % secondsPerMinute).toString().padLeft(2, '0');

    return '$formattedMinutesLeft : $formattedSecondsLeft';
  }

  void _loading(BuildContext context) async {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) {
          return Dialog(
            backgroundColor: kcSurfaceColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kcRadiusLg),
                side: const BorderSide(color: kcStrokeColor)),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(kcAccentOrange)),
                  SizedBox(height: 20),
                  Text('กรุณารอสักครู่...',
                      style: TextStyle(
                          color: kcTextPrimary, fontFamily: 'Kanit')),
                  SizedBox(height: 4),
                  Text('กำลังตรวจสอบข้อมูล',
                      style: TextStyle(
                          color: kcTextSecondary,
                          fontFamily: 'Kanit',
                          fontSize: 12)),
                ],
              ),
            ),
          );
        });
  }

  void _startTimer() {
    // Display timer: 1s tick — updates the countdown text and triggers
    // the 180s timeout.
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted || _finished) return;
      setState(() {
        _currentSecond = timer.tick;
      });
      if (timer.tick >= _maxSeconds) {
        timer.cancel();
        _pollTimer?.cancel();
        _handlePaymentTimeout();
      }
    });

    // Poll timer: 500ms tick — fires the payment-status check 2× per second
    // so the EndScreen appears within ~1s of the bank callback instead of
    // up to 2s with the original 1s polling interval.
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500),
        (Timer timer) {
      if (!mounted || _finished) return;
      _checkCallback();
    });
  }

  Future<void> _handlePaymentTimeout() async {
    // First retry pass: Krungsri detail API + local callback.
    await checkcallbackdetail();
    if (_finished || !mounted) return;
    await _checkCallback();
    if (_finished || !mounted) return;

    _loading(context);
    await Future.delayed(const Duration(seconds: 5));
    if (_finished || !mounted) return;

    // Second retry pass before giving up.
    await checkcallbackdetail();
    if (_finished || !mounted) return;
    await _checkCallback();
    if (_finished || !mounted) return;

    // Spoken warning that payment timed out.
    TtsService().speak("หมดเวลาชำระเงิน กรุณาลองอีกครั้ง");

    showDialog(
      context: context,
      builder: (BuildContext context) => KcDialog(
        icon: Icons.timer_off_outlined,
        iconColor: kcDangerColor,
        title: 'หมดเวลาชำระเงิน',
        message: 'ท่านไม่ได้ชำระเงินภายในระยะเวลาที่กำหนด',
        actions: [
          KcDialogButton(label: 'ยกเลิกคำสั่งซื้อ', onTap: cancelOrder),
          KcDialogButton(
              label: 'ชำระเงินอีกครั้ง', primary: true, onTap: QRPayment),
        ],
      ),
    );
  }

  void cancelOrder() async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      final id = localStorage.getString("order_id");
      final response =
          await Network().getCancelOrder('order/cancel', {'oid': id});
      if (!mounted) return;
      if (response.statusCode == 200) {
        PrinterService().clearCache();
        // Replace the stack: a plain push left this screen (and its
        // timers) alive underneath MainScreen.
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (_) => false);
        return;
      }
    } catch (e) {
      // ignore: avoid_print
      print('cancelOrder error: $e');
    }
    if (mounted) {
      _showAlertDialog(context, "ยกเลิกคำสั่งซื้อไม่สำเร็จ กรุณาลองอีกครั้ง");
    }
  }

  @override
  void dispose() {
    _finished = true;
    _timer?.cancel();
    _pollTimer?.cancel();
    scollBarController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('d MMM yyyy').format(DateTime.now());
    final progress =
        (1 - _currentSecond / _maxSeconds).clamp(0.0, 1.0).toDouble();
    final timedOut = _currentSecond >= _maxSeconds;
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
                  section: 'ชำระเงิน',
                  info: 'เครื่อง ${machine_code ?? "—"} · $formattedDate',
                ),
                // Mount the barcode sink with zero height — keeps it active
                // without affecting layout.
                SizedBox(
                  height: 0,
                  child: ClipRect(child: _hiddenBarcodeSink()),
                ),
                Expanded(
                  child: KcSplitLayout(
                    side: _qrPanel(progress, timedOut),
                    main: _detailPanel(timedOut),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // The hidden barcode listener is kept so stray keyboard input from the
  // scanner is consumed while the customer is on the payment screen.
  Widget _hiddenBarcodeSink() {
    return BarcodeKeyboardListener(
      bufferDuration: const Duration(milliseconds: 100),
      onBarcodeScanned: (_) {},
      child: const SizedBox.shrink(),
    );
  }

  // --- Side panel: QR, amount, countdown -----------------------------------

  Widget _qrPanel(double progress, bool timedOut) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KcSectionLabel('สแกนเพื่อชำระเงิน'),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kcRadiusMd),
              border: Border.all(color: kcStrokeColor),
            ),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final side = constraints.biggest.shortestSide;
                    return Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        // When timed out we swap the QR for an expired
                        // placeholder so the customer can't keep scanning.
                        child: timedOut
                            ? _expiredQr()
                            : QrImageView(
                                backgroundColor: Colors.white,
                                data: qr?.toString() ?? "",
                                version: QrVersions.auto,
                                size: side,
                                errorCorrectionLevel: QrErrorCorrectLevel.L,
                              ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text('ยอดที่ต้องชำระ', style: kcLabelStyle),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '฿ ${total_price ?? "0.00"}',
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 36,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                      color: kcAccentOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              timedOut ? 'QR หมดอายุแล้ว' : 'QR หมดอายุใน',
              style: const TextStyle(
                  fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted),
            ),
            const Spacer(),
            Text(
              _timerText,
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: timedOut || progress < 0.2
                    ? kcDangerColor
                    : kcTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        KcProgressBar(
          value: timedOut ? 0 : progress,
          color: progress < 0.2 ? kcDangerColor : kcAccentOrange,
        ),
      ],
    );
  }

  Widget _expiredQr() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.qr_code_2_rounded, size: 120, color: kcStrokeColorStrong),
        SizedBox(height: 8),
        Text('QR หมดอายุ',
            style: TextStyle(
                fontFamily: 'Kanit', fontSize: 16, color: kcTextMuted)),
      ],
    );
  }

  // --- Main panel: steps, order summary, status ----------------------------

  Widget _detailPanel(bool timedOut) {
    final items = productList ?? const <Product>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KcSectionLabel('ขั้นตอนการชำระเงิน'),
        _stepRow('1', 'เปิดแอปธนาคารที่ท่านสะดวก'),
        _stepRow('2', 'สแกนคิวอาร์โค้ดทางซ้าย'),
        _stepRow('3', 'ยืนยันการชำระเงินในแอปธนาคาร'),
        _stepRow('4', 'รอรับใบเสร็จ'),
        const SizedBox(height: 16),
        const Divider(color: kcStrokeColor, height: 1, thickness: 1),
        const SizedBox(height: 14),
        KcSectionLabel(
          'คำสั่งซื้อ ${order_number ?? "-"}',
          trailing: Text(
            '${items.length} รายการ · ${total_qty ?? 0} ชิ้น',
            style: kcLabelStyle,
          ),
        ),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            controller: scollBarController,
            child: ListView.builder(
              controller: scollBarController,
              itemExtent: 48,
              itemCount: items.length,
              itemBuilder: (context, index) => _orderRow(items[index]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            KcDot(color: timedOut ? kcDangerColor : kcSuccessDotColor),
            const SizedBox(width: 8),
            Text(
              timedOut ? 'หมดเวลาชำระเงิน' : 'กำลังรอการชำระเงิน...',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 14,
                color: timedOut ? kcDangerColor : kcSuccessColor,
              ),
            ),
            const Spacer(),
            KcOutlineButton(
              label: 'ยกเลิกการชำระเงิน',
              icon: Icons.close_rounded,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              onTap: _showCancelDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepRow(String n, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kcStrokeColorStrong),
            ),
            child: Text(n,
                style: const TextStyle(
                    fontFamily: 'Kanit',
                    color: kcAccentOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontFamily: 'Kanit', fontSize: 17, color: kcTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderRow(Product p) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kcStrokeColorSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Kanit', fontSize: 15, color: kcTextPrimary),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text('x${p.qty}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted)),
          ),
          SizedBox(
            width: 90,
            child: Text(p.totalprice,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'Kanit', fontSize: 15, color: kcTextPrimary)),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Future<void> _showCancelDialog() async {
    final ok = await showKcConfirm(
      context,
      icon: Icons.warning_amber_rounded,
      title: 'ยกเลิกการชำระเงิน',
      message: 'ต้องการยกเลิกรายการ ใช่หรือไม่?',
      cancelLabel: 'ไม่ใช่',
      confirmLabel: 'ยกเลิกรายการ',
      destructive: true,
    );
    if (!ok || _finished || !mounted) return;
    _finished = true;
    _timer?.cancel();
    _pollTimer?.cancel();
    cancelOrder();
  }
}
