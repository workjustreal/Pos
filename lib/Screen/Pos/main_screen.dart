// ignore_for_file: non_constant_identifier_names, prefer_typing_uninitialized_variables, use_build_context_synchronously, depend_on_referenced_packages

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kacee_pos/Screen/Pos/components/background.dart';
import 'package:kacee_pos/Screen/Pos/second_screen.dart';
import 'package:kacee_pos/components/aurora_background.dart';
import 'package:kacee_pos/components/dailog_container.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/model/product.dart';
import 'package:kacee_pos/network_utils/api.dart';
import 'package:kacee_pos/services/printer_service.dart';
import 'package:kacee_pos/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:crypto/crypto.dart';
import 'package:crypton/crypton.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  @override
  State<MainScreen> createState() => _MainState();
}

class _MainState extends State<MainScreen> {
  final ScrollController scollBarController = ScrollController();
  final List<int> _list = List.generate(20, (i) => i);
  final List<bool> _selected = List.generate(20, (i) => false);
  final player = AudioPlayer();

  String? _barcode;
  late bool visible;
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

  bool printBinded = false;
  int paperSize = 0;
  String serialNumber = "";
  String printerVersion = "";
  var coreItem = StringBuffer();
  var coreTotal = StringBuffer();

  final double _height = 80;
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
  bool _isButtonDisabled = false;
  bool _isScanning = false;

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

  void _paymentButtonEnabled() {
    setState(() {
      _isButtonDisabled = true;
    });
  }

  void _paymentButtonDisabled() {
    setState(() {
      _isButtonDisabled = false;
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
          backgroundColor: kcSurfaceColorHi,
          action: SnackBarAction(
              label: 'ปิด', textColor: kcAccentOrange, onPressed: () {}),
          content: const Text('ปริ้นใบเสร็จเรียบร้อย!',
              style: TextStyle(color: kcTextPrimary, fontFamily: 'Kanit')),
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
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var id = localStorage.getString("id");
    var path = 'order/get/';
    var urlapi = Network().getSearchProduct(path);
    var response = await urlapi;
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      // Guard: server can return 200 with empty/missing data on edge cases
      // (no active order, auth refresh window, etc.). Bail out cleanly
      // instead of crashing on null['items'].
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
        cart += double.parse((i['total_price'].toString())).toStringAsFixed(3);
        cart += "\n\n";
        coreItem.write(cart);
      }
      setState(() {
        coreTotal.clear();
        localStorage.setString(
            "order_id", jsonResponse['data']['order_id'].toString());
        order_id = jsonResponse['data']['order_id'].toString();
        order_number = jsonResponse['data']['order_number'];
        total_qty = jsonResponse['data']['total_qty'].toString();
        total_price = jsonResponse['data']['total_price'].toString();
        shop_code = localStorage.getString("shop_code");
        machine_code = localStorage.getString("machine_code");
        coreTotal.write(total_price);
        productList = item
            .map<Product>((m) => Product.fromJson(Map<String, dynamic>.from(m)))
            .toList();

        final index =
            productList!.indexWhere((element) => element.barcode == _barcode);
        _destinationIndex = index;
      });
      if (_selectItem != -1) {
        _scrollToIndex(_destinationIndex);
      }
      _paymentButtonEnabled();
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
    bool isConnected = await checkInternetConnectivity();
    if (isConnected) {
      // Speak the total aloud (Thai TTS) — so the customer can verify the
      // amount before scanning the QR.
      final amount =
          double.tryParse((total_price ?? '0').replaceAll(',', '')) ?? 0;
      TtsService().speakAmount(amount); // fire-and-forget
      QRPayment();
    } else {
      var message = "กรุณาตรวจสอบการเชื่อมต่ออินเตอร์เน็ต!";
      _showAlertDialog(context, message);
    }
  }

  Future<bool> showExitPopup() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: kcSurfaceColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kcRadiusLg)),
            title: const Text('ออกจากระบบ',
                style: TextStyle(color: kcTextPrimary, fontFamily: 'Kanit')),
            content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?',
                style: TextStyle(color: kcTextSecondary, fontFamily: 'Kanit')),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: kcSuccessColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0))),
                child: const Text('ไม่'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: kcDangerColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0))),
                child: const Text('ใช่'),
              ),
            ],
          ),
        ) ??
        false;
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
    _paymentButtonDisabled();
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
        _showAlertDialog(context, msg);
        await player.play(AssetSource('sound/noproduct.mp3'));
      }
    } catch (e) {
      // ignore: avoid_print
      print('searchProduct error: $e');
      if (mounted) {
        _showAlertDialog(context,
            "เกิดข้อผิดพลาดในการเชื่อมต่อ\nกรุณาลองสแกนใหม่อีกครั้ง");
      }
    } finally {
      _isScanning = false;
    }
  }

  Future delItem(id, sku) async {
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
    } else {
      _showAlertDialog(context, "ไม่สามารถบันทึกได้ กรุณาติดต่อ ADMIN");
    }
  }

  Future<void> clearItem() async {
    final response =
        await Network().pushTransfer('order/clear', {'oid': order_id});
    if (response.statusCode == 200) {
      _selectItem = -1;
      _loadSaleOrder();
    } else {
      _showAlertDialog(context, "ไม่สามารถบันทึกได้ กรุณาติดต่อ ADMIN");
    }
  }

  Future QRPayment() async {
    Future.delayed(const Duration(seconds: 1));
    var now = DateTime.now();
    var formatter = DateFormat('yyyy-MM-dd|HH:mm:ss');
    var timestamp = formatter.format(now);
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    var sum = total_price.toString().replaceAll(',', '');

    if (double.parse(sum) <= 0.00) {
      var message = "กรุณาเพิ่มสินค้าในตะกร้าก่อน";
      _showAlertDialog(context, message);
    } else {
      String bizMchId = '1088156637107024';
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
        // Snapshot current cart state and hand it to SecondScreen so the
        // QR review screen can render the list, totals, and order number
        // immediately — independent of whatever order/get/ returns once
        // the backend has moved the order into a pending-payment state.
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
        var message = 'ไม่สามรถเชื่อมต่อธนาคารได้! กรุณาติดต่อแอดมิน';
        _showAlertDialog(context, message);
      }
    }
  }

  // ------------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEEE d MMM yyyy').format(DateTime.now());
    return WillPopScope(
      onWillPop: showExitPopup,
      child: Scaffold(
        backgroundColor: kcInkColor,
        body: Background(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(formattedDate),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _actionRail(),
                        const SizedBox(width: 12),
                        Expanded(flex: 12, child: _productPanel()),
                        const SizedBox(width: 12),
                        Expanded(flex: 8, child: _scanAndPayPanel()),
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

  Widget _topBar(String formattedDate) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      radius: kcRadiusLg,
      // Left group expands/shrinks freely. Pills on the right are laid out
      // FIRST at their intrinsic width so they always show their full text —
      // the left group then takes whatever's left over (with the title /
      // date truncating via ellipsis if the screen is narrow).
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: kcBrandGradientSoft,
                    borderRadius: BorderRadius.circular(kcRadiusPill),
                    border: Border.all(color: kcAccentOrange.withOpacity(0.3)),
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
                const SizedBox(width: 14),
                const Flexible(
                  child: Text(
                    'SELF CHECKOUT',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 20,
                      color: kcTextPrimary,
                      letterSpacing: 2,
                    ),
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.circle, color: kcStrokeColor, size: 4),
                const SizedBox(width: 14),
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: kcTextMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    formattedDate,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 13,
                      color: kcTextSecondary,
                    ),
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _statusPill(Icons.storefront_rounded, shop_name ?? "—"),
          const SizedBox(width: 8),
          _statusPill(Icons.monitor_rounded, 'เครื่อง ${machine_code ?? "—"}'),
        ],
      ),
    );
  }

  Widget _statusPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kcSurfaceColorHi.withOpacity(0.65),
        borderRadius: BorderRadius.circular(kcRadiusPill),
        border: Border.all(color: kcStrokeColor),
      ),
      child: Row(
        // mainAxisSize.min + softWrap:false → the pill always grows to its
        // text's full intrinsic width on one line, so long machine codes /
        // shop names never get clipped against the frame.
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              gradient: kcBrandGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            softWrap: false,
            overflow: TextOverflow.visible,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: 'Kanit',
              color: kcTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRail() {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          _railButton(
            icon: Icons.shopping_bag_rounded,
            tooltip: 'หน้าหลัก',
            onTap: () {},
            highlight: true,
          ),
          const SizedBox(height: 12),
          _railButton(
            icon: Icons.remove_shopping_cart_rounded,
            tooltip: 'เคลียร์ตะกร้า',
            onTap: _showClearCartDialog,
          ),
          const SizedBox(height: 12),
          _railButton(
            icon: Icons.print_rounded,
            tooltip: 'พิมพ์อีกครั้ง',
            onTap: _reprintReceipt,
          ),
        ],
      ),
    );
  }

  Widget _railButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          gradient: highlight ? kcBrandGradient : null,
          color: highlight ? null : kcSurfaceColorHi.withOpacity(0.55),
          borderRadius: BorderRadius.circular(kcRadiusMd),
          border: Border.all(
            color: highlight ? Colors.transparent : kcStrokeColor,
            width: 1,
          ),
          boxShadow: highlight ? kcShadowGlow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(kcRadiusMd),
            child: Center(
              child: Icon(
                icon,
                color: highlight ? Colors.white : kcAccentOrange,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showClearCartDialog() {
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
                    Icon(Icons.remove_shopping_cart_rounded,
                        color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'เคลียร์ตะกร้า',
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
                  'ต้องการเคลียร์ตะกร้าใช่ไหม?',
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
                        clearItem();
                        Navigator.pop(context, false);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
      ),
    );
  }

  Widget _productPanel() {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
              if (productList != null && productList!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: kcSurfaceColorHi.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(kcRadiusPill),
                    border: Border.all(color: kcStrokeColor),
                  ),
                  child: Text(
                    '${productList!.length} รายการ',
                    style: const TextStyle(
                        fontFamily: 'Kanit',
                        color: kcTextSecondary,
                        fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kcInkColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(kcRadiusSm),
            ),
            child: Row(
              children: const [
                Expanded(
                    flex: 2, child: Text("รหัสสินค้า", style: kcLabelStyle)),
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
                SizedBox(width: 36),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: productList == null || productList!.isEmpty
                ? _emptyCart()
                : Scrollbar(
                    thumbVisibility: true,
                    controller: scollBarController,
                    child: ListView.separated(
                      controller: scollBarController,
                      scrollDirection: Axis.vertical,
                      itemCount: productList!.length,
                      separatorBuilder: (_, __) => const Divider(
                          color: kcStrokeColorSoft, height: 1, thickness: 1),
                      itemBuilder: (context, index) {
                        final p = productList![index];
                        final selected = p.barcode == '$_barcode';
                        return Container(
                          decoration: BoxDecoration(
                            gradient: selected ? kcBrandGradientSoft : null,
                            borderRadius: BorderRadius.circular(kcRadiusSm),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(children: [
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
                            const SizedBox(width: 4),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: kcDangerColor, size: 20),
                              onPressed: () {
                                delItem(p.id.toString(), p.sku);
                              },
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                kcAccentOrange.withOpacity(0.15),
                Colors.transparent
              ]),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: kcAccentOrange,
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ตะกร้ายังว่าง',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 16,
              color: kcTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'สแกนสินค้าด้านขวาเพื่อเพิ่มลงตะกร้า',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              color: kcTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanAndPayPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _orderNumberCard(),
        const SizedBox(height: 12),
        _scanCard(),
        const SizedBox(height: 12),
        Expanded(child: _summaryCard()),
      ],
    );
  }

  Widget _orderNumberCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      radius: kcRadiusLg,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'เลขคำสั่งซื้อ',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 11,
                  color: kcTextMuted,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order_number ?? "—",
                style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 22,
                    color: kcTextPrimary,
                    fontWeight: FontWeight.w400),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: kcBrandGradientSoft,
              borderRadius: BorderRadius.circular(kcRadiusSm),
              border: Border.all(color: kcAccentOrange.withOpacity(0.3)),
            ),
            child:
                const Icon(Icons.tag_rounded, color: kcAccentOrange, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _scanCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2438), Color(0xFF1F1A2C)],
        ),
        borderRadius: BorderRadius.circular(kcRadiusLg),
        border: Border.all(color: kcAccentOrange.withOpacity(0.35), width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33F96349), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: VisibilityDetector(
        onVisibilityChanged: (VisibilityInfo info) {
          visible = info.visibleFraction > 0;
        },
        key: const Key('visible-detector-key'),
        child: BarcodeKeyboardListener(
          bufferDuration: const Duration(milliseconds: 100),
          onBarcodeScanned: (sbarcode) {
            if (!visible) return;

            // QR / non-barcode guard: scanners on Sunmi sometimes lock onto
            // a QR code printed next to the real product barcode. Retail
            // product codes are 1–14 digits (EAN-8 / UPC-A / EAN-13 /
            // GTIN-14). Anything else — URLs, mixed chars, very long
            // strings — is almost certainly a QR / non-product scan.
            // Show a clear message instead of sending the garbage to the
            // backend and getting a confusing "ไม่พบสินค้า" response.
            if (!RegExp(r'^\d{1,14}$').hasMatch(sbarcode)) {
              _showAlertDialog(context,
                  "กรุณาสแกนเฉพาะบาร์โค้ดสินค้า (ไม่ใช่ QR code)");
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
          },
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: kcBrandGradient,
                  borderRadius: BorderRadius.circular(kcRadiusSm),
                  boxShadow: kcShadowGlow,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'สแกนบาร์โค้ดสินค้า',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 11,
                        color: kcTextMuted,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _barcode == null ? 'พร้อมสแกน...' : _barcode!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 18,
                        color:
                            _barcode == null ? kcTextSecondary : kcTextPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Pulsing indicator dot
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: kcSuccessColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x803DD68C),
                        blurRadius: 8,
                        spreadRadius: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final qtyText = total_qty ?? "0";
    final priceText = total_price ?? "0.00";
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      radius: kcRadiusLg,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'จำนวนสินค้า',
                style: TextStyle(
                    fontFamily: 'Kanit', fontSize: 14, color: kcTextSecondary),
              ),
              Text(
                qtyText,
                style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 22,
                    color: kcTextPrimary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  kcStrokeColor,
                  kcStrokeColor,
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // The big gradient total
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ยอดรวม',
                style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 12,
                    color: kcTextMuted,
                    letterSpacing: 2),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      kcBrandGradient.createShader(bounds),
                  child: Text(
                    '฿ $priceText',
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 46,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _payButton(),
        ],
      ),
    );
  }

  Widget _payButton() {
    final enabled = _isButtonDisabled; // legacy naming: true == enabled
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kcRadiusPill),
          gradient: kcBrandGradient,
          boxShadow: enabled ? kcShadowGlow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(kcRadiusPill),
            onTap: enabled ? paymentProcess : null,
            splashColor: Colors.white24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Text(
                  'ชำระเงิน',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
