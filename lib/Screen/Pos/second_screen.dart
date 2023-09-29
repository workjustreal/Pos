// ignore_for_file: non_constant_identifier_names, prefer_typing_uninitialized_variables, use_build_context_synchronously, depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:intl/intl.dart';
import 'package:kacee_pos/Screen/Pos/components/background.dart';
import 'package:kacee_pos/Screen/Pos/end_screen.dart';
import 'package:kacee_pos/Screen/Pos/main_screen.dart';
import 'package:kacee_pos/components/dailog_container.dart';
import 'package:kacee_pos/components/dailog_warning_container.dart';
import 'package:kacee_pos/components/rounded_button_home.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/model/product.dart';
import 'package:kacee_pos/network_utils/api.dart';
import 'package:page_transition/page_transition.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:crypto/crypto.dart';
import 'package:crypton/crypton.dart';

import 'dart:io';
import 'package:image/image.dart' as nImage;

class SecondScreen extends StatefulWidget {
  const SecondScreen({Key? key}) : super(key: key);
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
  late Timer _timer;

  @override
  void initState() {
    productList = null;
    super.initState();
    _loadSaleOrder();
    // _startTimer();
    printConnect();
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
      String amount = '0.01';
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
        setState(() {
          Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (BuildContext context) {
            return const SecondScreen();
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
    print(response.statusCode);
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      List item = jsonResponse['data']['items'];

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
        order_id = jsonResponse['data']['order_id'].toString();
        order_number = jsonResponse['data']['order_number'];
        total_qty = jsonResponse['data']['total_qty'].toString();
        total_price = jsonResponse['data']['total_price'].toString();
        coreTotal.write(total_price);
        productList = item
            .map<Product>((m) => Product.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        qr = localStorage.getString("qrcodeContent");
        trx = localStorage.getString("trxId");
        saveLogs(order_id, trx);
      });
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
            title: const Text('แจ้งเตือน'),
            content: const Text('คุณต้องการกลับไปแก้ไขรายการสินค้าใช่หรือไม่?'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.white),
                    backgroundColor:
                        MaterialStateProperty.all<Color>(Colors.green),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            side: const BorderSide(color: Colors.green)))),
                child: const Text('ไม่'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.white),
                    backgroundColor:
                        MaterialStateProperty.all<Color>(Colors.red),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            side: const BorderSide(color: Colors.red)))),
                child: const Text('ใช่'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _checkCallback() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var id = localStorage.getString("order_id");
    var path = 'payment/complete/$id';
    var urlapi = Network().getSearchProduct(path);
    var response = await urlapi;
    // print(response.statusCode);
    if (response.statusCode == 200) {
      printFocus();
      // _timer.cancel();
      setState(() {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (BuildContext context) {
          return const EndScreen();
        }), (r) {
          return false;
        });
      });
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

  // void _startTimer() {
  //   const duration = Duration(seconds: 1);
  //   _timer = Timer.periodic(duration, (Timer timer) {
  //     setState(() {
  //       _currentSecond = timer.tick;
  //       _checkCallback();

  //       if (timer.tick >= _maxSeconds) {
  //         _checkCallback();
  //         timer.cancel();
  //         showDialog(
  //           context: context,
  //           builder: (BuildContext context) => AlertDialog(
  //             shape: const RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.all(Radius.circular(20.0))),
  //             // titlePadding: const EdgeInsets.all(0),
  //             title: Container(
  //               decoration: const BoxDecoration(
  //                 color: kcSecondaryColor,
  //                 borderRadius: BorderRadius.only(
  //                     topLeft: Radius.circular(10.0),
  //                     topRight: Radius.circular(10.0),
  //                     bottomLeft: Radius.circular(0.0),
  //                     bottomRight: Radius.circular(0.0)),
  //               ),
  //               height: 50,
  //               child: const Padding(
  //                 padding: EdgeInsets.only(
  //                   top: 12,
  //                 ),
  //                 child: Text(
  //                   'แจ้งเตือน',
  //                   style: TextStyle(color: Colors.white, fontSize: 18),
  //                   textAlign: TextAlign.center,
  //                 ),
  //               ),
  //             ),
  //             titlePadding: const EdgeInsets.all(0),
  //             content: const Text(
  //               'ท่านไม่ได้ชำระเงินภายในระยะเวลาที่กำหนด',
  //               style: TextStyle(fontSize: 14),
  //             ),
  //             actions: <Widget>[
  //               TextButton(
  //                 onPressed: () {
  //                   cancelOrder();
  //                 },
  //                 child: const Text(
  //                   'ยกเลิกคำสั่งซิ้อ',
  //                   style: TextStyle(color: Colors.red, fontSize: 14),
  //                 ),
  //               ),
  //               TextButton(
  //                 // onPressed: () => Navigator.pop(context, 'OK'),
  //                 onPressed: () {
  //                   QRPayment();
  //                 },
  //                 child: const Text('ชำระเงินอีกครั้ง'),
  //               ),
  //             ],
  //           ),
  //         );
  //       }
  //     });
  //   });
  // }

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

  Future<void> printConnect() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var mac_printer = localStorage.getString("mac_printer");
    String mac = "$mac_printer";
    PrintBluetoothThermal.connect(macPrinterAddress: mac);
    const PaperSize paper = PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    bool conecctionStatus = await PrintBluetoothThermal.connectionStatus;
    if (conecctionStatus) {
      print("Connect");
    } else {
      //no connected
      print("No connect");
    }
  }

  Future<void> printFocus() async {
    const PaperSize paper = PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    bool conecctionStatus = await PrintBluetoothThermal.connectionStatus;
    if (conecctionStatus) {
      List<int> ticket = await printTicket(paper, profile);
      PrintBluetoothThermal.writeBytes(ticket);
    } else {
      //no connected
      print("No connect");
    }
  }

  Future<List<int>> printTicket(
      PaperSize paper, CapabilityProfile profile) async {
    final Generator ticket = Generator(paper, profile);
    List<int> bytes = [];
    bytes += ticket.reset();
    bytes += ticket.setGlobalCodeTable('CP1250');

    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var id = localStorage.getString("order_id");
    var path = 'order/receipt/$id';
    var urlapi = Network().getSearchProduct(path);
    var response = await urlapi;
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      var item = jsonResponse['data'];
      Uint8List unit8List = await base64Decode(item);
      final nImage.Image? image = nImage.decodeImage(unit8List);
      nImage.Image resized =
          nImage.copyResize(image!, width: 380, height: image.height + 50);
      bytes += ticket.imageRaster(resized, align: PosAlign.center);
      bytes += ticket.feed(1);
      bytes += ticket.cut();
    } else {
      print("Print Fielded.");
    }
    return bytes;
  }

  // Reading bytes from a network image
  Future<Uint8List> readNetworkImage(String imageUrl) async {
    final ByteData data =
        await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl);
    final Uint8List bytes = data.buffer.asUint8List();
    return bytes;
  }

  @override
  void dispose() {
    // _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('EEEEE d MMM yyyy').format(now);
    Size size = MediaQuery.of(context).size;
    return WillPopScope(
      onWillPop: showExitPopup,
      child: Scaffold(
        backgroundColor: kcDarkColor,
        body: Background(
          child: SingleChildScrollView(
            child: Opacity(
              opacity: 1,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            SizedBox(height: size.height * 0.25),
                            RoundedButtonHome(press: () {}),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 13,
                        child: Column(children: [
                          Container(
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(top: 20, left: 40),
                            child: Column(
                              children: [
                                SizedBox(height: size.height * 0.01),
                                const Text(
                                  "KACEE SELF CHECKOUT",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w200,
                                      fontSize: 30,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(top: 10, left: 10),
                            child: VisibilityDetector(
                              onVisibilityChanged: (VisibilityInfo info) {
                                visible = info.visibleFraction > 0;
                              },
                              key: const Key('visible-detector-key'),
                              child: BarcodeKeyboardListener(
                                bufferDuration:
                                    const Duration(milliseconds: 100),
                                onBarcodeScanned: (barcode) {
                                  if (!visible) return;
                                  setState(() {});
                                },
                                child: Column(),
                              ),
                            ),
                          ),
                          Container(
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(top: 5, left: 40),
                            child: Column(
                              children: [
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w200,
                                      fontSize: 15,
                                      color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(top: 15, left: 40),
                            child: Column(
                              children: [
                                SizedBox(height: size.height * 0.01),
                                Text(
                                  "เลขคำสั่งซื้อ : $order_number",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w200,
                                      fontSize: 20,
                                      color: kcPrimaryColor),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.only(top: 10, left: 30),
                            child: const Divider(color: Colors.white12),
                          ),
                          Container(
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(left: 30),
                            child: ListTile(
                              textColor: Colors.white,
                              title: Row(children: const <Widget>[
                                Expanded(
                                    flex: 1,
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text("รหัสสินค้า"))),
                                Expanded(
                                    flex: 3,
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text("ชื่อ"))),
                                Expanded(
                                    flex: 1,
                                    child: Align(
                                        alignment: Alignment.center,
                                        child: Text("ราคา"))),
                                Expanded(
                                    flex: 1,
                                    child: Align(
                                        alignment: Alignment.center,
                                        child: Text("จำนวน"))),
                                Expanded(
                                    flex: 1,
                                    child: Align(
                                        alignment: Alignment.center,
                                        child: Text("ราคารวม"))),
                              ]),
                            ),
                          ),
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.only(left: 30),
                            child: const Divider(color: Colors.white12),
                          ),
                          Container(
                            alignment: Alignment.topLeft,
                            height: 360,
                            padding: const EdgeInsets.only(top: 10, left: 30),
                            child: Scrollbar(
                              isAlwaysShown: true,
                              controller: scollBarController,
                              child: ListView.builder(
                                controller: scollBarController,
                                scrollDirection: Axis.vertical,
                                shrinkWrap: true,
                                itemCount: productList == null
                                    ? 0
                                    : productList?.length,
                                itemExtent: 40.0,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    textColor: Colors.white70,
                                    onTap: null,
                                    title: Row(children: <Widget>[
                                      Expanded(
                                        flex: 1,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            productList![index].sku,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w200,
                                                fontSize: 12,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            productList![index].name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w200,
                                                fontSize: 12,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Align(
                                          alignment: Alignment.center,
                                          child: Text(
                                            productList![index].price,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w200,
                                                fontSize: 12,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Align(
                                          alignment: Alignment.center,
                                          child: Text(
                                            productList![index].qty,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w200,
                                                fontSize: 12,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Align(
                                          alignment: Alignment.center,
                                          child: Text(
                                            productList![index].totalprice,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w200,
                                                fontSize: 12,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  );
                                },
                              ),
                            ),
                          ),
                          Container(
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(top: 20, right: 35),
                            child: Row(children: [
                              const Expanded(
                                child: Text(
                                  " ",
                                ),
                              ),
                              const Text(
                                "ราคารวม ",
                                style: TextStyle(
                                    fontWeight: FontWeight.w200,
                                    fontSize: 15,
                                    color: Colors.white70),
                              ),
                              Text(
                                " $total_price ",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w200,
                                    fontSize: 30,
                                    color: kcPrimaryColor),
                              ),
                              const Text(
                                "บาท ",
                                style: TextStyle(
                                    fontWeight: FontWeight.w200,
                                    fontSize: 15,
                                    color: Colors.white70),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                      Expanded(
                        flex: 7,
                        child: Column(
                          children: [
                            Container(
                                color: kcBackgroundColor,
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    Container(
                                      alignment: Alignment.topCenter,
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Column(children: [
                                        SizedBox(height: size.height * 0.02),
                                        const Text(
                                          "ขั้นตอนการชำระเงิน ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w200,
                                              fontSize: 30,
                                              color: Colors.white),
                                        ),
                                      ]),
                                    ),
                                    Container(
                                      alignment: Alignment.topLeft,
                                      padding: const EdgeInsets.only(left: 72),
                                      child: Column(children: [
                                        SizedBox(height: size.height * 0.02),
                                        const Text(
                                          "1.เปิดแอพฯธนาคารที่ท่านสะดวก\n2.สแกนคิวอาร์โค้ดด้านล่าง\n3.ยืนยันการชำระเงินในแอพฯธนาคาร\n4.รอรับใบเสร็จ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w200,
                                              fontSize: 15,
                                              color: Colors.white70),
                                        ),
                                      ]),
                                    ),
                                    // Container(
                                    //   alignment: Alignment.topCenter,
                                    //   padding: const EdgeInsets.only(top: 20),
                                    //   child: Column(
                                    //     children: <Widget>[
                                    //       Text(
                                    //         "ชำระเงินภายใน  $_timerText ",
                                    //         style: const TextStyle(
                                    //             fontWeight: FontWeight.w200,
                                    //             fontSize: 15,
                                    //             color: Colors.yellow),
                                    //       ),
                                    //     ],
                                    //   ),
                                    // ),
                                    // Container(
                                    //   alignment: Alignment.topCenter,
                                    //   padding: const EdgeInsets.only(top: 10),
                                    //   child: Column(
                                    //     children: <Widget>[
                                    //       Image.asset(
                                    //           "assets/images/qr_header.jpg",
                                    //           width: 250.0),
                                    //     ],
                                    //   ),
                                    // ),
                                    // Container(
                                    //   alignment: Alignment.topCenter,
                                    //   child: Column(
                                    //     children: [
                                    //       QrImage(
                                    //         backgroundColor: Colors.white,
                                    //         data: qr.toString(),
                                    //         version: QrVersions.auto,
                                    //         size: 250.0,
                                    //         errorCorrectionLevel:
                                    //             QrErrorCorrectLevel.L,
                                    //         // embeddedImage: const AssetImage(
                                    //         //     "assets/images/qr_logo.png"),
                                    //         // embeddedImageStyle:  QrEmbeddedImageStyle( size: const Size(50, 50),
                                    //         // ),
                                    //       ),
                                    //     ],
                                    //   ),
                                    // ),
                                    // Container(
                                    //   alignment: Alignment.topCenter,
                                    //   child: Column(
                                    //     children: <Widget>[
                                    //       Image.asset(
                                    //           "assets/images/qr_footer.png",
                                    //           width: 250.0),
                                    //     ],
                                    //   ),
                                    // ),
                                    Container(
                                      alignment: Alignment.topCenter,
                                      padding: const EdgeInsets.only(
                                          top: 260, left: 10, bottom: 38),
                                      child: Column(children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            backgroundColor: kcPrimaryColor,
                                            shadowColor: Colors.redAccent,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        32.0)),
                                            minimumSize: const Size(
                                                200, 40), //////// HERE
                                          ),
                                          onPressed: () {
                                            _checkCallback();
                                          },
                                          child: const Text('เสร็จสิ้น',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18)),
                                        ),
                                      ]),
                                    ),
                                    Container(
                                      alignment: Alignment.topCenter,
                                      padding: const EdgeInsets.only(
                                          top: 30, left: 72, bottom: 48),
                                      child: Row(children: [
                                        // SizedBox(
                                        //   child: ElevatedButton(
                                        //     style: ElevatedButton.styleFrom(
                                        //       foregroundColor: Colors.white,
                                        //       backgroundColor: Colors.black45,
                                        //       shadowColor:
                                        //           Colors.lightBlueAccent,
                                        //       shape: RoundedRectangleBorder(
                                        //           borderRadius:
                                        //               BorderRadius.circular(
                                        //                   32.0)),
                                        //       minimumSize: const Size(
                                        //           100, 35), //////// HERE
                                        //     ),
                                        //     onPressed: () {
                                        //       showDialog(
                                        //           context: context,
                                        //           builder:
                                        //               (BuildContext context) {
                                        //             return AlertDialog(
                                        //               contentPadding:
                                        //                   EdgeInsets.zero,
                                        //               shape: const RoundedRectangleBorder(
                                        //                   borderRadius:
                                        //                       BorderRadius.all(
                                        //                           Radius.circular(
                                        //                               20.0))),
                                        //               titlePadding:
                                        //                   const EdgeInsets.all(
                                        //                       0),
                                        //               title: Container(
                                        //                 decoration:
                                        //                     const BoxDecoration(
                                        //                   color:
                                        //                       kcSecondaryColor,
                                        //                   borderRadius: BorderRadius.only(
                                        //                       topLeft:
                                        //                           Radius
                                        //                               .circular(
                                        //                                   10.0),
                                        //                       topRight:
                                        //                           Radius
                                        //                               .circular(
                                        //                                   10.0),
                                        //                       bottomLeft: Radius
                                        //                           .circular(
                                        //                               0.0),
                                        //                       bottomRight:
                                        //                           Radius
                                        //                               .circular(
                                        //                                   0.0)),
                                        //                 ),
                                        //                 height: 50,
                                        //                 child: Container(
                                        //                   margin:
                                        //                       const EdgeInsets
                                        //                               .only(
                                        //                           top: 12.0),
                                        //                   child: const Text(
                                        //                     "แจ้งเตือน",
                                        //                     style: TextStyle(
                                        //                         color: Colors
                                        //                             .white,
                                        //                         fontSize: 18),
                                        //                     textAlign: TextAlign
                                        //                         .center,
                                        //                   ),
                                        //                 ),
                                        //               ),
                                        //               content: Padding(
                                        //                 padding:
                                        //                     const EdgeInsets
                                        //                         .all(20.0),
                                        //                 child: Text(
                                        //                     'ต้องการกลับไปแก้ไขคำสั๋งซื้อ ใช่หรือไม่',
                                        //                     style: TextStyle(
                                        //                         color: Colors
                                        //                             .grey[700],
                                        //                         fontSize: 14)),
                                        //               ),
                                        //               actions: <Widget>[
                                        //                 TextButton(
                                        //                   onPressed: () {
                                        //                     setState(() {
                                        //                       _timer.cancel();
                                        //                       Navigator.pushAndRemoveUntil(
                                        //                           context,
                                        //                           MaterialPageRoute(builder:
                                        //                               (BuildContext
                                        //                                   context) {
                                        //                         return const MainScreen();
                                        //                       }), (r) {
                                        //                         return false;
                                        //                       });
                                        //                     });
                                        //                   },
                                        //                   child: const Text(
                                        //                       'ตกลง',
                                        //                       style: TextStyle(
                                        //                           color: Colors
                                        //                               .black,
                                        //                           fontSize:
                                        //                               14)),
                                        //                 ),
                                        //                 TextButton(
                                        //                   onPressed: () =>
                                        //                       Navigator.pop(
                                        //                           context,
                                        //                           false),
                                        //                   child: Text('ยกเลิก',
                                        //                       style: TextStyle(
                                        //                           color: Colors
                                        //                               .red[500],
                                        //                           fontSize:
                                        //                               14)),
                                        //                 ),
                                        //               ],
                                        //             );
                                        //           });
                                        //     },
                                        //     child: const Text('ย้อนกลับ',
                                        //         style: TextStyle(
                                        //             color: Colors.white)),
                                        //   ),
                                        // ),
                                        const SizedBox(
                                          width: 20,
                                        ),
                                        SizedBox(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor: Colors.black45,
                                              shadowColor: Colors.redAccent,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          32.0)),
                                              minimumSize: const Size(200, 35),
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    return AlertDialog(
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      shape: const RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius.circular(
                                                                      20.0))),
                                                      titlePadding:
                                                          const EdgeInsets.all(
                                                              0),
                                                      title: Container(
                                                        decoration:
                                                            const BoxDecoration(
                                                          color:
                                                              kcSecondaryColor,
                                                          borderRadius: BorderRadius.only(
                                                              topLeft:
                                                                  Radius
                                                                      .circular(
                                                                          10.0),
                                                              topRight:
                                                                  Radius
                                                                      .circular(
                                                                          10.0),
                                                              bottomLeft: Radius
                                                                  .circular(
                                                                      0.0),
                                                              bottomRight:
                                                                  Radius
                                                                      .circular(
                                                                          0.0)),
                                                        ),
                                                        height: 50,
                                                        child: Container(
                                                          margin:
                                                              const EdgeInsets
                                                                      .only(
                                                                  top: 12.0),
                                                          child: const Text(
                                                            "แจ้งเตือน",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 18),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                      ),
                                                      content: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(20.0),
                                                        child: Text(
                                                            'ต้องการยกเลิกรายการ ใช่หรือไม่',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey[700],
                                                                fontSize: 14)),
                                                      ),
                                                      actions: <Widget>[
                                                        TextButton(
                                                          onPressed: () {
                                                            setState(() {
                                                              // _timer.cancel();
                                                              cancelOrder();
                                                            });
                                                          },
                                                          child: const Text(
                                                              'ตกลง',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .black,
                                                                  fontSize:
                                                                      14)),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  false),
                                                          child: Text('ยกเลิก',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red[500],
                                                                  fontSize:
                                                                      14)),
                                                        ),
                                                      ],
                                                    );
                                                  });
                                            },
                                            child: const Text('ยกเลิก',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ),
                                        ),
                                      ]),
                                    ),
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ],
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
