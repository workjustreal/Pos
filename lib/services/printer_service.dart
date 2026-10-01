// ignore_for_file: avoid_print, library_prefixes
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'package:image/image.dart' as nImage;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kacee_pos/network_utils/api.dart';

class PrintArgs {
  final Uint8List imageData;
  final PaperSize paper;
  final CapabilityProfile profile;
  PrintArgs(this.imageData, this.paper, this.profile);
}

List<int> _generateReceiptBytes(PrintArgs args) {
  final image = nImage.decodeImage(args.imageData);
  if (image == null) return const [];

  // Original resize behaviour — known to work on this customer's printer.
  // (Tried PosImageFn.graphics + aspect-ratio resize for speed, but the
  // printer doesn't support the GS ( L graphics command and printed blank,
  // so reverted to the proven bitImageRaster path.)
  final resized =
      nImage.copyResize(image, width: 380, height: image.height + 50);

  final ticket = Generator(args.paper, args.profile);
  final bytes = <int>[];
  bytes.addAll(ticket.reset());
  bytes.addAll(ticket.setGlobalCodeTable('CP1250'));
  bytes.addAll(ticket.imageRaster(resized, align: PosAlign.center));
  bytes.addAll(ticket.feed(1));
  bytes.addAll(ticket.cut());
  return bytes;
}

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  Future<CapabilityProfile>? _profileFuture;
  bool _printing = false;

  // Cache of fully-rendered ESC/POS byte streams keyed by receipt path.
  // Populated by [prefetchReceipt] while the customer is still paying, then
  // consumed by [printReceipt] on payment success — turning the print path
  // into a single Bluetooth write.
  final Map<String, List<int>> _bytesCache = {};
  // Pending prefetch futures so [printReceipt] can await an in-flight
  // prefetch instead of racing it with a duplicate fetch.
  final Map<String, Future<void>> _prefetchInflight = {};

  Future<CapabilityProfile> _getProfile() {
    return _profileFuture ??= CapabilityProfile.load();
  }

  /// Last failure reason from [ensureConnected] — surfaced to the UI so the
  /// customer/cashier can act on it instead of just seeing "ไม่พร้อม".
  String? lastConnectError;

  Future<bool> ensureConnected() async {
    lastConnectError = null;
    try {
      // 1. Read configured MAC. If empty, nothing we can do.
      final prefs = await SharedPreferences.getInstance();
      final mac = prefs.getString("mac_printer") ?? "";
      print('PrinterService: mac_printer="$mac"');
      if (mac.isEmpty) {
        lastConnectError = 'ยังไม่ได้ตั้งค่า MAC เครื่องพิมพ์ (login อีกครั้ง)';
        return false;
      }

      // 2. Check current status with a timeout — connectionStatus can hang
      //    indefinitely if the BT stack is in a wedged state.
      bool isConnected = false;
      try {
        isConnected = await PrintBluetoothThermal.connectionStatus.timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        );
      } catch (e) {
        print('PrinterService: connectionStatus check failed: $e');
        isConnected = false;
      }
      if (isConnected) {
        print('PrinterService: already connected');
        return true;
      }

      // 3. Force a disconnect first to clear any stale handle. Some Android
      //    BT stacks (notably the older one on Sunmi T2 / Android 7.1) hold
      //    onto a dead socket and refuse new connects until you reset it.
      try {
        await PrintBluetoothThermal.disconnect.timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
      } catch (_) {
        // ignored — disconnect failing is fine, we just wanted to try
      }

      // 4. Connect with a timeout so a missing/off printer can't freeze
      //    the whole print flow.
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac)
          .timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      print('PrinterService: connect("$mac") → $ok');
      if (!ok) {
        lastConnectError =
            'ไม่สามารถเชื่อมต่อเครื่องพิมพ์ ($mac) — ตรวจไฟ/ระยะ BT';
      }
      return ok;
    } catch (e) {
      print('PrinterService.ensureConnected error: $e');
      lastConnectError = 'ผิดพลาด: $e';
      return false;
    }
  }

  /// Pre-render the receipt for [receiptPath] while the customer is still on
  /// the payment screen. Fire-and-forget — silently fails if the backend
  /// can't generate the receipt yet (e.g. order not paid), in which case
  /// [printReceipt] will fall back to the normal fetch path. Saves ~1.5-2s
  /// off the perceived print latency when it succeeds.
  Future<void> prefetchReceipt(String receiptPath) {
    if (_bytesCache.containsKey(receiptPath)) {
      return Future.value();
    }
    final inflight = _prefetchInflight[receiptPath];
    if (inflight != null) return inflight;

    final future = _doPrefetch(receiptPath);
    _prefetchInflight[receiptPath] = future;
    return future.whenComplete(() {
      _prefetchInflight.remove(receiptPath);
    });
  }

  Future<void> _doPrefetch(String receiptPath) async {
    try {
      final response = await Network().getSearchProduct(receiptPath);
      if (response.statusCode != 200) return;
      final jsonResponse = json.decode(response.body);
      final data = jsonResponse['data'];
      if (data == null) return;

      final Uint8List imageData = base64Decode(data);
      final profile = await _getProfile();
      final bytes = await compute(
        _generateReceiptBytes,
        PrintArgs(imageData, PaperSize.mm58, profile),
      );
      if (bytes.isNotEmpty) {
        _bytesCache[receiptPath] = bytes;
      }
    } catch (e) {
      print('PrinterService.prefetchReceipt error: $e');
    }
  }

  Future<bool> printReceipt(String receiptPath) async {
    if (_printing) return false;
    _printing = true;
    try {
      final connected = await ensureConnected();
      if (!connected) return false;

      // If a prefetch is still in flight, give it a chance to finish so we
      // hit the fast path (waiting ~200ms beats spawning a duplicate fetch).
      final inflight = _prefetchInflight[receiptPath];
      if (inflight != null) {
        await inflight;
      }

      // Fast path: bytes were pre-rendered — skip HTTP, decode, isolate.
      final cached = _bytesCache.remove(receiptPath);
      if (cached != null && cached.isNotEmpty) {
        return await PrintBluetoothThermal.writeBytes(cached);
      }

      // Slow path: prefetch didn't run or failed — original flow.
      final response = await Network().getSearchProduct(receiptPath);
      if (response.statusCode != 200) return false;

      final jsonResponse = json.decode(response.body);
      final data = jsonResponse['data'];
      if (data == null) return false;

      final Uint8List imageData = base64Decode(data);
      final profile = await _getProfile();

      final bytes = await compute(
        _generateReceiptBytes,
        PrintArgs(imageData, PaperSize.mm58, profile),
      );

      if (bytes.isEmpty) return false;
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      print('PrinterService.printReceipt error: $e');
      return false;
    } finally {
      _printing = false;
    }
  }

  /// Clear the cache. Safe to call e.g. when the customer cancels — the
  /// stale bytes are tiny (~30KB) but tidying up is cleaner.
  void clearCache() {
    _bytesCache.clear();
  }
}
