import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:crypton/crypton.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kacee_pos/network_utils/api.dart';

/// Krungsri QR Payment — builds and signs requests for `trans/precreate`
/// and `trans/detail`. Single source of truth for the merchant config that
/// used to be copy-pasted into MainScreen and SecondScreen.
class KrungsriPaymentService {
  // Production merchant config.
  // UAT: bizMchId '1088156774177478', pubKey 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCe1AS2Cmt24Nu6rcbG5q5whL5Yt1BtSi4r5nJKIL+UcKEWH3jMJFO029xxZdPeOzo6EkeFRKeJkfKRUDGDOjlNRQSp2uK85fLt0y09B2nemru3IIpMEgCr5VcWdxlzNE/K6WGVYn2z5WM54viFLOF8oqL7f8A8iQyy4h/BAXzIdQIDAQAB'
  static const String bizMchId = '1088156637107024';
  static const String _pubKey =
      'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC0LhvtMyXZFBEw2ePMYrZfDQhGdgLjx2Ls8JCovMk48zcMlWk/yuImicxl7bKW6syXGQScByRaFjcQrPMk6RLDcFtpsTo+vkbCY/0A6STTBepsS4lWtB2bAOgWPuHI+hblccWiRUGHKf2P9bWSq6Yb5xJe0EuLfVtm42xNtdTpAQIDAQAB';
  static const String _billerId = '010554709331800';
  static const String _channel = '2';
  static const String _reference2 = '024293333';
  static const String _terminalId = '0001';

  /// SHA-256 of the canonical `k=v&...` string, RSA-encrypted with the
  /// bank's public key.
  static String _sign(String canonical) {
    final digest = sha256.convert(utf8.encode(canonical));
    return RSAPublicKey.fromString(_pubKey).encrypt(digest.toString());
  }

  /// Creates a payment QR. On success stores `qrcodeContent` and `trxId`
  /// in SharedPreferences (read by SecondScreen) and returns true.
  /// Network errors propagate to the caller.
  static Future<bool> precreate({
    required String amount,
    required String reference1,
  }) async {
    final remark = DateFormat('yyyy-MM-dd|HH:mm:ss').format(DateTime.now());
    final sign = _sign(
        "amount=$amount&billerId=$_billerId&bizMchId=$bizMchId&channel=$_channel"
        "&reference1=$reference1&reference2=$_reference2&remark=$remark"
        "&terminalId=$_terminalId");

    final response = await Network().paymentTransfer('trans/precreate', {
      'bizMchId': bizMchId,
      'billerId': _billerId,
      'channel': _channel,
      'reference1': reference1,
      'reference2': _reference2,
      'terminalId': _terminalId,
      'amount': amount,
      'remark': remark,
      'sign': sign,
    });
    if (response.statusCode != 200) return false;

    final jsonResponse = json.decode(response.body);
    final qr = jsonResponse['qrcodeContent'];
    final trxId = jsonResponse['trxId'];
    if (qr == null || trxId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("qrcodeContent", qr.toString());
    await prefs.setString("trxId", trxId.toString());
    return true;
  }

  /// True when Krungsri reports the transaction as paid.
  /// Network errors propagate to the caller.
  static Future<bool> isPaid(String trxId) async {
    final response = await Network().paymentTransfer('trans/detail', {
      'bizMchId': bizMchId,
      'trxId': trxId,
      'sign': _sign("bizMchId=$bizMchId&trxId=$trxId"),
    });
    if (response.statusCode != 200) return false;
    final jsonResponse = json.decode(response.body);
    return jsonResponse['returnCode'] == "10000" &&
        jsonResponse['transaction']?['trxStatus'] == "1";
  }
}
