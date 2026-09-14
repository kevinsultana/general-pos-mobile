import 'dart:convert';

enum PrinterConnectionType {
  bluetooth,
  usb,
  network;

  static PrinterConnectionType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'USB':
        return PrinterConnectionType.usb;
      case 'NETWORK':
        return PrinterConnectionType.network;
      case 'BLUETOOTH':
      default:
        return PrinterConnectionType.bluetooth;
    }
  }

  String toDbString() => name.toUpperCase();
}

enum PrinterRole {
  receipt,
  kitchen,
  both;

  static PrinterRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'KITCHEN':
        return PrinterRole.kitchen;
      case 'BOTH':
        return PrinterRole.both;
      case 'RECEIPT':
      default:
        return PrinterRole.receipt;
    }
  }

  String toDbString() => name.toUpperCase();

  String get displayName {
    switch (this) {
      case PrinterRole.receipt:
        return 'Struk Kasir';
      case PrinterRole.kitchen:
        return 'Pesanan Dapur';
      case PrinterRole.both:
        return 'Kasir & Dapur';
    }
  }
}

enum PrinterPaperSize {
  mm58(32),
  mm80(48);

  final int maxCharsPerLine;
  const PrinterPaperSize(this.maxCharsPerLine);

  static PrinterPaperSize fromString(String? value) {
    if (value == '80mm' || value == 'mm80') {
      return PrinterPaperSize.mm80;
    }
    return PrinterPaperSize.mm58;
  }

  String get displayName => this == mm58 ? '58mm (Standar)' : '80mm (Lebar)';
  String toConfigString() => this == mm58 ? '58mm' : '80mm';
}

enum PrinterState {
  disconnected,
  connecting,
  connected,
  error;

  String get displayName {
    switch (this) {
      case PrinterState.disconnected:
        return 'Terputus';
      case PrinterState.connecting:
        return 'Menghubungkan...';
      case PrinterState.connected:
        return 'Terhubung';
      case PrinterState.error:
        return 'Error Koneksi';
    }
  }
}

class PrinterDevice {
  final String id;
  final String storeId;
  final String name;
  final PrinterConnectionType connectionType;
  final String? addressReference; // MAC address (Bluetooth) or IP
  final PrinterRole role;
  final PrinterPaperSize paperSize;
  final int receiptCopies;
  final int kitchenCopies;
  final bool autoPrint;
  final bool active;
  final PrinterState state;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PrinterDevice({
    required this.id,
    required this.storeId,
    required this.name,
    this.connectionType = PrinterConnectionType.bluetooth,
    this.addressReference,
    this.role = PrinterRole.receipt,
    this.paperSize = PrinterPaperSize.mm58,
    this.receiptCopies = 1,
    this.kitchenCopies = 1,
    this.autoPrint = false,
    this.active = true,
    this.state = PrinterState.disconnected,
    required this.createdAt,
    required this.updatedAt,
  });

  PrinterDevice copyWith({
    String? id,
    String? storeId,
    String? name,
    PrinterConnectionType? connectionType,
    String? addressReference,
    PrinterRole? role,
    PrinterPaperSize? paperSize,
    int? receiptCopies,
    int? kitchenCopies,
    bool? autoPrint,
    bool? active,
    PrinterState? state,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrinterDevice(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      addressReference: addressReference ?? this.addressReference,
      role: role ?? this.role,
      paperSize: paperSize ?? this.paperSize,
      receiptCopies: receiptCopies ?? this.receiptCopies,
      kitchenCopies: kitchenCopies ?? this.kitchenCopies,
      autoPrint: autoPrint ?? this.autoPrint,
      active: active ?? this.active,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String encodeConfiguration() {
    return jsonEncode({
      'paperSize': paperSize.toConfigString(),
    });
  }

  static PrinterPaperSize decodePaperSize(String? configJson) {
    if (configJson == null || configJson.isEmpty) {
      return PrinterPaperSize.mm58;
    }
    try {
      final map = jsonDecode(configJson) as Map<String, dynamic>;
      return PrinterPaperSize.fromString(map['paperSize'] as String?);
    } catch (_) {
      return PrinterPaperSize.mm58;
    }
  }
}
