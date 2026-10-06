import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../core/models/tenant_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/currency_formatter.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._init();
  PrinterService._init();

  String? _connectedMac;
  String? _connectedDeviceName;

  bool get isConnectedLocal => _connectedMac != null;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get connectedMac => _connectedMac;

  /// Cache ESC/POS raster image bytes
  static final Map<String, List<int>> _rasterCache = {};

  /// Cek Izin Bluetooth
  Future<bool> checkPermission() async {
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah Bluetooth aktif
  Future<bool> isBluetoothEnabled() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Ambil daftar perangkat Bluetooth paired
  Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      debugPrint('Error getting paired bluetooth devices: $e');
      return [];
    }
  }

  /// Cek status koneksi printer saat ini
  Future<bool> isConnected() async {
    try {
      final status = await PrintBluetoothThermal.connectionStatus;
      if (!status) {
        _connectedMac = null;
        _connectedDeviceName = null;
      }
      return status;
    } catch (_) {
      return false;
    }
  }

  /// Hubungkan ke printer melalui MAC Address
  Future<bool> connect(String macAddress, {String? deviceName}) async {
    try {
      final success = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      if (success) {
        _connectedMac = macAddress;
        _connectedDeviceName = deviceName ?? macAddress;
      }
      return success;
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      return false;
    }
  }

  /// Putuskan koneksi printer
  Future<bool> disconnect() async {
    try {
      final success = await PrintBluetoothThermal.disconnect;
      _connectedMac = null;
      _connectedDeviceName = null;
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Mengonversi Logo Gambar (URL MinIO / File Lokal SQLite) menjadi perintah ESC/POS Raster Bit Image (GS v 0)
  static Future<List<int>?> rasterizeLogo(
    String pathOrUrl, {
    int maxDots = 256,
  }) async {
    try {
      final cacheKey = '$pathOrUrl@$maxDots';
      if (_rasterCache.containsKey(cacheKey)) {
        return _rasterCache[cacheKey];
      }

      Uint8List? imgBytes;

      if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        // Gambar dari server MinIO / Cloud
        final uri = Uri.tryParse(pathOrUrl);
        if (uri == null) return null;

        final httpClient = HttpClient();
        httpClient.connectionTimeout = const Duration(seconds: 5);
        final request = await httpClient.getUrl(uri);
        final response = await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) return null;
        imgBytes = await consolidateHttpClientResponseBytes(response);
      } else {
        // Gambar lokal dari penyimpanan perangkat (untuk FREE Plan)
        final file = File(pathOrUrl);
        if (await file.exists()) {
          imgBytes = await file.readAsBytes();
        }
      }

      if (imgBytes == null || imgBytes.isEmpty) return null;

      final codec = await ui.instantiateImageCodec(imgBytes);
      final frameInfo = await codec.getNextFrame();
      final img = frameInfo.image;

      final origW = img.width;
      final origH = img.height;
      if (origW <= 0 || origH <= 0) return null;

      // Batasi lebar maksimum dan pastikan kelipatan 8 dots
      int targetW = origW > maxDots ? maxDots : origW;
      targetW = (targetW ~/ 8) * 8;
      if (targetW < 8) targetW = 8;
      final targetH = ((origH * targetW) / origW).round();
      if (targetH <= 0) return null;

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      // Background putih solid
      canvas.drawRect(
        Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, origW.toDouble(), origH.toDouble()),
        Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );

      final picture = pictureRecorder.endRecording();
      final renderedImg = await picture.toImage(targetW, targetH);
      final byteData = await renderedImg.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final rawBytes = byteData.buffer.asUint8List();
      final bytesWidth = targetW ~/ 8;
      final xL = bytesWidth & 0xff;
      final xH = (bytesWidth >> 8) & 0xff;
      final yL = targetH & 0xff;
      final yH = (targetH >> 8) & 0xff;

      // Header ESC/POS Raster Bit Image: GS v 0 0 xL xH yL yH
      final rasterBytes = <int>[
        29, 118, 48, 0,
        xL, xH,
        yL, yH,
      ];

      for (int y = 0; y < targetH; y++) {
        for (int b = 0; b < bytesWidth; b++) {
          int byteVal = 0;
          for (int bit = 0; bit < 8; bit++) {
            final x = b * 8 + bit;
            final idx = (y * targetW + x) * 4;
            final r = rawBytes[idx];
            final g = rawBytes[idx + 1];
            final bl = rawBytes[idx + 2];
            final a = rawBytes[idx + 3];

            // Jika transparan -> putih
            final lum = a < 128 ? 255.0 : (0.299 * r + 0.587 * g + 0.114 * bl);
            if (lum < 165) {
              byteVal |= (0x80 >> bit);
            }
          }
          rasterBytes.add(byteVal);
        }
      }

      img.dispose();
      picture.dispose();
      renderedImg.dispose();

      _rasterCache[cacheKey] = rasterBytes;
      return rasterBytes;
    } catch (e) {
      debugPrint('[PrinterService] Gagal rasterize logo: $e');
      return null;
    }
  }

  static String _formatRow(String left, String right, {int width = 32}) {
    final availableSpace = width - left.length - right.length;
    if (availableSpace <= 0) {
      return '$left $right\n';
    }
    return '$left${' ' * availableSpace}$right\n';
  }

  /// Cetak Struk Uji Coba (Test Print)
  Future<bool> printTestReceipt({
    String storeName = 'OmniPOS Kasir Pintar',
    int printerWidth = 58,
    String receiptFontSize = 'NORMAL',
    String? logoUrl,
    bool showLogo = true,
  }) async {
    final connected = await isConnected();
    if (!connected) return false;

    final cols = printerWidth == 80 ? 48 : 32;
    final sep = '-' * cols;
    final doubleSep = '=' * cols;

    final bytes = <int>[];
    bytes.addAll([27, 64]); // Reset ESC/POS

    // Font Size
    if (receiptFontSize == 'SMALL') {
      bytes.addAll([27, 77, 1]); // Font B
    }

    // Logo Struk Uji Coba jika ada
    if (showLogo && logoUrl != null && logoUrl.trim().isNotEmpty) {
      try {
        final maxDots = printerWidth == 80 ? 384 : 256;
        final logoBytes = await rasterizeLogo(logoUrl.trim(), maxDots: maxDots);
        if (logoBytes != null && logoBytes.isNotEmpty) {
          bytes.addAll([27, 97, 1]); // Rata tengah
          bytes.addAll(logoBytes);
          bytes.addAll([10]); // Line feed
        }
      } catch (e) {
        debugPrint('Logo print error in test receipt: $e');
      }
    }

    // Header Nama Toko
    bytes.addAll([27, 97, 1]); // Center
    bytes.addAll([27, 69, 1]); // Bold On
    bytes.addAll([29, 33, 17]); // Double size
    bytes.addAll(utf8.encode('$storeName\n'));
    bytes.addAll([29, 33, 0]); // Normal size
    bytes.addAll([27, 69, 0]); // Bold Off
    bytes.addAll(utf8.encode('OmniPOS Thermal System\n'));
    bytes.addAll(utf8.encode('$doubleSep\n'));

    bytes.addAll([27, 69, 1]);
    bytes.addAll(utf8.encode('UJI COBA CETAK STRUK BERHASIL\n'));
    bytes.addAll([27, 69, 0]);
    bytes.addAll(utf8.encode('Koneksi Bluetooth Berjalan Lancar\n'));
    bytes.addAll(utf8.encode('Lebar Kertas: ${printerWidth}mm ($cols Kolom)\n'));
    bytes.addAll(utf8.encode('Ukuran Font: $receiptFontSize\n'));
    bytes.addAll(utf8.encode('$sep\n'));

    // Contoh Item
    bytes.addAll(utf8.encode(_formatRow('1x Kopi Susu Gula Aren', 'Rp 18.000', width: cols)));
    bytes.addAll(utf8.encode(_formatRow('1x Roti Bakar Cokelat', 'Rp 15.000', width: cols)));
    bytes.addAll(utf8.encode('$sep\n'));
    bytes.addAll([27, 69, 1]);
    bytes.addAll(utf8.encode(_formatRow('TOTAL', 'Rp 33.000', width: cols)));
    bytes.addAll([27, 69, 0]);
    bytes.addAll(utf8.encode('$doubleSep\n'));

    bytes.addAll([27, 97, 1]);
    bytes.addAll(utf8.encode('Terima Kasih Atas Kunjungan Anda!\n'));
    bytes.addAll(utf8.encode('Simpan struk sebagai bukti transaksi.\n'));
    bytes.addAll(utf8.encode('${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}\n'));

    if (receiptFontSize == 'SMALL') {
      bytes.addAll([27, 77, 0]); // Reset to Font A
    }

    bytes.addAll([10, 10, 10]); // Feed 3 lines

    try {
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint('Error writing test receipt bytes: $e');
      return false;
    }
  }

  /// Cetak Struk Transaksi Resmi POS
  Future<bool> printReceipt({
    required String storeName,
    required TransactionModel transaction,
    TenantModel? tenant,
    int? printerWidth,
    String? receiptFontSize,
    String? logoUrl,
    bool? showLogo,
  }) async {
    final connected = await isConnected();
    if (!connected) return false;

    final width = printerWidth ?? tenant?.printerWidth ?? 58;
    final fontSize = receiptFontSize ?? tenant?.receiptFontSize ?? 'NORMAL';
    final shouldShowLogo = showLogo ?? tenant?.receiptShowLogo ?? true;
    final finalLogo = logoUrl ?? tenant?.logoUrl;

    final cols = width == 80 ? 48 : 32;
    final sep = '-' * cols;
    final doubleSep = '=' * cols;

    final bytes = <int>[];
    bytes.addAll([27, 64]); // Inisialisasi printer

    // Ukuran Font
    if (fontSize == 'SMALL') {
      bytes.addAll([27, 77, 1]);
    }

    // 1. Logo Toko
    if (shouldShowLogo && finalLogo != null && finalLogo.trim().isNotEmpty) {
      try {
        final maxDots = width == 80 ? 384 : 256;
        final logoBytes = await rasterizeLogo(finalLogo.trim(), maxDots: maxDots);
        if (logoBytes != null && logoBytes.isNotEmpty) {
          bytes.addAll([27, 97, 1]); // Center
          bytes.addAll(logoBytes);
          bytes.addAll([10]);
        }
      } catch (e) {
        debugPrint('[PrinterService] Gagal cetak logo: $e');
      }
    }

    // 2. Header Toko
    bytes.addAll([27, 97, 1]); // Center
    bytes.addAll([27, 69, 1]); // Bold
    bytes.addAll([29, 33, 17]); // Double size
    bytes.addAll(utf8.encode('$storeName\n'));
    bytes.addAll([29, 33, 0]); // Normal size
    bytes.addAll([27, 69, 0]); // Bold off
    bytes.addAll(utf8.encode('OmniPOS Kasir Pintar\n'));
    bytes.addAll(utf8.encode('$doubleSep\n'));

    // 3. Info Transaksi
    bytes.addAll([27, 97, 0]); // Left
    final date = DateTime.tryParse(transaction.createdAt) ?? DateTime.now();
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(date);

    bytes.addAll(utf8.encode('No. Struk : ${transaction.receiptNumber}\n'));
    bytes.addAll(utf8.encode('Waktu     : $dateFormatted\n'));
    bytes.addAll(utf8.encode('Pelanggan : ${transaction.customerName ?? "Umum"}\n'));
    bytes.addAll(utf8.encode('Metode    : ${transaction.paymentMethod}\n'));
    bytes.addAll('$sep\n'.codeUnits);

    // 4. Daftar Item
    bytes.addAll([27, 69, 1]);
    bytes.addAll(utf8.encode(_formatRow('MENU', 'TOTAL', width: cols)));
    bytes.addAll([27, 69, 0]);
    bytes.addAll('$sep\n'.codeUnits);

    for (final item in transaction.items) {
      final name = item.productName;
      final line1 = '${item.quantity}x $name';
      final priceStr = CurrencyFormatter.format(item.subtotal);
      bytes.addAll(utf8.encode(_formatRow(line1, priceStr, width: cols)));

      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes.addAll(utf8.encode('  * ${item.notes}\n'));
      }
    }

    bytes.addAll('$sep\n'.codeUnits);

    // 5. Total Pembayaran
    if (transaction.discountAmount > 0) {
      final promoLabel = transaction.promoCode != null ? 'Diskon (${transaction.promoCode})' : 'Diskon';
      bytes.addAll(utf8.encode(_formatRow(promoLabel, '-${CurrencyFormatter.format(transaction.discountAmount)}', width: cols)));
    }

    bytes.addAll([27, 69, 1]);
    bytes.addAll(utf8.encode(_formatRow('TOTAL', CurrencyFormatter.format(transaction.totalAmount), width: cols)));
    bytes.addAll([27, 69, 0]);

    bytes.addAll(utf8.encode(_formatRow('TUNAI', CurrencyFormatter.format(transaction.cashPaid), width: cols)));
    bytes.addAll(utf8.encode(_formatRow('KEMBALI', CurrencyFormatter.format(transaction.changeAmount), width: cols)));
    bytes.addAll(utf8.encode('$doubleSep\n'));

    // 6. Footer
    bytes.addAll([27, 97, 1]); // Center
    bytes.addAll(utf8.encode('Terima Kasih Atas Kunjungan Anda\n'));
    bytes.addAll(utf8.encode('Powered by OmniPOS\n'));

    if (fontSize == 'SMALL') {
      bytes.addAll([27, 77, 0]);
    }

    bytes.addAll([10, 10, 10]); // Feed lines

    try {
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      return false;
    }
  }
}
