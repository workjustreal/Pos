// ignore_for_file: non_constant_identifier_names, prefer_typing_uninitialized_variables, use_build_context_synchronously, depend_on_referenced_packages

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kacee_pos/Screen/Login/login_screen.dart';
import 'package:kacee_pos/Screen/Pos/components/background.dart';
import 'package:kacee_pos/Screen/Pos/second_screen.dart';
import 'package:kacee_pos/components/a3_dialog.dart';
import 'package:kacee_pos/components/a3_layout.dart';
import 'package:kacee_pos/components/dailog_container.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/model/product.dart';
import 'package:kacee_pos/network_utils/api.dart';
import 'package:kacee_pos/services/krungsri_payment_service.dart';
import 'package:kacee_pos/services/printer_service.dart';
import 'package:kacee_pos/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  @override
  State<MainScreen> createState() => _MainState();
}

class _MainState extends State<MainScreen> {
  final ScrollController scollBarController = ScrollController();
  final player = AudioPlayer();

  String? _barcode;
  // Starts false so a scan that lands before VisibilityDetector's first
  // report is ignored instead of throwing LateInitializationError.
  bool visible = false;
  late List<Product>? productList;
  // late final id;
  String? order_id,
      order_number,
      total_qty,
      total_price,
      shop_code,
      shop_name,
      self_name,
      machine_code;

  final double _height = 64; // cart row height (ListView itemExtent)
  void _scrollToIndex(index) {
    // Guard against two crash cases:
    //  1. ListView isn't in the tree yet (empty cart shows _emptyCart instead)
    //     → controller has no positions attached → animateTo throws.
    //  2. indexWhere returned -1 (barcode not in current cart) → would
    //     animate to a negative offset.
    if (index == null || index < 0) return;
    if (!scollBarController.hasClients) return;
    scollBarController.animateTo(_height * index,
        duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
  }

  int? _selectItem;
  int? _destinationIndex;
  bool _canPay = false;
  bool _isScanning = false;
  // Blocks a double-tap on "ชำระเงิน" from creating two QR transactions.
  bool _isPaying = false;

  @override
  void initState() {
    productList = null;
    super.initState();
    // Load locally-cached identifiers FIRST so the header pills show
    // shop / machine even if the network APIs (_loadSaleOrder, _userDetail)
    // are slow or fail. These were stored at login time.
    _loadLocalIdentifiers();
    _loadSaleOrder();
    PrinterService().ensureConnected();
    _userDetail();
  }

  @override
  void dispose() {
    scollBarController.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> _loadLocalIdentifiers() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      shop_code = prefs.getString("shop_code");
      machine_code = prefs.getString("machine_code");
      // Use shop_code as a placeholder name until _userDetail fills in
      // the real shop_name. If user/detail/ never returns, at least we
      // show *something* meaningful instead of "—".
      shop_name ??= shop_code;
    });
  }

  void _setPayEnabled(bool enabled) {
    if (!mounted) return;
    setState(() {
      _canPay = enabled;
    });
  }

  Future<void> _reprintReceipt() async {
    final localStorage = await SharedPreferences.getInstance();
    final id = localStorage.getString("id");
    final ok = await PrinterService().printReceipt('order/receipt/reprint/$id');
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kcDarkColor,
          action: SnackBarAction(
              label: 'ปิด', textColor: kcAccentOrange, onPressed: () {}),
          content: const Text('ปริ้นใบเสร็จเรียบร้อย!',
              style: TextStyle(color: Colors.white, fontFamily: 'Kanit')),
          duration: const Duration(milliseconds: 1500),
          width: 320.0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kcRadiusMd),
          ),
        ),
      );
    } else {
      // Surface the actual reason — most often "ยังไม่ได้ตั้งค่า MAC"
      // (mac_printer empty in prefs) or "ไม่สามารถเชื่อมต่อ" (BT off /
      // printer out of range / Sunmi BT stack wedged).
      final reason = PrinterService().lastConnectError;
      _showAlertDialog(
        context,
        reason != null
            ? "พิมพ์ไม่สำเร็จ\n\n$reason"
            : "ไม่พบออเดอร์หรือเครื่องพิมพ์ไม่พร้อม",
      );
    }
  }

  void _userDetail() async {
    try {
      final response = await Network().getSearchProduct('user/detail/');
      if (response.statusCode != 200) return;
      final jsonResponse = json.decode(response.body);
      // Server can return 200 with a body that doesn't contain `data`
      // (auth-related responses, error payloads). Guard before indexing —
      // this used to crash with "[] called on null".
      final data = jsonResponse is Map ? jsonResponse['data'] : null;
      if (data == null || data is! Map) return;
      if (!mounted) return;
      setState(() {
        shop_name = data['shop_name']?.toString();
        self_name = data['name']?.toString();
      });
    } catch (e) {
      // Silent: header pills will keep their previous values ("—" if first
      // load). Don't propagate so the rest of the screen still works.
      // ignore: avoid_print
      print('_userDetail error: $e');
    }
  }

  Future<void> _loadSaleOrder() async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      final response = await Network().getSearchProduct('order/get/');
      if (response.statusCode != 200) return;
      final jsonResponse = json.decode(response.body);
      // Guard: server can return 200 with empty/missing data on edge cases
      // (no active order, auth refresh window, etc.). Bail out cleanly
      // instead of crashing on null['items'].
      final data = jsonResponse is Map ? jsonResponse['data'] : null;
      if (data == null || data is! Map) return;
      final List item = (data['items'] as List?) ?? const [];
      final products = item
          .map<Product>((m) => Product.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      final oid = data['order_id'].toString();
      await localStorage.setString("order_id", oid);
      if (!mounted) return;
      setState(() {
        order_id = oid;
        order_number = data['order_number']?.toString();
        total_qty = data['total_qty'].toString();
        total_price = data['total_price'].toString();
        shop_code = localStorage.getString("shop_code");
        machine_code = localStorage.getString("machine_code");
        productList = products;
        _destinationIndex =
            products.indexWhere((element) => element.barcode == _barcode);
      });
      if (_selectItem != -1) {
        _scrollToIndex(_destinationIndex);
      }
      _setPayEnabled(true);
    } catch (e) {
      // ignore: avoid_print
      print('_loadSaleOrder error: $e');
    }
  }

  Future<bool> checkInternetConnectivity() async {
    // connectivity_plus 6.x returns List<ConnectivityResult> (a device can
    // report multiple active transports — wifi + vpn, mobile + ethernet, etc.)
    // The old 5.x API returned a single enum value. The previous code
    // compared the list to an enum constant which is always false, so the
    // "no internet" alert fired every time pay was pressed.
    final results = await Connectivity().checkConnectivity();
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  void paymentProcess() async {
    if (_isPaying) return;
    _isPaying = true;
    try {
      bool isConnected = await checkInternetConnectivity();
      if (!mounted) return;
      if (isConnected) {
        await QRPayment();
      } else {
        var message = "กรุณาตรวจสอบการเชื่อมต่ออินเตอร์เน็ต!";
        _showAlertDialog(context, message);
      }
    } finally {
      _isPaying = false;
    }
  }

  /// Back button = logout. After a sale MainScreen is the only route on
  /// the stack, so letting the pop through closed the app instead of
  /// returning to login. Always replace the stack with LoginScreen.
  Future<bool> _onBackPressed() async {
    final logout = await showExitPopup();
    if (!logout || !mounted) return false;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false);
    return false;
  }

  Future<bool> showExitPopup() {
    return showKcConfirm(
      context,
      icon: Icons.logout_rounded,
      title: 'ออกจากระบบ',
      message: 'คุณต้องการออกจากระบบใช่หรือไม่?',
      cancelLabel: 'ไม่',
      confirmLabel: 'ใช่',
      destructive: true,
    );
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

  Future searchProduct(String? code) async {
    // scan lock prevents a fast double-scan from firing duplicate
    // add-item requests while the previous round-trip is still pending.
    if (_isScanning) return;
    _setPayEnabled(false);
    _isScanning = true;
    try {
      // If we don't have an active order yet, try one refresh first. This
      // recovers from the case where MainScreen.initState entered before
      // the backend had an active order ready (so _loadSaleOrder bailed
      // silently on null data) — without this, every scan in that state
      // returns 4xx and shows "ไม่สามารถบันทึกได้" / "ไม่เจอสินค้า" which
      // misleads the customer into thinking it's a product-not-found.
      if (order_id == null ||
          order_id!.isEmpty ||
          order_id == 'null') {
        await _loadSaleOrder();
      }

      final response = await Network().pushTransfer('order/item/add', {
        'oid': order_id,
        'barcode': code,
      });
      // ignore: avoid_print
      print('searchProduct: oid=$order_id barcode=$code → ${response.statusCode}');
      if (response.statusCode == 200) {
        _loadSaleOrder();
      } else {
        // Surface the actual status so admin can tell the difference between
        //  - 400 (oid invalid / order closed)        → system issue
        //  - 404 (barcode not in product master)     → genuine "not found"
        //  - 5xx (server error)                      → backend down
        final isLikelyProductIssue = response.statusCode == 404;
        final msg = isLikelyProductIssue
            ? "ไม่พบสินค้านี้ในระบบ — กรุณาแจ้งแคชเชียร์"
            : "บันทึกไม่สำเร็จ (HTTP ${response.statusCode})\nกรุณาแจ้งแคชเชียร์";
        // The cart didn't change — re-enable pay for the items already in it.
        _setPayEnabled(true);
        if (!mounted) return;
        _showAlertDialog(context, msg);
        await player.play(AssetSource('sound/noproduct.mp3'));
      }
    } catch (e) {
      // ignore: avoid_print
      print('searchProduct error: $e');
      _setPayEnabled(true);
      if (mounted) {
        _showAlertDialog(context,
            "เกิดข้อผิดพลาดในการเชื่อมต่อ\nกรุณาลองสแกนใหม่อีกครั้ง");
      }
    } finally {
      _isScanning = false;
    }
  }

  Future delItem(id, sku) async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      final uid = localStorage.getString("id");
      final response = await Network().pushTransfer('order/item/del', {
        'uid': uid,
        'oid': id,
        'sku': sku,
      });
      if (response.statusCode == 200) {
        _selectItem = -1;
        _loadSaleOrder();
        return;
      }
    } catch (e) {
      // ignore: avoid_print
      print('delItem error: $e');
    }
    if (mounted) {
      _showAlertDialog(context, "ไม่สามารถบันทึกได้ กรุณาติดต่อ ADMIN");
    }
  }

  Future<void> clearItem() async {
    try {
      final response =
          await Network().pushTransfer('order/clear', {'oid': order_id});
      if (response.statusCode == 200) {
        _selectItem = -1;
        _loadSaleOrder();
        return;
      }
    } catch (e) {
      // ignore: avoid_print
      print('clearItem error: $e');
    }
    if (mounted) {
      _showAlertDialog(context, "ไม่สามารถบันทึกได้ กรุณาติดต่อ ADMIN");
    }
  }

  Future QRPayment() async {
    final sum = (total_price ?? '0').replaceAll(',', '');
    final amount = double.tryParse(sum) ?? 0;
    if (amount <= 0) {
      _showAlertDialog(context, "กรุณาเพิ่มสินค้าในตะกร้าก่อน");
      return;
    }

    // Speak the total aloud (Thai TTS) — so the customer can verify the
    // amount before scanning the QR.
    TtsService().speakAmount(amount); // fire-and-forget

    bool ok;
    try {
      ok = await KrungsriPaymentService.precreate(
          amount: sum, reference1: '$order_number');
    } catch (e) {
      // ignore: avoid_print
      print('QRPayment error: $e');
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      _showAlertDialog(context, 'ไม่สามรถเชื่อมต่อธนาคารได้! กรุณาติดต่อแอดมิน');
      return;
    }

    // Snapshot current cart state and hand it to SecondScreen so the
    // QR review screen can render the list, totals, and order number
    // immediately — independent of whatever order/get/ returns once
    // the backend has moved the order into a pending-payment state.
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

  // ------------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------------

  /// The cart row matching the last scanned barcode, shown in the spotlight
  /// card. Null before the first scan or while the add-item round-trip is
  /// still pending.
  Product? get _lastScanned {
    final list = productList;
    if (list == null || _barcode == null) return null;
    for (final p in list) {
      if (p.barcode == _barcode) return p;
    }
    return null;
  }

  void _onBarcodeScanned(String sbarcode) {
    if (!visible) return;

    // QR / non-barcode guard: scanners on Sunmi sometimes lock onto
    // a QR code printed next to the real product barcode. Retail
    // product codes are 1–14 digits (EAN-8 / UPC-A / EAN-13 /
    // GTIN-14). Anything else — URLs, mixed chars, very long
    // strings — is almost certainly a QR / non-product scan.
    // Show a clear message instead of sending the garbage to the
    // backend and getting a confusing "ไม่พบสินค้า" response.
    if (!RegExp(r'^\d{1,14}$').hasMatch(sbarcode)) {
      _showAlertDialog(
          context, "กรุณาสแกนเฉพาะบาร์โค้ดสินค้า (ไม่ใช่ QR code)");
      player.play(AssetSource('sound/noproduct.mp3'));
      return;
    }

    // Normalize barcode then fire scan OUTSIDE setState.
    String barcode;
    if (sbarcode != '0088300607402' && sbarcode != '047469058654') {
      barcode = (int.tryParse(sbarcode) ?? 0).toString();
    } else {
      barcode = sbarcode;
    }
    setState(() {
      _barcode = barcode;
      _selectItem = 1;
    });
    searchProduct(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('d MMM yyyy').format(DateTime.now());
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
                  info: '${shop_name ?? "—"} · เครื่อง ${machine_code ?? "—"}'
                      ' · $formattedDate',
                  actions: [
                    KcOutlineButton(
                      label: 'เคลียร์ตะกร้า',
                      icon: Icons.remove_shopping_cart_outlined,
                      onTap: _showClearCartDialog,
                    ),
                    KcOutlineButton(
                      label: 'พิมพ์ซ้ำ',
                      icon: Icons.print_outlined,
                      onTap: _reprintReceipt,
                    ),
                  ],
                ),
                Expanded(
                  child: KcSplitLayout(
                    side: _scanPanel(),
                    main: _cartPanel(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showClearCartDialog() async {
    final ok = await showKcConfirm(
      context,
      icon: Icons.remove_shopping_cart_outlined,
      title: 'เคลียร์ตะกร้า',
      message: 'ต้องการเคลียร์ตะกร้าใช่ไหม? สินค้าทั้งหมดจะถูกลบออก',
      confirmLabel: 'เคลียร์ตะกร้า',
      destructive: true,
    );
    if (ok) clearItem();
  }

  // --- Side panel: last-scanned spotlight, totals, pay ---------------------

  Widget _scanPanel() {
    final priceText = total_price ?? "0.00";
    return VisibilityDetector(
      key: const Key('visible-detector-key'),
      onVisibilityChanged: (VisibilityInfo info) {
        visible = info.visibleFraction > 0;
      },
      child: BarcodeKeyboardListener(
        bufferDuration: const Duration(milliseconds: 100),
        onBarcodeScanned: _onBarcodeScanned,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KcSectionLabel('เพิ่งสแกน'),
            _spotlightCard(),
            const SizedBox(height: 12),
            const Row(
              children: [
                KcDot(color: kcSuccessDotColor),
                SizedBox(width: 8),
                Text('พร้อมสแกน',
                    style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 13,
                        color: kcSuccessColor)),
              ],
            ),
            const Spacer(),
            KcInfoRow('เลขคำสั่งซื้อ', order_number ?? '—'),
            KcInfoRow('จำนวนสินค้า', '${total_qty ?? "0"} ชิ้น'),
            const SizedBox(height: 14),
            const Text('ยอดรวม', style: kcLabelStyle),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '฿ $priceText',
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 46,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  color: kcTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            KcPrimaryButton(
              label: 'ชำระเงิน',
              icon: Icons.qr_code_2_rounded,
              onTap: _canPay ? paymentProcess : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _spotlightCard() {
    final p = _lastScanned;
    return Container(
      constraints: const BoxConstraints(minHeight: 168),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(kcRadiusMd),
        border: Border.all(color: p == null ? kcStrokeColor : kcAccentOrange),
      ),
      child: p == null ? _spotlightEmpty() : _spotlightProduct(p),
    );
  }

  Widget _spotlightEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.qr_code_scanner_rounded,
            color: kcAccentOrange, size: 34),
        const SizedBox(height: 10),
        const Text('สแกนบาร์โค้ดสินค้า',
            style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: kcTextPrimary)),
        const SizedBox(height: 2),
        Text(
          _barcode == null
              ? 'วางบาร์โค้ดใต้เครื่องสแกนได้เลย'
              : 'บาร์โค้ดล่าสุด $_barcode',
          style: const TextStyle(
              fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted),
        ),
      ],
    );
  }

  Widget _spotlightProduct(Product p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: kcSuccessColor, size: 18),
            SizedBox(width: 6),
            Text('เพิ่มลงตะกร้าแล้ว',
                style: TextStyle(
                    fontFamily: 'Kanit', fontSize: 13, color: kcSuccessColor)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          p.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w500,
            color: kcTextPrimary,
          ),
        ),
        Text(p.barcode.isNotEmpty ? p.barcode : p.sku, style: kcCaptionStyle),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('฿ ${p.price}',
                style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 28,
                    height: 1.0,
                    color: kcAccentOrange)),
            const Spacer(),
            Text('ในตะกร้า x${p.qty}',
                style: const TextStyle(
                    fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted)),
          ],
        ),
      ],
    );
  }

  // --- Main panel: cart list -----------------------------------------------

  Widget _cartPanel() {
    final items = productList ?? const <Product>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KcSectionLabel(
          'ตะกร้าของคุณ',
          trailing: Text('${items.length} รายการ', style: kcLabelStyle),
        ),
        _cartHeader(),
        Expanded(
          child: items.isEmpty
              ? _emptyCart()
              : Scrollbar(
                  thumbVisibility: true,
                  controller: scollBarController,
                  child: ListView.builder(
                    controller: scollBarController,
                    // Fixed row height so _scrollToIndex lands exactly on
                    // the scanned row.
                    itemExtent: _height,
                    itemCount: items.length,
                    itemBuilder: (context, index) => _cartRow(items[index]),
                  ),
                ),
        ),
      ],
    );
  }

  static const _colPrice = 90.0;
  static const _colQty = 80.0;
  static const _colTotal = 100.0;
  static const _colDelete = 52.0;

  Widget _cartHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kcStrokeColor)),
      ),
      child: const Row(
        children: [
          Expanded(child: Text('สินค้า', style: kcLabelStyle)),
          SizedBox(
              width: _colPrice,
              child: Text('ราคา',
                  style: kcLabelStyle, textAlign: TextAlign.right)),
          SizedBox(
              width: _colQty,
              child: Text('จำนวน',
                  style: kcLabelStyle, textAlign: TextAlign.center)),
          SizedBox(
              width: _colTotal,
              child: Text('รวม',
                  style: kcLabelStyle, textAlign: TextAlign.right)),
          SizedBox(width: _colDelete),
        ],
      ),
    );
  }

  Widget _cartRow(Product p) {
    final selected = p.barcode == '$_barcode';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? kcAccentTint : null,
        border: const Border(bottom: BorderSide(color: kcStrokeColorSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Kanit', fontSize: 16, color: kcTextPrimary),
                ),
                Text(
                  selected ? 'เพิ่งสแกน · ${p.sku}' : p.sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 12,
                      color: selected ? kcAccentOrange : kcTextMuted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _colPrice,
            child: Text(p.price,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'Kanit', fontSize: 15, color: kcTextSecondary)),
          ),
          SizedBox(
            width: _colQty,
            child: Text(p.qty,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Kanit', fontSize: 16, color: kcTextPrimary)),
          ),
          SizedBox(
            width: _colTotal,
            child: Text(p.totalprice,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: kcTextPrimary)),
          ),
          SizedBox(
            width: _colDelete,
            child: IconButton(
              tooltip: 'ลบรายการ',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: kcDangerColor, size: 22),
              onPressed: () => delItem(p.id.toString(), p.sku),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCart() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, color: kcTextFaint, size: 52),
          SizedBox(height: 12),
          Text('ตะกร้ายังว่าง',
              style: TextStyle(
                  fontFamily: 'Kanit', fontSize: 18, color: kcTextSecondary)),
          SizedBox(height: 4),
          Text('สแกนบาร์โค้ดสินค้าเพื่อเริ่มรายการ',
              style: TextStyle(
                  fontFamily: 'Kanit', fontSize: 14, color: kcTextMuted)),
        ],
      ),
    );
  }
}
