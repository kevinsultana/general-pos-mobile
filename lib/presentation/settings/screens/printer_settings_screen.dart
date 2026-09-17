import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/printer_device.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingPrinterId;

  Future<void> _scanAndAddPrinter() async {
    setState(() => _isScanning = true);
    final printerService = ref.read(printerServiceProvider);

    try {
      final devices = await printerService.getAvailableBluetoothDevices();
      if (!mounted) return;

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada printer Bluetooth yang ditemukan. Pastikan Bluetooth aktif dan printer sudah di-pairing di Pengaturan Bluetooth HP.',
            ),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      await _showDeviceSelectionDialog(devices);
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _showDeviceSelectionDialog(List<BluetoothInfo> devices) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bluetooth_searching_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Pilih Printer Bluetooth'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: devices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final d = devices[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  d.name.isNotEmpty ? d.name : 'Unknown Device',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  d.macAdress,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showConfigurePrinterDialog(
                    initialName: d.name.isNotEmpty ? d.name : 'Thermal Printer',
                    initialMac: d.macAdress,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfigurePrinterDialog({
    PrinterDevice? existingPrinter,
    String? initialName,
    String? initialMac,
  }) async {
    final nameController = TextEditingController(
      text: existingPrinter?.name ?? initialName ?? 'Printer Thermal 58mm',
    );
    final macController = TextEditingController(
      text: existingPrinter?.addressReference ?? initialMac ?? '',
    );

    PrinterRole selectedRole = existingPrinter?.role ?? PrinterRole.receipt;
    PrinterPaperSize selectedPaper =
        existingPrinter?.paperSize ?? PrinterPaperSize.mm58;
    int receiptCopies = existingPrinter?.receiptCopies ?? 1;
    int kitchenCopies = existingPrinter?.kitchenCopies ?? 1;
    bool autoPrint = existingPrinter?.autoPrint ?? false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(existingPrinter == null ? 'Tambah Printer' : 'Ubah Printer'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Printer',
                    hintText: 'Contoh: Kasir Depan, Dapur Bar',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: macController,
                  decoration: InputDecoration(
                    labelText: 'Alamat MAC Bluetooth',
                    hintText: '00:11:22:33:44:55',
                    prefixIcon: const Icon(Icons.bluetooth_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Role Dropdown
                const Text(
                  'Peran Printer:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<PrinterRole>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.work_outline_rounded,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: PrinterRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.displayName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Paper Size
                const Text(
                  'Ukuran Kertas Thermal:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('58mm (32 Karakter)'),
                        selected: selectedPaper == PrinterPaperSize.mm58,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(
                              () => selectedPaper = PrinterPaperSize.mm58,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('80mm (48 Karakter)'),
                        selected: selectedPaper == PrinterPaperSize.mm80,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(
                              () => selectedPaper = PrinterPaperSize.mm80,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Copies
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Salinan Struk',
                            style: TextStyle(fontSize: 12),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: receiptCopies > 1
                                    ? () =>
                                          setDialogState(() => receiptCopies--)
                                    : null,
                              ),
                              Text(
                                '$receiptCopies',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: receiptCopies < 5
                                    ? () =>
                                          setDialogState(() => receiptCopies++)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Salinan Dapur',
                            style: TextStyle(fontSize: 12),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: kitchenCopies > 1
                                    ? () =>
                                          setDialogState(() => kitchenCopies--)
                                    : null,
                              ),
                              Text(
                                '$kitchenCopies',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: kitchenCopies < 5
                                    ? () =>
                                          setDialogState(() => kitchenCopies++)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Auto Print Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cetak Otomatis (Auto Print)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Otomatis mencetak struk saat kasir menyelesaikan pembayaran',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  value: autoPrint,
                  onChanged: (val) {
                    setDialogState(() => autoPrint = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(printerRepositoryProvider);
      final now = DateTime.now();

      final activeStoreId = ref.read(activeStoreIdProvider);
      final newPrinter = PrinterDevice(
        id: existingPrinter?.id ?? const Uuid().v4(),
        storeId: activeStoreId,
        name: nameController.text.trim().isEmpty
            ? 'Thermal Printer'
            : nameController.text.trim(),
        connectionType: PrinterConnectionType.bluetooth,
        addressReference: macController.text.trim().isEmpty
            ? null
            : macController.text.trim(),
        role: selectedRole,
        paperSize: selectedPaper,
        receiptCopies: receiptCopies,
        kitchenCopies: kitchenCopies,
        autoPrint: autoPrint,
        active: true,
        customConfiguration: existingPrinter?.customConfiguration ?? const {},
        createdAt: existingPrinter?.createdAt ?? now,
        updatedAt: now,
      );

      await repo.savePrinter(newPrinter);
      ref.invalidate(printerListStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existingPrinter == null
                  ? 'Printer berhasil ditambahkan'
                  : 'Pengaturan printer diperbarui',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _handleConnect(PrinterDevice printer) async {
    setState(() {
      _isConnecting = true;
      _connectingPrinterId = printer.id;
    });

    final printerService = ref.read(printerServiceProvider);
    try {
      final success = await printerService.connect(printer);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil terhubung ke ${printer.name}'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal terhubung ke ${printer.name}. Pastikan printer menyala dan Bluetooth aktif.',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingPrinterId = null;
        });
      }
    }
  }

  Future<void> _handleTestPrint(PrinterDevice printer) async {
    final printerService = ref.read(printerServiceProvider);
    final success = await printerService.printTest(printer);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uji coba cetak berhasil dikirim ke printer'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal mencetak slip uji coba. Pastikan printer terhubung dan kertas terpasang.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(PrinterDevice printer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Printer'),
        content: Text('Hapus printer "${printer.name}" dari daftar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(printerRepositoryProvider);
      await repo.deletePrinter(printer.id);
      ref.invalidate(printerListStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer dihapus'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final printersAsync = ref.watch(printerListStreamProvider);
    final printerService = ref.watch(printerServiceProvider);
    final connected = printerService.connectedPrinter;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan Printer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.print_rounded, size: 32, color: AppColors.primary),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Hubungkan printer thermal Bluetooth (58mm / 80mm ESC/POS) untuk mencetak struk belanja kasir dan tiket pesanan dapur.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimaryLight,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scan Button Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tambah Printer Baru',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pindai printer Bluetooth yang sudah dipasangkan (paired) pada HP Anda.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isScanning ? null : _scanAndAddPrinter,
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.bluetooth_searching_rounded),
                          label: Text(
                            _isScanning
                                ? 'Memindai...'
                                : 'Cari Printer Bluetooth',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showConfigurePrinterDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Manual'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section Title
          const Text(
            'Daftar Printer Tersimpan:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),

          // Printer List
          printersAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) =>
                Center(child: Text('Error memuat printer: $err')),
            data: (printers) {
              if (printers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.print_disabled_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum Ada Printer Dikonfigurasi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tekan tombol "Cari Printer Bluetooth" di atas untuk menambahkan printer thermal Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: printers.map((p) {
                  final isCurrentlyConnected = connected?.id == p.id;
                  final isConnectingThis =
                      _isConnecting && _connectingPrinterId == p.id;

                  return Card(
                    elevation: 0.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isCurrentlyConnected
                            ? AppColors.primary
                            : Colors.grey.shade200,
                        width: isCurrentlyConnected ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isCurrentlyConnected
                                      ? Colors.green.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.print_rounded,
                                  color: isCurrentlyConnected
                                      ? Colors.green.shade700
                                      : AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.addressReference ?? 'Bluetooth',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrentlyConnected
                                      ? Colors.green.shade100
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isCurrentlyConnected
                                      ? 'TERHUBUNG'
                                      : 'TERPUTUS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentlyConnected
                                        ? Colors.green.shade800
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Badges: Role, Paper size, Copies, Auto Print
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _chip(Icons.work_outline, p.role.displayName),
                              _chip(
                                Icons.aspect_ratio,
                                p.paperSize.displayName,
                              ),
                              if (p.autoPrint)
                                _chip(
                                  Icons.flash_on_rounded,
                                  'Auto Print ON',
                                  color: Colors.amber.shade100,
                                  textColor: Colors.amber.shade900,
                                ),
                              if (p.receiptCopies > 1)
                                _chip(
                                  Icons.copy_rounded,
                                  '${p.receiptCopies}x Struk',
                                ),
                            ],
                          ),
                          const Divider(height: 20),

                          // Action Buttons
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                ),
                                onPressed: () => _handleDelete(p),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                ),
                                label: const Text('Hapus'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showConfigurePrinterDialog(
                                  existingPrinter: p,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Ubah'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _handleTestPrint(p),
                                icon: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 16,
                                ),
                                label: const Text('Uji Cetak'),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isCurrentlyConnected
                                      ? Colors.grey.shade200
                                      : AppColors.primary,
                                  foregroundColor: isCurrentlyConnected
                                      ? Colors.black87
                                      : Colors.white,
                                ),
                                onPressed: isConnectingThis
                                    ? null
                                    : () {
                                        if (isCurrentlyConnected) {
                                          printerService.disconnect();
                                          setState(() {});
                                        } else {
                                          _handleConnect(p);
                                        }
                                      },
                                icon: isConnectingThis
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        isCurrentlyConnected
                                            ? Icons.bluetooth_disabled_rounded
                                            : Icons.bluetooth_connected_rounded,
                                        size: 16,
                                      ),
                                label: Text(
                                  isCurrentlyConnected
                                      ? 'Putus'
                                      : (isConnectingThis
                                            ? 'Menghubungkan...'
                                            : 'Sambungkan'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, {Color? color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor ?? Colors.blue.shade800),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor ?? Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
