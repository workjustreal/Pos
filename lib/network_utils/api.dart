// ignore_for_file: prefer_typing_uninitialized_variables

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:kacee_pos/network_utils/krungsri_ca.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Network {
  // Reuse a single HTTP client across requests so the underlying TCP socket
  // stays warm (keep-alive). This dramatically reduces per-request latency
  // for the once-per-second payment polling on slow networks.
  static final http.Client _httpClient = http.Client();
  static IOClient? _payClient;

  // Without a timeout a stalled socket can hang for minutes — and because
  // SecondScreen guards polling with `_isPolling`, one hung request would
  // stop payment detection entirely. Callers must catch TimeoutException.
  static const Duration _timeout = Duration(seconds: 15);

  static IOClient _getPayClient() {
    return _payClient ??=
        IOClient(HttpClient(context: _krungsriSecurityContext()));
  }

  /// Full TLS verification: the system trust store plus the bundled
  /// DigiCert root, so old Android builds missing that root still connect.
  /// Never accept bad certificates here — a forged api.krungsri.com could
  /// swap the payment QR for an attacker's account.
  static SecurityContext _krungsriSecurityContext() {
    final context = SecurityContext(withTrustedRoots: true);
    try {
      context.setTrustedCertificatesBytes(utf8.encode(digiCertGlobalRootG2));
    } on TlsException catch (e) {
      // Some platforms reject a root that's already in the system store;
      // verification still works via the system roots.
      // ignore: avoid_print
      print('Krungsri CA not added (system roots still apply): $e');
    }
    return context;
  }

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

  pushTransfer(apiUrl, data) async {
    fullUrl = _url + apiUrl;
    urlAPI = Uri.parse(fullUrl);
    await _getToken();
    return await _httpClient
        .post(urlAPI, body: jsonEncode(data), headers: _setHeaders())
        .timeout(_timeout);
  }

  paymentTransfer(apiUrl, data) async {
    fullUrl = _upay + apiUrl;
    urlAPI = Uri.parse(fullUrl);
    await _getUUID();
    return _getPayClient()
        .post(urlAPI, body: jsonEncode(data), headers: _setHead())
        .timeout(_timeout);
  }

  getSearchProduct(apiUrl) async {
    fullUrl = _url + apiUrl;
    urlAPI = Uri.parse(fullUrl);
    await _getToken();
    return await _httpClient
        .get(urlAPI, headers: _setHeaders())
        .timeout(_timeout);
  }

  getCancelOrder(apiUrl, oid) async {
    fullUrl = _url + apiUrl;
    urlAPI = Uri.parse(fullUrl);
    await _getToken();
    return await _httpClient
        .post(urlAPI, body: jsonEncode(oid), headers: _setHeaders())
        .timeout(_timeout);
  }

  getLogin(user) async {
    data = user;
    urlAPI = Uri.parse(_uri);
    return await _httpClient.post(urlAPI, body: data).timeout(_timeout);
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
