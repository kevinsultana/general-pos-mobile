import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/printer_device.dart';
import '../../domain/models/receipt_data.dart';
import '../../domain/repositories/i_printer_repository.dart';
import 'esc_pos_generator.dart';

/// Transport abstraction to allow real Bluetooth printing on devices
/// and mock transport in unit tests.
abstract class IPrinterTransport {
  Future<bool> isPermissionGranted();
  Future<bool> isBluetoothEnabled();
  Future<List<BluetoothInfo>> getPairedDevices();
  Future<bool> connect(String macAddress);
  Future<bool> disconnect();
  Future<bool> isConnected();
  Future<bool> writeBytes(List<int> bytes);
}

class BluetoothPrinterTransport implements IPrinterTransport {
  @override
  Future<bool> isPermissionGranted() =>
      PrintBluetoothThermal.isPermissionBluetoothGranted;

  @override
  Future<bool> isBluetoothEnabled() =>
      PrintBluetoothThermal.bluetoothEnabled;

  @override
  Future<List<BluetoothInfo>> getPairedDevices() =>
      PrintBluetoothThermal.pairedBluetooths;

  @override
  Future<bool> connect(String macAddress) =>
      PrintBluetoothThermal.connect(macPrinterAddress: macAddress);

  @override
  Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  @override
  Future<bool> isConnected() => PrintBluetoothThermal.connectionStatus;

  @override
  Future<bool> writeBytes(List<int> bytes) =>
      PrintBluetoothThermal.writeBytes(bytes);
}

class MockPrinterTransport implements IPrinterTransport {
  bool connected = false;
  final List<List<int>> printedByteHistory = [];

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> isBluetoothEnabled() async => true;

  @override
  Future<List<BluetoothInfo>> getPairedDevices() async {
    return [
      BluetoothInfo(name: 'Mock Thermal 58mm', macAdress: '00:11:22:33:44:55'),
      BluetoothInfo(name: 'Mock Kitchen 80mm', macAdress: '66:77:88:99:AA:BB'),
    ];
  }

  @override
  Future<bool> connect(String macAddress) async {
    connected = true;
    return true;
  }

  @override
  Future<bool> disconnect() async {
    connected = false;
    return true;
  }

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<bool> writeBytes(List<int> bytes) async {
    if (!connected) return false;
    printedByteHistory.add(List.from(bytes));
    return true;
  }
}

class PrinterService {
  final IPrinterRepository _printerRepository;
  final IPrinterTransport _transport;

  PrinterDevice? _connectedPrinter;
  PrinterDevice? get connectedPrinter => _connectedPrinter;

  PrinterService(
    this._printerRepository, {
    IPrinterTransport? transport,
  }) : _transport = transport ?? BluetoothPrinterTransport();

  /// Scans for paired Bluetooth thermal printers
  Future<List<BluetoothInfo>> getAvailableBluetoothDevices() async {
    try {
      final isEnabled = await _transport.isBluetoothEnabled();
      if (!isEnabled) return [];
      return await _transport.getPairedDevices();
    } catch (e) {
      debugPrint('Error getting bluetooth devices: $e');
      return [];
    }
  }

  /// Checks Bluetooth permission
  Future<bool> checkPermission() async {
    try {
      return await _transport.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  /// Connects to a specific printer
  Future<bool> connect(PrinterDevice printer) async {
    if (printer.addressReference == null || printer.addressReference!.isEmpty) {
      return false;
    }

    try {
      final success = await _transport.connect(printer.addressReference!);
      if (success) {
        _connectedPrinter = printer.copyWith(state: PrinterState.connected);
      } else {
        _connectedPrinter = null;
      }
      return success;
    } catch (e) {
      debugPrint('Printer connection error: $e');
      _connectedPrinter = null;
      return false;
    }
  }

  /// Disconnects from current printer
  Future<void> disconnect() async {
    try {
      await _transport.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting printer: $e');
    } finally {
      _connectedPrinter = null;
    }
  }

  /// Checks if currently connected
  Future<bool> isConnected() async {
    try {
      return await _transport.isConnected();
    } catch (_) {
      return false;
    }
  }

  /// Ensures connection to the given printer, attempting reconnect if needed
  Future<bool> _ensureConnected(PrinterDevice printer) async {
    final alreadyConnected = await isConnected();
    if (alreadyConnected &&
        _connectedPrinter != null &&
        _connectedPrinter!.addressReference == printer.addressReference) {
      return true;
    }
    return await connect(printer);
  }

  /// Prints a customer receipt (Kasir)
  ///
  /// CRITICAL BUSINESS RULE (PRD Bab 28 & Roadmap 10.6):
  /// Printing failure NEVER rolls back or corrupts transaction financial state.
  /// If printing fails, this returns `false` safely.
  Future<bool> printReceipt(
    ReceiptData receipt, {
    PrinterDevice? targetPrinter,
    String storeId = AppConstants.defaultStoreId,
  }) async {
    try {
      // 1. Resolve printer
      PrinterDevice? printer = targetPrinter;
      if (printer == null) {
        final receiptPrinters = await _printerRepository.getActivePrintersByRole(
          storeId,
          PrinterRole.receipt,
        );
        if (receiptPrinters.isEmpty) {
          debugPrint('No active receipt printer configured');
          return false;
        }
        printer = receiptPrinters.first;
      }

      // 2. Ensure connection
      final connected = await _ensureConnected(printer);
      if (!connected) {
        debugPrint('Failed to connect to receipt printer: ${printer.name}');
        return false;
      }

      // 3. Generate ESC/POS bytes
      final bytes = EscPosGenerator.generateReceipt(
        receipt,
        paperSize: printer.paperSize,
      );

      // 4. Print configured copies
      final copies = printer.receiptCopies.clamp(1, 5);
      bool allSuccess = true;
      for (int i = 0; i < copies; i++) {
        final success = await _transport.writeBytes(bytes);
        if (!success) allSuccess = false;
      }

      return allSuccess;
    } catch (e) {
      debugPrint('Print receipt exception: $e');
      return false;
    }
  }

  /// Prints a kitchen order ticket (Dapur)
  Future<bool> printKitchenTicket(
    KitchenTicketData ticket, {
    PrinterDevice? targetPrinter,
    String storeId = AppConstants.defaultStoreId,
  }) async {
    try {
      // 1. Resolve printer
      PrinterDevice? printer = targetPrinter;
      if (printer == null) {
        final kitchenPrinters = await _printerRepository.getActivePrintersByRole(
          storeId,
          PrinterRole.kitchen,
        );
        if (kitchenPrinters.isEmpty) {
          debugPrint('No active kitchen printer configured');
          return false;
        }
        printer = kitchenPrinters.first;
      }

      // 2. Ensure connection
      final connected = await _ensureConnected(printer);
      if (!connected) {
        debugPrint('Failed to connect to kitchen printer: ${printer.name}');
        return false;
      }

      // 3. Generate ESC/POS bytes
      final bytes = EscPosGenerator.generateKitchenTicket(
        ticket,
        paperSize: printer.paperSize,
      );

      // 4. Print configured copies
      final copies = printer.kitchenCopies.clamp(1, 5);
      bool allSuccess = true;
      for (int i = 0; i < copies; i++) {
        final success = await _transport.writeBytes(bytes);
        if (!success) allSuccess = false;
      }

      return allSuccess;
    } catch (e) {
      debugPrint('Print kitchen ticket exception: $e');
      return false;
    }
  }

  /// Prints a test slip
  Future<bool> printTest(PrinterDevice printer) async {
    try {
      final connected = await _ensureConnected(printer);
      if (!connected) return false;

      final bytes = EscPosGenerator.generateTestPrint(
        paperSize: printer.paperSize,
      );

      return await _transport.writeBytes(bytes);
    } catch (e) {
      debugPrint('Print test exception: $e');
      return false;
    }
  }

  /// Handles auto-print trigger when a transaction is completed
  Future<void> handleAutoPrintOnTransactionCompleted(
    ReceiptData receipt, {
    KitchenTicketData? kitchenTicket,
    String storeId = AppConstants.defaultStoreId,
  }) async {
    try {
      final printers = await _printerRepository.getAllPrinters(storeId);

      // 1. Check receipt auto-print
      for (final p in printers.where((p) => p.active && p.autoPrint)) {
        if (p.role == PrinterRole.receipt || p.role == PrinterRole.both) {
          await printReceipt(receipt, targetPrinter: p, storeId: storeId);
        }
        if (kitchenTicket != null &&
            (p.role == PrinterRole.kitchen || p.role == PrinterRole.both)) {
          await printKitchenTicket(kitchenTicket, targetPrinter: p, storeId: storeId);
        }
      }
    } catch (e) {
      debugPrint('Auto print exception: $e');
      // Never rethrow: transaction integrity is already finalized!
    }
  }
}
