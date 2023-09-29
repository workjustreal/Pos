// ignore_for_file: prefer_typing_uninitialized_variables

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Network {
  final String _url = 'http://192.168.2.12:1145/api/self-checkout/';
  final String _uri = 'http://192.168.2.12:1145/api/auth/login';
  final String _upay = 'https://api.krungsri.com/native/QRPayment/';
  var data, token, fullUrl, urlAPI, uid;

  _getToken() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    token = localStorage.getString("token");
  }

  _getUUID() async {
    var uuid = const Uuid();
    uid = uuid.v4();
  }

  authData(data, apiUrl) async {
    fullUrl = _url + apiUrl;
    return await http.post(fullUrl,
        body: jsonEncode(data), headers: _setHeaders());
  }

  pushTransfer(apiUrl, data) async {
    fullUrl = _url + apiUrl;
    urlAPI = Uri.parse(fullUrl);
    await _getToken();
    return await http.post(urlAPI,
        body: jsonEncode(data), headers: _setHeaders());
  }

  paymentTransfer(apiUrl, data) async {
    fullUrl = _upay + apiUrl;
    urlAPI = Uri.parse(fullUrl);
    await _getUUID();
    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    final http = IOClient(ioc);
    return http.post(urlAPI, body: jsonEncode(data), headers: _setHead());
  }

  getSearchProduct(apiUrl) async {
    fullUrl = _url + apiUrl;
    urlAPI = Uri.parse(fullUrl);
    await _getToken();
    return await http.get(urlAPI, headers: _setHeaders());
  }

  getCancelOrder(apiUrl, oid) async {
    fullUrl = _url + apiUrl;
    urlAPI = Uri.parse(fullUrl);
    await _getToken();
    return await http.post(urlAPI,
        body: jsonEncode(oid), headers: _setHeaders());
  }

  getLogin(user) async {
    data = user;
    urlAPI = Uri.parse(_uri);
    return await http.post(urlAPI, body: data);
  }

  _setHeaders() => {
        'Content-type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token'
      };

  _setHead() => {
        // 'API-Key': 'l7034f3920fc2144b28ec981986a5d3c9c', //uat
        'API-Key': 'l7d16e70f0023745b297aaf6c0caddd0ea',
        'X-Client-Transaction-ID': '$uid',
        'Content-Type': 'application/json',
      };
}
