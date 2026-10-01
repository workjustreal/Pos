// ignore_for_file: non_constant_identifier_names, prefer_typing_uninitialized_variables, use_build_context_synchronously, depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:intl/intl.dart';
import 'package:kacee_pos/Screen/Pos/components/background.dart';
import 'package:kacee_pos/Screen/Pos/end_screen.dart';
import 'package:kacee_pos/Screen/Pos/main_screen.dart';
import 'package:kacee_pos/components/aurora_background.dart';
import 'package:kacee_pos/components/dailog_container.dart';
import 'package:kacee_pos/components/rounded_button_home.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/model/product.dart';
import 'package:kacee_pos/network_utils/api.dart';
import 'package:kacee_pos/services/printer_service.dart';
import 'package:kacee_pos/services/tts_service.dart';
import 'package:page_transition/page_transition.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:crypto/crypto.dart';
import 'package:crypton/crypton.dart';

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
  late bool visible;
  late List<Product>? productList;
  // late final id;
  String? order_id, order_number, total_qty, total_price, qr, trx;

  bool printBinded = false;
  int paperSize = 0;
  String serialNumber = "";
  String printerVersion = "";
  var coreItem = StringBuffer();
  var coreTotal = StringBuffer();

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
    _loadSaleOrder();
    _startTimer();
    PrinterService().ensureConnected();
  }

  Future QRPayment() async {
    var now = DateTime.now();
    var formatter = DateFormat('yyyy-MM-dd|HH:mm:ss');
    var timestamp = formatter.format(now);
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var sum = total_price.toString().replaceAll(',', '');

    if (double.parse(sum) <= 0.00) {
      var message = "กรุณาเพิ่มสินค้าในตะกร้าก่อน";
      _showAlertDialog(context, message);
    } else {
      // String bizMchId = '1088156774177478'; //uat
      String bizMchId = '1088156637107024';
      // String pubKey =
      //     'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCe1AS2Cmt24Nu6rcbG5q5whL5Yt1BtSi4r5nJKIL+UcKEWH3jMJFO029xxZdPeOzo6EkeFRKeJkfKRUDGDOjlNRQSp2uK85fLt0y09B2nemru3IIpMEgCr5VcWdxlzNE/K6WGVYn2z5WM54viFLOF8oqL7f8A8iQyy4h/BAXzIdQIDAQAB'; //uat
      String pubKey =
          'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC0LhvtMyXZFBEw2ePMYrZfDQhGdgLjx2Ls8JCovMk48zcMlWk/yuImicxl7bKW6syXGQScByRaFjcQrPMk6RLDcFtpsTo+vkbCY/0A6STTBepsS4lWtB2bAOgWPuHI+hblccWiRUGHKf2P9bWSq6Yb5xJe0EuLfVtm42xNtdTpAQIDAQAB';
      String billerId = '010554709331800';
      String ch = '2';
      String ref1 = '$order_number';
      String ref2 = '024293333';
      String terminalId = '0001';
      String amount = sum;
      String remark = timestamp;

      String strA =
          "amount=$amount&billerId=$billerId&bizMchId=$bizMchId&channel=$ch&reference1=$ref1&reference2=$ref2&remark=$remark&terminalId=$terminalId";
      var key = utf8.encode(strA);
      var strB = sha256.convert(key);

      RSAPublicKey rsa = RSAPublicKey.fromString(pubKey);
      String sign = rsa.encrypt(strB.toString());

      Map<String, dynamic> requests = {
        'bizMchId': bizMchId,
        'billerId': billerId,
        'channel': ch,
        'reference1': ref1,
        'reference2': ref2,
        'terminalId': terminalId,
        'amount': amount,
        'remark': remark,
        'sign': sign
      };
      var path = 'trans/precreate';
      var uriapi = Network().paymentTransfer(path, requests);
      var response = await uriapi;
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        sharedPreferences.setString(
            "qrcodeContent", jsonResponse['qrcodeContent']);
        sharedPreferences.setString("trxId", jsonResponse['trxId']);
        // Preserve cart state across the retry push (same order, same items).
        final productsSnapshot =
            productList == null ? null : List<Product>.from(productList!);
        final totalPriceSnapshot = total_price;
        final totalQtySnapshot = total_qty;
        final orderNumberSnapshot = order_number;
        final orderIdSnapshot = order_id;
        setState(() {
          Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (BuildContext context) {
            return SecondScreen(
              initialProducts: productsSnapshot,
              initialTotalPrice: totalPriceSnapshot,
              initialTotalQty: totalQtySnapshot,
              initialOrderNumber: orderNumberSnapshot,
              initialOrderId: orderIdSnapshot,
            );
          }), (r) {
            return false;
          });
        });
      } else {
        var message = response.body.toString();
        _showAlertDialog(context, message);
      }
    }
  }

  void _loadSaleOrder() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var id = localStorage.getString("id");
    var path = 'order/get';
    var urlapi = Network().getSearchProduct(path);
    var response = await urlapi;
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      // Same guard as main_screen — server can return 200 with missing data
      // on edge cases (no active order, auth refresh). Bail cleanly.
      final data = jsonResponse is Map ? jsonResponse['data'] : null;
      if (data == null || data is! Map) return;
      final List item = (data['items'] as List?) ?? const [];

      coreItem.clear();
      var cart;
      for (var i in item) {
        cart = i['sku'];
        cart += "(";
        cart += i['qty'].toString();
        cart += ")";
        cart += "          ";
        cart += double.parse((i['total_price'].toString())).toStringAsFixed(2);
        cart += "\n\n";
        coreItem.write(cart);
      }
      setState(() {
        coreTotal.clear();
        order_id = data['order_id']?.toString() ?? order_id;
        order_number =
            data['order_number']?.toString() ?? order_number;
        total_qty = data['total_qty']?.toString() ?? total_qty;
        total_price = data['total_price']?.toString() ?? total_price;
        coreTotal.write(total_price ?? '');
        // Only overwrite the cart if the server returned actual items —
        // an empty array here would otherwise wipe the list MainScreen
        // already gave us during navigation.
        if (item.isNotEmpty) {
          productList = item
              .map<Product>(
                  (m) => Product.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
        qr = localStorage.getString("qrcodeContent");
        trx = localStorage.getString("trxId");
        saveLogs(order_id, trx);
      });

      // Pre-render the receipt image while the customer is still paying.
      // When the payment callback lands, PrinterService.printReceipt can
      // skip the HTTP fetch + isolate work and go straight to the BT write
      // — typically saves 1.5-2s off the post-payment print latency.
      // If the backend refuses to generate the receipt before payment
      // (e.g. returns 404), this silently no-ops and the live path runs.
      final oid = jsonResponse['data']['order_id'].toString();
      PrinterService().prefetchReceipt('order/receipt/$oid');
    }
  }

  Future saveLogs(String? order_id, trx) async {
    Map<String, dynamic> request = {
      'oid': order_id,
      'tid': trx,
    };
    var path = 'payment/log';
    var urlapi = Network().pushTransfer(path, request);
    var response = await urlapi;
    if (response.statusCode == 200) {
      // ignore: avoid_print
      print("create logs complete");
    } else {
      var message = "ฐานข้อมูลมีปัญหา กรุณาติดต่อ ADMIN";
      _showAlertDialog(context, message);
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

  Future<bool> showExitPopup() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: kcSurfaceColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kcRadiusLg)),
            title: const Text('แจ้งเตือน',
                style: TextStyle(color: kcTextPrimary, fontFamily: 'Kanit')),
            content: const Text(
                'คุณต้องการกลับไปแก้ไขรายการสินค้าใช่หรือไม่?',
                style: TextStyle(
                    color: kcTextSecondary, fontFamily: 'Kanit')),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: kcSuccessColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: const Text('ไม่'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: kcDangerColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: const Text('ใช่'),
              ),
            ],
          ),
        ) ??
        false;
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
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const EndScreen()),
        (_) => false);

    SharedPreferences.getInstance().then((prefs) {
      final oid = prefs.getString("order_id");
      if (oid != null) {
        PrinterService().printReceipt('order/receipt/$oid');
      }
    });
  }

  Future<void> checkcallbackdetail() async {
    if (_finished) return;
    try {
      final localStorage = await SharedPreferences.getInstance();
      final id = localStorage.getString("order_id");
      const bizMchId = '1088156637107024';
      const pubKey =
          'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC0LhvtMyXZFBEw2ePMYrZfDQhGdgLjx2Ls8JCovMk48zcMlWk/yuImicxl7bKW6syXGQScByRaFjcQrPMk6RLDcFtpsTo+vkbCY/0A6STTBepsS4lWtB2bAOgWPuHI+hblccWiRUGHKf2P9bWSq6Yb5xJe0EuLfVtm42xNtdTpAQIDAQAB';
      final trxId = trx;
      final strB =
          sha256.convert(utf8.encode("bizMchId=$bizMchId&trxId=$trxId"));
      final sign = RSAPublicKey.fromString(pubKey).encrypt(strB.toString());

      final response = await Network().paymentTransfer('trans/detail', {
        'bizMchId': bizMchId,
        'trxId': trxId,
        'sign': sign,
      });
      if (response.statusCode != 200) return;

      final jsonResponse = json.decode(response.body);
      if (jsonResponse['returnCode'] != "10000") return;
      if (jsonResponse['transaction']?['trxStatus'] != "1") return;

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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kcRadiusLg)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
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
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kcSurfaceColorHi, kcSurfaceColor],
            ),
            borderRadius: BorderRadius.circular(kcRadiusLg),
            border: Border.all(color: kcStrokeColor),
            boxShadow: kcShadowSoft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  gradient: kcBrandGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(kcRadiusLg),
                    topRight: Radius.circular(kcRadiusLg),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.timer_off_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'หมดเวลาชำระเงิน',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Kanit',
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ท่านไม่ได้ชำระเงินภายในระยะเวลาที่กำหนด',
                  style: TextStyle(
                      color: kcTextSecondary,
                      fontSize: 14,
                      fontFamily: 'Kanit'),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: cancelOrder,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(kcRadiusLg)),
                        ),
                      ),
                      child: const Text('ยกเลิกคำสั่งซื้อ',
                          style: TextStyle(
                              color: kcDangerColor,
                              fontSize: 15,
                              fontFamily: 'Kanit')),
                    ),
                  ),
                  Container(width: 1, height: 50, color: kcStrokeColor),
                  Expanded(
                    child: TextButton(
                      onPressed: QRPayment,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(kcRadiusLg)),
                        ),
                      ),
                      child: const Text('ชำระเงินอีกครั้ง',
                          style: TextStyle(
                              color: kcAccentOrange,
                              fontSize: 15,
                              fontFamily: 'Kanit',
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void cancelOrder() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var id = localStorage.getString("order_id");
    Map<String, dynamic> request = {
      'oid': id,
    };
    var path = 'order/cancel';
    var urlapi = Network().getCancelOrder(path, request);
    var response = await urlapi;
    if (response.statusCode == 200) {
      setState(() {
        Navigator.push(
          context,
          PageTransition(
              type: PageTransitionType.fade,
              child: const MainScreen(),
              inheritTheme: true,
              ctx: context),
        );
      });
    }
  }

  @override
  void dispose() {
    _finished = true;
    _timer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEEE d MMM yyyy').format(DateTime.now());
    final progress =
        (1 - _currentSecond / _maxSeconds).clamp(0.0, 1.0).toDouble();
    final timedOut = _currentSecond >= _maxSeconds;
    return WillPopScope(
      onWillPop: showExitPopup,
      child: Scaffold(
        backgroundColor: kcInkColor,
        body: Background(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(formattedDate),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 11, child: _orderPanel()),
                        const SizedBox(width: 16),
                        Expanded(flex: 9, child: _paymentPanel(progress, timedOut)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The hidden barcode listener is kept so stray keyboard input from the
  // scanner is consumed while the customer is on the payment screen.
  Widget _hiddenBarcodeSink() {
    return VisibilityDetector(
      onVisibilityChanged: (info) {
        visible = info.visibleFraction > 0;
      },
      key: const Key('visible-detector-key'),
      child: BarcodeKeyboardListener(
        bufferDuration: const Duration(milliseconds: 100),
        onBarcodeScanned: (barcode) {
          if (!visible) return;
          setState(() {});
        },
        child: const SizedBox.shrink(),
      ),
    );
  }

  Widget _topBar(String formattedDate) {
    return Row(
      children: [
        RoundedButtonHome(press: () {}),
        const SizedBox(width: 16),
        Expanded(
          child: GlassCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            radius: kcRadiusLg,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: kcBrandGradientSoft,
                    borderRadius: BorderRadius.circular(kcRadiusPill),
                    border:
                        Border.all(color: kcAccentOrange.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'KACEEPOS  2.0',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 11,
                      color: kcAccentOrange,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'ชำระเงิน',
                  style: TextStyle(
                      fontFamily: 'Kanit',
                      color: kcTextPrimary,
                      fontSize: 18),
                ),
                const Spacer(),
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: kcTextMuted),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: const TextStyle(
                      fontFamily: 'Kanit',
                      color: kcTextSecondary,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Countdown pill
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: kcBrandGradient,
            borderRadius: BorderRadius.circular(kcRadiusLg),
            boxShadow: kcShadowGlow,
          ),
          child: Row(
            children: [
              const Icon(Icons.timelapse_rounded,
                  size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _timerText,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Mount the barcode sink off-screen — keeps it active without
        // affecting layout.
        SizedBox(
          width: 0,
          height: 0,
          child: ClipRect(child: _hiddenBarcodeSink()),
        ),
      ],
    );
  }

  Widget _orderPanel() {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      radius: kcRadiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: kcAccentOrange, size: 22),
              const SizedBox(width: 8),
              const Text(
                'รายการสินค้า',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 20,
                  color: kcTextPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: kcSurfaceColorHi.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(kcRadiusPill),
                  border: Border.all(color: kcStrokeColor),
                ),
                child: Text(
                  'เลข ${order_number ?? "-"}',
                  style: const TextStyle(
                      fontFamily: 'Kanit',
                      color: kcAccentOrange,
                      fontSize: 12,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kcInkColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(kcRadiusSm),
            ),
            child: Row(
              children: const [
                Expanded(
                    flex: 2,
                    child: Text("รหัสสินค้า", style: kcLabelStyle)),
                Expanded(flex: 3, child: Text("ชื่อ", style: kcLabelStyle)),
                Expanded(
                    flex: 1,
                    child: Text("ราคา",
                        style: kcLabelStyle, textAlign: TextAlign.center)),
                Expanded(
                    flex: 1,
                    child: Text("จำนวน",
                        style: kcLabelStyle, textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text("ราคารวม",
                        style: kcLabelStyle, textAlign: TextAlign.right)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              controller: scollBarController,
              child: ListView.separated(
                controller: scollBarController,
                scrollDirection: Axis.vertical,
                itemCount: productList == null ? 0 : productList!.length,
                separatorBuilder: (_, __) => const Divider(
                    color: kcStrokeColorSoft, height: 1, thickness: 1),
                itemBuilder: (context, index) {
                  final p = productList![index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: Text(
                          p.sku,
                          style: const TextStyle(
                              fontFamily: 'Kanit',
                              fontWeight: FontWeight.w300,
                              fontSize: 12,
                              color: kcTextMuted),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          p.name,
                          style: const TextStyle(
                              fontFamily: 'Kanit',
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              color: kcTextPrimary),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          p.price,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: 'Kanit',
                              fontWeight: FontWeight.w300,
                              fontSize: 12,
                              color: kcTextSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: kcSurfaceColorHi.withOpacity(0.7),
                            borderRadius:
                                BorderRadius.circular(kcRadiusPill),
                          ),
                          child: Text(
                            p.qty,
                            style: const TextStyle(
                                fontFamily: 'Kanit',
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: kcAccentOrange),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          p.totalprice,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontFamily: 'Kanit',
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: kcTextPrimary),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _totalCard(),
        ],
      ),
    );
  }

  Widget _totalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kcRadiusLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2438), Color(0xFF1F1A2C)],
        ),
        border: Border.all(color: kcAccentOrange.withOpacity(0.35), width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33F96349), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ยอดรวมทั้งหมด',
                  style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 13,
                      color: kcTextSecondary,
                      letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(
                '${total_qty ?? 0} รายการ',
                style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 12,
                    color: kcTextMuted,
                    letterSpacing: 1),
              ),
            ],
          ),
          const Spacer(),
          ShaderMask(
            shaderCallback: (bounds) => kcBrandGradient.createShader(bounds),
            child: Text(
              '฿ ${total_price ?? "0.00"}',
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 38,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentPanel(double progress, bool timedOut) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      radius: kcRadiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.qr_code_scanner_rounded,
                  color: kcAccentPink, size: 22),
              SizedBox(width: 8),
              Text(
                'ขั้นตอนการชำระเงิน',
                style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 20,
                    color: kcTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _stepRow('1', 'เปิดแอพฯ ธนาคารที่ท่านสะดวก'),
          _stepRow('2', 'สแกนคิวอาร์โค้ดด้านล่าง'),
          _stepRow('3', 'ยืนยันการชำระเงินในแอพฯ ธนาคาร'),
          _stepRow('4', 'รอรับใบเสร็จ'),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: _qrWithRing(progress, timedOut),
            ),
          ),
          const SizedBox(height: 16),
          _cancelButton(),
        ],
      ),
    );
  }

  Widget _stepRow(String n, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: kcBrandGradient,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33F96349),
                    blurRadius: 8,
                    offset: Offset(0, 3)),
              ],
            ),
            child: Text(n,
                style: const TextStyle(
                    fontFamily: 'Kanit',
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 14,
                  color: kcTextSecondary,
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrWithRing(double progress, bool timedOut) {
    // Countdown ring around QR. When timed out we swap the QR for the
    // existing "hide_qr" asset so the customer can't continue scanning.
    const double size = 270;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ambient halo
        Container(
          width: size + 30,
          height: size + 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              kcAccentOrange.withOpacity(0.18),
              Colors.transparent,
            ]),
          ),
        ),
        // Progress ring
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: timedOut ? 0 : progress,
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(
                timedOut ? kcDangerColor : kcAccentOrange),
            backgroundColor: kcStrokeColor,
          ),
        ),
        // QR / hide image card
        Container(
          width: size - 32,
          height: size - 32,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kcRadiusMd),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 6)),
            ],
          ),
          child: timedOut
              ? Image.asset("assets/images/hide_qr.jpg", fit: BoxFit.contain)
              : QrImageView(
                  backgroundColor: Colors.white,
                  data: qr?.toString() ?? "",
                  version: QrVersions.auto,
                  size: size - 60,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                ),
        ),
      ],
    );
  }

  Widget _cancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showCancelDialog,
        icon: const Icon(Icons.close_rounded,
            size: 18, color: kcTextSecondary),
        label: const Text(
          'ยกเลิกการชำระเงิน',
          style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 14,
              color: kcTextSecondary,
              letterSpacing: 1),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: kcStrokeColor, width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kcRadiusPill)),
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kcSurfaceColorHi, kcSurfaceColor],
              ),
              borderRadius: BorderRadius.circular(kcRadiusLg),
              border: Border.all(color: kcStrokeColor),
              boxShadow: kcShadowSoft,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 18),
                  decoration: const BoxDecoration(
                    gradient: kcBrandGradient,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(kcRadiusLg),
                      topRight: Radius.circular(kcRadiusLg),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'แจ้งเตือน',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'Kanit',
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'ต้องการยกเลิกรายการ ใช่หรือไม่?',
                    style: TextStyle(
                        color: kcTextSecondary,
                        fontSize: 14,
                        fontFamily: 'Kanit'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(kcRadiusLg)),
                          ),
                        ),
                        child: const Text('ยกเลิก',
                            style: TextStyle(
                                color: kcDangerColor,
                                fontSize: 15,
                                fontFamily: 'Kanit')),
                      ),
                    ),
                    Container(width: 1, height: 50, color: kcStrokeColor),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _finished = true;
                          _timer?.cancel();
                          _pollTimer?.cancel();
                          cancelOrder();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(kcRadiusLg)),
                          ),
                        ),
                        child: const Text('ตกลง',
                            style: TextStyle(
                                color: kcAccentOrange,
                                fontSize: 15,
                                fontFamily: 'Kanit',
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
