// ignore_for_file: non_constant_identifier_names, prefer_typing_uninitialized_variables, use_build_context_synchronously, depend_on_referenced_packages

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kacee_pos/Screen/Pos/components/background.dart';
import 'package:kacee_pos/Screen/Pos/second_screen.dart';
import 'package:kacee_pos/components/dailog_container.dart';
import 'package:kacee_pos/components/rounded_button_home.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:kacee_pos/constants.dart';
import 'package:kacee_pos/model/product.dart';
import 'package:kacee_pos/network_utils/api.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:crypto/crypto.dart';
import 'package:crypton/crypton.dart';

import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as nImage;
import 'package:audioplayers/audioplayers.dart';
import 'package:fdottedline_nullsafety/fdottedline__nullsafety.dart';

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
      machine_code;

  bool printBinded = false;
  int paperSize = 0;
  String serialNumber = "";
  String printerVersion = "";
  var coreItem = StringBuffer();
  var coreTotal = StringBuffer();

  final double _height = 80;
  void _scrollToIndex(index) {
    scollBarController.animateTo(_height * index,
        duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
  }

  int? _selectItem;
  int? _destinationIndex;

  @override
  void initState() {
    productList = null;
    super.initState();
    _loadSaleOrder();
    printConnect();
  }

  Future<void> printConnect() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var mac_printer = localStorage.getString("mac_printer");
    String mac = "$mac_printer";
    PrintBluetoothThermal.connect(macPrinterAddress: mac);
    final bool conecctionStatus = await PrintBluetoothThermal.connectionStatus;
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
    var id = localStorage.getString("id");
    var path = 'order/receipt/reprint/$id';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          action: SnackBarAction(
            label: 'ปิด',
            onPressed: () {
              // Code to execute.
            },
          ),
          content: const Text('ปริ้นใบเสร็จเรียบร้อย!'),
          duration: const Duration(milliseconds: 1500),
          width: 280.0, // Width of the SnackBar.
          padding: const EdgeInsets.symmetric(
            horizontal: 8.0, // Inner padding for SnackBar content.
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      );
    } else {
      var message = "ไม่พบออเดอร์";
      _showAlertDialog(context, message);
    }
    return bytes;
  }

  void _loadSaleOrder() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var id = localStorage.getString("id");
    var path = 'order/get/';
    var urlapi = Network().getSearchProduct(path);
    var response = await urlapi;
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
        cart += double.parse((i['total_price'].toString())).toStringAsFixed(3);
        cart += "\n\n";
        coreItem.write(cart);
      }
      setState(() {
        // printConnect();
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
    }
  }

  Future<bool> showExitPopup() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ออกจากระบบ'),
            content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
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
    Map<String, dynamic> request = {
      'oid': order_id,
      'barcode': code,
    };
    var path = 'order/item/add';
    var urlapi = Network().pushTransfer(path, request);
    var response = await urlapi;
    if (response.statusCode == 200) {
      setState(() {
        _loadSaleOrder();
      });
    } else {
      var message = "ไม่สามารถบันทึกได้ กรุณาติดต่อ ADMIN";
      _showAlertDialog(context, message);
      await player.play(AssetSource('sound/noproduct.mp3'));
    }
  }

  Future delItem(id, sku) async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var uid = localStorage.getString("id");
    Map<String, dynamic> requests = {
      'uid': uid,
      'oid': id,
      'sku': sku,
    };
    var path = 'order/item/del';
    var uriapi = Network().pushTransfer(path, requests);
    var response = await uriapi;
    if (response.statusCode == 200) {
      setState(() {
        _selectItem = -1;
        _loadSaleOrder();
      });
    } else {
      var message = "ไม่สามารถบันทึกได้ กรุณาติดต่อ ADMIN";
      _showAlertDialog(context, message);
    }
  }

  Future<void> clearItem() async {
    Map<String, dynamic> requests = {
      'oid': order_id,
    };
    var path = 'order/clear';
    var uriapi = Network().pushTransfer(path, requests);
    var response = await uriapi;
    if (response.statusCode == 200) {
      setState(() {
        _selectItem = -1;
        _loadSaleOrder();
      });
    } else {
      var message = "ไม่สามารถบันทึกได้ กรุณาติดต่อ ADMIN";
      _showAlertDialog(context, message);
    }
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
      String bizMchId = '1088156637107024';
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
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: RoundedButtonHome(press: () {}),
                          ),
                          SizedBox(height: size.height * 0.05),
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: IconButton(
                              alignment: Alignment.topRight,
                              icon: const Icon(Icons.remove_shopping_cart),
                              tooltip: 'เคลียร์ตะกร้า',
                              color: kcPrimaryColor,
                              onPressed: () {
                                showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        contentPadding: EdgeInsets.zero,
                                        shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(20.0))),
                                        titlePadding: const EdgeInsets.all(0),
                                        title: Container(
                                          decoration: const BoxDecoration(
                                            color: kcSecondaryColor,
                                            borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(10.0),
                                                topRight: Radius.circular(10.0),
                                                bottomLeft: Radius.circular(0.0),
                                                bottomRight:
                                                    Radius.circular(0.0)),
                                          ),
                                          height: 50,
                                          child: Container(
                                            margin:
                                                const EdgeInsets.only(top: 12.0),
                                            child: const Text(
                                              "เคลียร์ตะกร้า!",
                                              style: TextStyle(
                                                  color: kcPrimaryColor,
                                                  fontSize: 18),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        content: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Text(
                                              'ต้องการเคลียร์ตะกร้าใช่ไหม?',
                                              style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 14)),
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text('ยกเลิก',
                                                style: TextStyle(
                                                    color: Colors.red[500],
                                                    fontSize: 14)),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              clearItem();
                                              Navigator.pop(context, false);
                                            },
                                            child: const Text('ตกลง',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 14)),
                                          ),
                                        ],
                                      );
                                    });
                              },
                            ),
                          ),
                          SizedBox(height: size.height * 0.01),
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: IconButton(
                              color: kcPrimaryColor,
                              icon: const Icon(Icons.print_rounded),
                              tooltip: 'พิมพ์อีกครั้ง',
                              onPressed: () {
                                printFocus();
                              },
                            ),
                          ),
                          // ElevatedButton.icon(
                          //   onPressed: () {
                          //     printFocus();
                          //   },
                          //   style: const ButtonStyle(
                          //     backgroundColor: MaterialStatePropertyAll<Color>(
                          //         kcBackgroundColor),
                          //   ),
                          //   icon: const Icon(
                          //     Icons.print_rounded,
                          //     size: 24.0,
                          //     color: kcPrimaryColor,
                          //   ),
                          //   label: const Text(
                          //     'พิมพ์อีกครั้ง',
                          //   ), // <-- Text
                          // ),
                          const SizedBox(
                            height: 222,
                          ),
                          Column(children: [
                            Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50.0),
                                  border: Border.all(
                                    color:
                                        Colors.white38, // Change the border color
                                    width: 1.0, // Change the border width
                                    style: BorderStyle
                                        .solid, // Change the border style
                                  )),
                              width: 100,
                              height: 25,
                              alignment: Alignment.center,
                              child: Row(children: [
                                const Padding(
                                  padding: EdgeInsets.all(1.0),
                                  child: CircleAvatar(
                                    backgroundColor:
                                        kcPrimaryColor, // Customize the CircleAvatar background color
                                    radius:
                                        12, // Adjust the radius to fit within the Container
                                    child: Icon(
                                      Icons
                                          .storefront, // You can replace this with your desired icon
                                      color: Colors.white, // Customize the icon color
                                      size: 14, // Customize the icon size
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    'Shop : $shop_code',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50.0),
                                  border: Border.all(
                                      color: Colors.white38,
                                      width: 1.0,
                                      style: BorderStyle.solid)),
                              width: 100,
                              height: 25,
                              alignment: Alignment.center,
                              child: Row(children: [
                                const Padding(
                                  padding: EdgeInsets.all(1.0),
                                  child: CircleAvatar(
                                    backgroundColor:
                                        kcPrimaryColor, // Customize the CircleAvatar background color
                                    radius:
                                        12, // Adjust the radius to fit within the Container
                                    child: Icon(
                                      Icons
                                          .monitor, // You can replace this with your desired icon
                                      color:Colors.white, // Customize the icon color
                                      size: 14, // Customize the icon size
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    'Pos : $machine_code',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                              ]),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 13,
                      child: Column(children: [
                        Container(
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(top: 20, left: 30),
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
                          padding: const EdgeInsets.only(top: 5, left: 30),
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
                          padding: const EdgeInsets.only(top: 15, left: 30),
                          child: Column(
                            children: [
                              SizedBox(height: size.height * 0.01),
                              const Text(
                                "รายการสินค้า",
                                style: TextStyle(
                                    fontWeight: FontWeight.w200,
                                    fontSize: 20,
                                    color: kcPrimaryColor),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.only(top: 10, left: 20),
                          child: const Divider(color: Colors.white12),
                        ),
                        Container(
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(left: 20),
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
                            trailing: const Text(
                              'แก้ไข',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Divider(color: Colors.white12),
                        ),
                        Container(
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(top: 10, left: 20),
                          height: 450,
                          child: Scrollbar(
                            isAlwaysShown: true,
                            controller: scollBarController,
                            child: ListView.builder(
                              controller: scollBarController,
                              scrollDirection: Axis.vertical,
                              shrinkWrap: true,
                              itemCount:
                                  productList == null ? 0 : productList?.length,
                              itemBuilder: (context, index) => Container(
                                color:
                                    productList![index].barcode == '$_barcode'
                                        ? Colors.white30
                                        : null,
                                child: ListTile(
                                  textColor: Colors.white70,
                                  visualDensity: VisualDensity(vertical: -3),
                                  onTap: () {},
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
                                            color: Colors.white,
                                          ),
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
                                  trailing: IconButton(
                                    color: kcPrimaryColor,
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      delItem(productList![index].id.toString(),
                                          productList![index].sku);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          Container(
                              // color: kcBackgroundColor,
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Container(
                                    alignment: Alignment.topLeft,
                                    padding: const EdgeInsets.only(
                                        top: 10, left: 20),
                                    child: Column(children: [
                                      SizedBox(height: size.height * 0.02),
                                      const Text(
                                        "คำสั่งซ์้อที่",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w200,
                                            fontSize: 15,
                                            color: Colors.white70),
                                      ),
                                    ]),
                                  ),
                                  Container(
                                    alignment: Alignment.topLeft,
                                    padding: const EdgeInsets.only(
                                        left: 20, bottom: 13),
                                    child: Column(children: [
                                      Text(
                                        order_number.toString(),
                                        style: const TextStyle(
                                            fontSize: 25, color: Colors.white),
                                      ),
                                    ]),
                                  ),
                                  Card(
                                    color: kcBackgroundColor,
                                    child: Container(
                                      alignment: Alignment.topLeft,
                                      padding: const EdgeInsets.only(top: 10),
                                      child: VisibilityDetector(
                                        onVisibilityChanged:
                                            (VisibilityInfo info) {
                                          visible = info.visibleFraction > 0;
                                        },
                                        key: const Key('visible-detector-key'),
                                        child: BarcodeKeyboardListener(
                                          bufferDuration:
                                              const Duration(milliseconds: 100),
                                          onBarcodeScanned: (sbarcode) {
                                            if (!visible) return;
                                            setState(() {
                                              if (sbarcode != '0088300607402' &&
                                                  sbarcode != '047469058654') {
                                                var _bar = int.parse(sbarcode);
                                                String barcode =
                                                    _bar.toString();
                                                searchProduct(barcode);
                                                _barcode = barcode;
                                              } else {
                                                searchProduct(sbarcode);
                                                _barcode = sbarcode;
                                              }
                                              _selectItem = 1;
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10, left: 20),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: <Widget>[
                                                Text(
                                                  _barcode == null
                                                      ? 'สแกนสินค้า'
                                                      : 'key: $_barcode',
                                                  style: tableB,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Card(
                                    elevation: 0,
                                    color: kcBackgroundColor,
                                    child: SizedBox(
                                      height: 530,
                                      child: Column(
                                        children: [
                                          Container(
                                            alignment: Alignment.topLeft,
                                            padding: const EdgeInsets.only(
                                                left: 20, top: 10),
                                            child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    "จำนวนสินค้า ",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w200,
                                                        fontSize: 15,
                                                        color: Colors.white70),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 20),
                                                    child: Text(
                                                      " $total_qty ",
                                                      textAlign: TextAlign.end,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w200,
                                                          fontSize: 20,
                                                          color: Colors.white),
                                                    ),
                                                  ),
                                                  // const Text(
                                                  //   " ชิ้น",
                                                  //   style: TextStyle(
                                                  //       fontWeight: FontWeight.w200,
                                                  //       fontSize: 20,
                                                  //       color: Colors.white70),
                                                  // ),
                                                ]),
                                          ),
                                          // Container(
                                          //   alignment: Alignment.topLeft,
                                          //   padding: const EdgeInsets.only(
                                          //       left: 20, top: 15),
                                          //   child: Row(
                                          //       mainAxisAlignment:
                                          //           MainAxisAlignment
                                          //               .spaceBetween,
                                          //       children: const [
                                          //         Text(
                                          //           "น้ำหนักรวม",
                                          //           style: TextStyle(
                                          //               fontWeight:
                                          //                   FontWeight.w200,
                                          //               fontSize: 15,
                                          //               color: Colors.white70),
                                          //         ),
                                          //         Padding(
                                          //           padding: EdgeInsets.only(
                                          //               right: 20),
                                          //           child: Text(
                                          //             "15.5 g",
                                          //             style: TextStyle(
                                          //                 fontWeight:
                                          //                     FontWeight.w200,
                                          //                 fontSize: 15,
                                          //                 color: Colors.white),
                                          //           ),
                                          //         ),
                                          //         // const Text(
                                          //         //   "บาท ",
                                          //         //   style: TextStyle(
                                          //         //       fontWeight: FontWeight.w200,
                                          //         //       fontSize: 20,
                                          //         //       color: Colors.white70),
                                          //         // ),
                                          //       ]),
                                          // ),
                                          // Container(
                                          //   alignment: Alignment.topLeft,
                                          //   padding: const EdgeInsets.only(
                                          //       left: 20, top: 15),
                                          //   child: Row(
                                          //       mainAxisAlignment:
                                          //           MainAxisAlignment
                                          //               .spaceBetween,
                                          //       children: const [
                                          //         Text(
                                          //           "น้ำหนักที่ชั่ง",
                                          //           style: TextStyle(
                                          //               fontWeight:
                                          //                   FontWeight.w200,
                                          //               fontSize: 15,
                                          //               color: Colors.white70),
                                          //         ),
                                          //         Padding(
                                          //           padding: EdgeInsets.only(
                                          //               right: 20),
                                          //           child: Text(
                                          //             "12.3 g",
                                          //             style: TextStyle(
                                          //                 fontWeight:
                                          //                     FontWeight.w200,
                                          //                 fontSize: 15,
                                          //                 color: Colors.white),
                                          //           ),
                                          //         ),
                                          //         // const Text(
                                          //         //   "บาท ",
                                          //         //   style: TextStyle(
                                          //         //       fontWeight: FontWeight.w200,
                                          //         //       fontSize: 20,
                                          //         //       color: Colors.white70),
                                          //         // ),
                                          //       ]),
                                          // ),
                                          const SizedBox(
                                            height: 24,
                                          ),
                                          FDottedLine(
                                            color: Colors.white70,
                                            width: 290.0,
                                            strokeWidth: 1.5,
                                            dottedLength: 3.0,
                                            space: 2.0,
                                          ),
                                          Container(
                                            alignment: Alignment.topLeft,
                                            padding: const EdgeInsets.only(
                                                left: 20, top: 15),
                                            child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    "ราคารวม ",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w200,
                                                        fontSize: 20,
                                                        color: Colors.white70),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 20),
                                                    child: Text(
                                                      "฿$total_price",
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w200,
                                                          fontSize: 25,
                                                          color:
                                                              kcPrimaryColor),
                                                    ),
                                                  ),
                                                  // const Text(
                                                  //   "บาท ",
                                                  //   style: TextStyle(
                                                  //       fontWeight: FontWeight.w200,
                                                  //       fontSize: 20,
                                                  //       color: Colors.white70),
                                                  // ),
                                                ]),
                                          ),
                                          Container(
                                            alignment: Alignment.topCenter,
                                            padding: const EdgeInsets.only(
                                                top: 320, left: 10, bottom: 38),
                                            child: Column(children: [
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor:
                                                      kcPrimaryColor,
                                                  shadowColor: Colors.redAccent,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              32.0)),
                                                  minimumSize: const Size(
                                                      200, 40), //////// HERE
                                                ),
                                                onPressed: () {
                                                  QRPayment();
                                                },
                                                child: const Text('ชำระเงิน',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18)),
                                              ),
                                            ]),
                                          ),
                                        ],
                                      ),
                                    ),
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
    );
  }
}
