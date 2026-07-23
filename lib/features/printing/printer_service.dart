import 'dart:ui' as ui;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc;
import 'package:http/http.dart' as http;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../invoices/receipt_data.dart';
import '../invoices/receipt_formatter.dart';
import 'receipt_raster.dart';

class BtDevice {
  final String name;
  final String mac;
  const BtDevice(this.name, this.mac);
}

class PrintResult {
  final bool ok;
  final String? error;
  const PrintResult(this.ok, [this.error]);
}

/// Wraps the Bluetooth thermal printer. Discovery/connect/write are all
/// hardware operations and require a real paired printer to fully exercise;
/// the byte generation (raster) is deterministic and reused for a test print.
class PrinterService {
  Future<bool> get bluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled;

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<List<BtDevice>> pairedDevices() async {
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list
        .map((b) => BtDevice(b.name, b.macAdress))
        .toList(growable: false);
  }

  Future<bool> connect(String mac) {
    return PrintBluetoothThermal.connect(macPrinterAddress: mac);
  }

  Future<void> disconnect() => PrintBluetoothThermal.disconnect;

  /// Ensures a connection to [mac], connecting if needed.
  Future<bool> _ensureConnected(String mac) async {
    if (await isConnected) return true;
    return connect(mac);
  }

  /// Best-effort: downloads and decodes the shop's logo for the receipt
  /// header. Never throws — a network failure or bad image just means the
  /// receipt prints without a logo, not that printing fails.
  Future<ui.Image?> _fetchLogo(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 5),
          );
      if (res.statusCode != 200) return null;
      return decodeLogoImage(res.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  /// Builds the ESC/POS byte stream for a receipt (raster image + cut).
  Future<List<int>> buildBytes(
    ReceiptData data, {
    required PaperSize paper,
    required ReceiptLabels labels,
  }) async {
    final bodyLines = ReceiptFormatter(
      paper: paper,
      labels: labels,
      // Always the ASCII 'Ks' on receipts so money columns stay aligned even
      // when the UI language is Burmese.
      currencySymbol: 'Ks',
    ).format(data, includeHeader: false);

    final logo = await _fetchLogo(data.logoUrl);
    final image = await renderReceiptImage(data, bodyLines, paper, logo: logo);

    final profile = await esc.CapabilityProfile.load();
    final generator = esc.Generator(
      paper == PaperSize.mm80 ? esc.PaperSize.mm80 : esc.PaperSize.mm58,
      profile,
    );

    final bytes = <int>[];
    bytes.addAll(generator.imageRaster(image));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<PrintResult> printReceipt(
    ReceiptData data, {
    required PaperSize paper,
    required String mac,
    required ReceiptLabels labels,
  }) async {
    try {
      if (!await _ensureConnected(mac)) {
        return const PrintResult(false, 'connect_failed');
      }
      final bytes = await buildBytes(data, paper: paper, labels: labels);
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      return PrintResult(ok, ok ? null : 'write_failed');
    } catch (e) {
      return PrintResult(false, e.toString());
    }
  }
}
