import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../sync/controllers/sync_controller.dart';
import '../services/printer_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _storeNameCtrl = TextEditingController();

  // Printer State
  bool _isScanningPrinters = false;
  List<BluetoothInfo> _pairedDevices = [];
  bool _isConnectingPrinter = false;
  bool _isTestPrinting = false;

  // Rounding Simulation State
  double _simulationAmount = 14250;

  // Media (MinIO) State
  bool _isMediaLoading = false;
  List<dynamic> _mediaItems = [];
  Map<String, dynamic> _mediaSummary = {
    'totalFiles': 0,
    'totalUsed': 0,
    'totalUnused': 0,
    'totalBytes': 0,
  };
  String _mediaFilter = 'ALL'; // ALL | USED | UNUSED
  String _mediaSearch = '';
  String? _deletingMediaKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authCtrl = context.read<AuthController>();
      final tenant = authCtrl.currentTenant;
      if (tenant != null) {
        _storeNameCtrl.text = tenant.name;
      }
      _checkPrinterStatus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _storeNameCtrl.dispose();
    super.dispose();
  }

  // ─── Format Bytes Helper ───────────────────────────────────────────────────
  String _formatBytes(num? bytes) {
    if (bytes == null || bytes == 0) return '0 KB';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes > 0) ? (bytes.toString().length > 0 ? (bytes / 1024 > 1024 ? 2 : 1) : 0) : 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ─── PRINTER METHODS ────────────────────────────────────────────────────────
  Future<void> _checkPrinterStatus() async {
    await PrinterService.instance.isConnected();
    if (mounted) setState(() {});
  }

  Future<void> _scanPrinters() async {
    setState(() => _isScanningPrinters = true);

    final hasPerm = await PrinterService.instance.checkPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin Bluetooth belum diberikan di perangkat ini.')),
        );
        setState(() => _isScanningPrinters = false);
      }
      return;
    }

    final isBtOn = await PrinterService.instance.isBluetoothEnabled();
    if (!isBtOn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth ponsel sedang mati. Harap aktifkan Bluetooth.')),
        );
        setState(() => _isScanningPrinters = false);
      }
      return;
    }

    final devices = await PrinterService.instance.getPairedDevices();
    if (mounted) {
      setState(() {
        _pairedDevices = devices;
        _isScanningPrinters = false;
      });
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada printer Bluetooth yang terpasang (paired). Pasangkan di pengaturan HP terlebih dahulu.')),
        );
      }
    }
  }

  Future<void> _connectToPrinter(BluetoothInfo device) async {
    setState(() => _isConnectingPrinter = true);
    final ok = await PrinterService.instance.connect(device.macAdress, deviceName: device.name);
    if (mounted) {
      setState(() => _isConnectingPrinter = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil terhubung ke ${device.name}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghubungkan ke ${device.name}. Pastikan printer menyala.')),
        );
      }
    }
  }

  Future<void> _disconnectPrinter() async {
    await PrinterService.instance.disconnect();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer terputus.')),
      );
    }
  }

  Future<void> _handleTestPrint() async {
    final authCtrl = context.read<AuthController>();
    final tenant = authCtrl.currentTenant;

    final connected = await PrinterService.instance.isConnected();
    if (!connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer belum terhubung. Hubungkan printer Bluetooth terlebih dahulu.')),
        );
      }
      return;
    }

    setState(() => _isTestPrinting = true);
    final ok = await PrinterService.instance.printTestReceipt(
      storeName: tenant?.name ?? 'OmniPOS Toko',
      printerWidth: tenant?.printerWidth ?? 58,
      receiptFontSize: tenant?.receiptFontSize ?? 'NORMAL',
      logoUrl: tenant?.logoUrl,
      showLogo: tenant?.receiptShowLogo ?? true,
    );
    if (mounted) {
      setState(() => _isTestPrinting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Struk uji coba berhasil dicetak!' : 'Gagal mengirim data ke printer.'),
        ),
      );
    }
  }

  // ─── LOGO METHODS ───────────────────────────────────────────────────────────
  Future<void> _pickAndUploadLogo() async {
    final authCtrl = context.read<AuthController>();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null || pickedFile.path.isEmpty) return;
    final path = pickedFile.path;

    final ok = await authCtrl.updateLogo(path);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authCtrl.isProOrPlus
                  ? 'Logo toko berhasil diunggah ke server cloud MinIO!'
                  : 'Logo toko berhasil disimpan di database SQLite lokal (Free Plan).',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan logo toko.')),
        );
      }
    }
  }

  Future<void> _handleDeleteLogo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Logo Toko?'),
        content: const Text('Logo toko akan dihapus dari aplikasi dan struk kasir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final authCtrl = context.read<AuthController>();
    final ok = await authCtrl.deleteLogo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Logo toko berhasil dihapus.' : 'Gagal menghapus logo.')),
      );
    }
  }

  // ─── MEDIA MINIO METHODS ────────────────────────────────────────────────────
  Future<void> _fetchMedia() async {
    final authCtrl = context.read<AuthController>();
    if (!authCtrl.isProOrPlus) return;

    setState(() => _isMediaLoading = true);
    try {
      final res = await ApiClient.instance.dio.get('/media');
      if (res.data?['success'] == true && res.data?['data'] != null) {
        final data = res.data['data'];
        setState(() {
          _mediaItems = data['items'] ?? [];
          if (data['summary'] != null) {
            _mediaSummary = Map<String, dynamic>.from(data['summary']);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching media: $e');
    } finally {
      if (mounted) setState(() => _isMediaLoading = false);
    }
  }

  Future<void> _deleteMedia(String key, String filename) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Media MinIO?'),
        content: Text('File "$filename" akan dihapus secara permanen dari object storage MinIO.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingMediaKey = key);
    try {
      final res = await ApiClient.instance.dio.delete('/media', queryParameters: {'key': key});
      if (res.data?['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File media berhasil dihapus dari MinIO!')),
          );
        }
        await _fetchMedia();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus media: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingMediaKey = null);
    }
  }

  // ─── BUILD SCREEN ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authCtrl = context.watch<AuthController>();
    final syncCtrl = context.watch<SyncController>();
    final tenant = authCtrl.currentTenant;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text(
          'Pengaturan Sistem',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.slate900),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.slate500,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'Toko'),
                Tab(icon: Icon(Icons.print_rounded, size: 18), text: 'Printer'),
                Tab(icon: Icon(Icons.calculate_rounded, size: 18), text: 'Pembulatan'),
                Tab(icon: Icon(Icons.perm_media_rounded, size: 18), text: 'Media'),
              ],
              onTap: (idx) {
                if (idx == 3) _fetchMedia();
              },
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoreTab(authCtrl, syncCtrl),
          _buildPrinterTab(authCtrl),
          _buildRoundingTab(authCtrl),
          _buildMediaTab(authCtrl),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: PENGATURAN TOKO & IDENTITAS
  // ===========================================================================
  Widget _buildStoreTab(AuthController authCtrl, SyncController syncCtrl) {
    final tenant = authCtrl.currentTenant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // Identitas Toko
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          backgroundColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Identitas Toko',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Nama Toko', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _storeNameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Masukkan nama toko...',
                        filled: true,
                        fillColor: AppColors.slate50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: () async {
                      final ok = await authCtrl.updateStoreName(_storeNameCtrl.text);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Nama toko berhasil disimpan!' : 'Gagal menyimpan nama toko.')),
                        );
                      }
                    },
                    child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Logo Toko
              const Text('Logo Toko', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: tenant?.logoUrl != null && tenant!.logoUrl!.isNotEmpty
                          ? (tenant.logoUrl!.startsWith('http')
                              ? Image.network(
                                  tenant.logoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: AppColors.slate400),
                                )
                              : Image.file(
                                  File(tenant.logoUrl!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: AppColors.slate400),
                                ))
                          : const Icon(Icons.image_outlined, size: 32, color: AppColors.slate400),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: authCtrl.isProOrPlus ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            authCtrl.isProOrPlus ? 'Cloud Storage MinIO (Pro/Plus)' : 'Local SQLite DB (Free Offline)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: authCtrl.isProOrPlus ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: const Text('Pilih Logo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: _pickAndUploadLogo,
                            ),
                            if (tenant?.logoUrl != null)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: Color(0xFFFECDD3)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                label: const Text('Hapus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _handleDeleteLogo,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Switch Cetak Logo di Struk
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cetak Logo di Header Struk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Tampilkan logo grafis di bagian atas kertas struk thermal', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                value: tenant?.receiptShowLogo ?? true,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  authCtrl.updateReceiptShowLogo(val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Info Lisensi & Akun Toko
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          backgroundColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Paket Langganan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tenant?.isProOrPlus == true ? AppColors.primary50 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tenant?.isProOrPlus == true ? AppColors.primary : AppColors.slate300),
                    ),
                    child: Text(
                      'PLAN: ${tenant?.plan ?? "FREE"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: tenant?.isProOrPlus == true ? AppColors.primaryDark : AppColors.slate700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Slug Web Order', '/order/${tenant?.slug ?? ""}', isCopyable: true),
              const SizedBox(height: 8),
              _buildInfoRow('Cabang Aktif', tenant?.branchName ?? 'Cabang Utama'),
              const SizedBox(height: 8),
              _buildInfoRow('Pemilik', tenant?.ownerName ?? '-'),
              const SizedBox(height: 8),
              _buildInfoRow('Backend Server', ApiConstants.baseUrl),
              const Divider(height: 24),

              // Cek Upgrade Server Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.slate900,
                    side: const BorderSide(color: AppColors.slate300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Cek Upgrade Server & Sinkronisasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: syncCtrl.isSyncing
                      ? null
                      : () async {
                          await authCtrl.refreshTenantPlan();
                          if (context.mounted && tenant != null) {
                            await syncCtrl.syncIfUpgraded(context, tenant);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Logout Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFF1F2),
              foregroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFECDD3)),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text(
              'Keluar dari Akun Kasir',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _confirmLogout(context, authCtrl),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: BLUETOOTH THERMAL PRINTER
  // ===========================================================================
  Widget _buildPrinterTab(AuthController authCtrl) {
    final tenant = authCtrl.currentTenant;
    final isConnected = PrinterService.instance.isConnectedLocal;
    final connectedName = PrinterService.instance.connectedDeviceName ?? 'Printer';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // Status Printer Card
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          backgroundColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bluetooth_connected_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Koneksi Printer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isConnected ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3)),
                    ),
                    child: Text(
                      isConnected ? 'TERHUBUNG' : 'TERPUTUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isConnected ? const Color(0xFF047857) : const Color(0xFFBE123C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isConnected
                    ? 'Perangkat aktif: $connectedName (${PrinterService.instance.connectedMac ?? "-"})'
                    : 'Belum ada printer Bluetooth yang terhubung. Pindai perangkat yang sudah di-pair pada ponsel.',
                style: const TextStyle(fontSize: 12, color: AppColors.slate600),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (isConnected)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.bluetooth_disabled_rounded, size: 16),
                        label: const Text('Putuskan Koneksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: _disconnectPrinter,
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _isScanningPrinters
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.bluetooth_searching_rounded, size: 16),
                        label: Text(_isScanningPrinters ? 'Memindai...' : 'Pindai Printer Bluetooth', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: _isScanningPrinters ? null : _scanPrinters,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Daftar Perangkat Paired (Jika ada)
        if (_pairedDevices.isNotEmpty) ...[
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(18),
            backgroundColor: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Perangkat Bluetooth Paired', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                const SizedBox(height: 8),
                ...List.generate(_pairedDevices.length, (idx) {
                  final dev = _pairedDevices[idx];
                  final isThisConnected = PrinterService.instance.connectedMac == dev.macAdress;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isThisConnected ? const Color(0xFFF0FDF4) : AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isThisConnected ? const Color(0xFF86EFAC) : AppColors.slate200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(dev.macAdress, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isThisConnected ? AppColors.slate200 : AppColors.primary,
                            foregroundColor: isThisConnected ? AppColors.slate700 : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isThisConnected
                              ? null
                              : (_isConnectingPrinter ? null : () => _connectToPrinter(dev)),
                          child: Text(isThisConnected ? 'Tersambung' : 'Hubungkan', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Konfigurasi Kertas & Format Struk
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          backgroundColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppColors.slate700, size: 18),
                  SizedBox(width: 8),
                  Text('Format Kertas & Font', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                ],
              ),
              const SizedBox(height: 14),

              // Lebar Kertas
              const Text('Lebar Kertas Thermal:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildFormatOptionCard(
                      title: '58 mm (32 Kolom)',
                      subtitle: 'Standar Mobile Kasir',
                      isSelected: (tenant?.printerWidth ?? 58) == 58,
                      onTap: () => authCtrl.updatePrinterSettings(width: 58),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFormatOptionCard(
                      title: '80 mm (48 Kolom)',
                      subtitle: 'Standar Kasir Besar',
                      isSelected: (tenant?.printerWidth ?? 58) == 80,
                      onTap: () => authCtrl.updatePrinterSettings(width: 80),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ukuran Font
              const Text('Ukuran Font Struk:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildFormatOptionCard(
                      title: 'NORMAL',
                      subtitle: 'Font A Standar',
                      isSelected: (tenant?.receiptFontSize ?? 'NORMAL') == 'NORMAL',
                      onTap: () => authCtrl.updatePrinterSettings(fontSize: 'NORMAL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFormatOptionCard(
                      title: 'SMALL',
                      subtitle: 'Font B Lebih Rapat',
                      isSelected: (tenant?.receiptFontSize ?? 'NORMAL') == 'SMALL',
                      onTap: () => authCtrl.updatePrinterSettings(fontSize: 'SMALL'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Tombol Uji Coba Cetak Struk
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.slate900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isTestPrinting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print_rounded, size: 18),
                  label: Text(_isTestPrinting ? 'Mencetak Struk...' : 'Uji Coba Cetak Struk Thermal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _isTestPrinting ? null : _handleTestPrint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: PEMBULATAN TRANSAKSI
  // ===========================================================================
  Widget _buildRoundingTab(AuthController authCtrl) {
    final tenant = authCtrl.currentTenant;
    final currentMode = tenant?.roundingMode ?? 0;

    final simulatedRaw = _simulationAmount;
    final simulatedRounded = currentMode > 0 ? ((simulatedRaw / currentMode).ceil() * currentMode).toDouble() : simulatedRaw;
    final simulatedDiff = simulatedRounded - simulatedRaw;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          backgroundColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Mode Pembulatan Kasir', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih kelipatan nominal pembulatan untuk mempermudah transaksi kasir dengan uang tunai (cash). Pembulatan akan otomatis diterapkan pada checkout POS.',
                style: TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.4),
              ),
              const SizedBox(height: 16),

              _buildRoundingOptionCard(
                title: 'Tanpa Pembulatan (0)',
                description: 'Total transaksi tampil persis sesuai harga aslinya tanpa perubahan.',
                modeValue: 0,
                selectedMode: currentMode,
                onSelect: () => authCtrl.updateRoundingMode(0),
              ),
              const SizedBox(height: 10),
              _buildRoundingOptionCard(
                title: 'Kelipatan Rp 100',
                description: 'Dibulatkan ke atas ke kelipatan Rp 100 terdekat (Contoh: Rp 12.340 -> Rp 12.400).',
                modeValue: 100,
                selectedMode: currentMode,
                onSelect: () => authCtrl.updateRoundingMode(100),
              ),
              const SizedBox(height: 10),
              _buildRoundingOptionCard(
                title: 'Kelipatan Rp 500',
                description: 'Dibulatkan ke atas ke kelipatan Rp 500 terdekat (Contoh: Rp 12.340 -> Rp 12.500).',
                modeValue: 500,
                selectedMode: currentMode,
                onSelect: () => authCtrl.updateRoundingMode(500),
              ),
              const SizedBox(height: 10),
              _buildRoundingOptionCard(
                title: 'Kelipatan Rp 1.000',
                description: 'Dibulatkan ke atas ke kelipatan Rp 1.000 terdekat (Contoh: Rp 12.340 -> Rp 13.000).',
                modeValue: 1000,
                selectedMode: currentMode,
                onSelect: () => authCtrl.updateRoundingMode(1000),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Simulator
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          backgroundColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.visibility_rounded, color: AppColors.slate700, size: 18),
                  SizedBox(width: 8),
                  Text('Simulasi Perhitungan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Coba pilih contoh nominal belanja:', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [14250.0, 23890.0, 47120.0, 89550.0].map((val) {
                  final isSel = _simulationAmount == val;
                  return ChoiceChip(
                    label: Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val)),
                    selected: isSel,
                    selectedColor: AppColors.primary50,
                    onSelected: (_) => setState(() => _simulationAmount = val),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  children: [
                    _buildSimLine('Total Belanja Asli', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(simulatedRaw)),
                    const SizedBox(height: 6),
                    _buildSimLine(
                      'Selisih Pembulatan',
                      '+${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(simulatedDiff)}',
                      textColor: simulatedDiff > 0 ? const Color(0xFFD97706) : AppColors.slate500,
                    ),
                    const Divider(height: 16),
                    _buildSimLine(
                      'TOTAL DIBAYAR KONSUMEN',
                      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(simulatedRounded),
                      isBold: true,
                      textColor: AppColors.primary,
                      fontSize: 15,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: MANAJEMEN MEDIA (MinIO)
  // ===========================================================================
  Widget _buildMediaTab(AuthController authCtrl) {
    if (!authCtrl.isProOrPlus) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(22),
            backgroundColor: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.cloud_queue_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Manajemen Media MinIO Cloud',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fitur manajemen media object storage (MinIO) terintegrasi pada Paket Pro / Plus saat online. Pada Paket Free, gambar produk & logo tersimpan di database SQLite perangkat Anda secara offline-first.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Cek Status Langganan Cloud', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () async {
                    await authCtrl.refreshTenantPlan();
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Filter media items
    final filtered = _mediaItems.where((item) {
      if (_mediaFilter == 'USED' && item['usage']?['type'] == 'UNUSED') return false;
      if (_mediaFilter == 'UNUSED' && item['usage']?['type'] != 'UNUSED') return false;
      if (_mediaSearch.trim().isNotEmpty) {
        final q = _mediaSearch.toLowerCase();
        final fn = (item['filename'] as String? ?? '').toLowerCase();
        final lbl = (item['usage']?['label'] as String? ?? '').toLowerCase();
        return fn.contains(q) || lbl.contains(q);
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchMedia,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // Summary Card
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ringkasan Media MinIO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      onPressed: _isMediaLoading ? null : _fetchMedia,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildSummaryStat('Total File', '${_mediaSummary['totalFiles'] ?? 0}'),
                    _buildSummaryStat('Terpakai', '${_mediaSummary['totalUsed'] ?? 0}', color: const Color(0xFF047857)),
                    _buildSummaryStat('Tidak Terpakai', '${_mediaSummary['totalUnused'] ?? 0}', color: const Color(0xFFD97706)),
                    _buildSummaryStat('Ukuran', _formatBytes(_mediaSummary['totalBytes'] as num?)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search & Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari nama file media...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
                  ),
                  onChanged: (val) => setState(() => _mediaSearch = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFilterChip('Semua', 'ALL'),
              const SizedBox(width: 8),
              _buildFilterChip('Terpakai', 'USED'),
              const SizedBox(width: 8),
              _buildFilterChip('Tidak Terpakai', 'UNUSED'),
            ],
          ),
          const SizedBox(height: 16),

          // List / Grid Media
          if (_isMediaLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.perm_media_outlined, size: 48, color: AppColors.slate300),
                    const SizedBox(height: 10),
                    Text(
                      _mediaItems.isEmpty ? 'Belum ada media tersimpan di MinIO.' : 'Tidak ada media yang cocok dengan filter.',
                      style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(filtered.length, (idx) {
              final item = filtered[idx];
              final key = item['key'] as String? ?? '';
              final fn = item['filename'] as String? ?? 'file';
              final url = item['url'] as String? ?? '';
              final size = item['size'] as num?;
              final usage = item['usage'] as Map<String, dynamic>?;
              final isUsed = usage?['type'] != 'UNUSED';
              final isDeleting = _deletingMediaKey == key;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 24, color: AppColors.slate400),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(_formatBytes(size), style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isUsed ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              usage?['label'] ?? (isUsed ? 'Terpakai' : 'Tidak Terpakai'),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isUsed ? const Color(0xFF047857) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.slate600),
                      tooltip: 'Salin URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL media berhasil disalin!')),
                        );
                      },
                    ),
                    IconButton(
                      icon: isDeleting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger))
                          : const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                      tooltip: 'Hapus Media',
                      onPressed: isDeleting ? null : () => _deleteMedia(key, fn),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── HELPER WIDGETS ────────────────────────────────────────────────────────
  Widget _buildInfoRow(String label, String value, {bool isCopyable = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate800)),
            if (isCopyable) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks disalin ke papan klip!')));
                },
                child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.slate400),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFormatOptionCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary50 : AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.slate200, width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? AppColors.primaryDark : AppColors.slate900)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.slate500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundingOptionCard({
    required String title,
    required String description,
    required int modeValue,
    required int selectedMode,
    required VoidCallback onSelect,
  }) {
    final isSelected = selectedMode == modeValue;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.slate200, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Radio<int>(
              value: modeValue,
              groupValue: selectedMode,
              activeColor: AppColors.primary,
              onChanged: (_) => onSelect(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? AppColors.primaryDark : AppColors.slate900)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimLine(String label, String value, {bool isBold = false, Color? textColor, double fontSize = 12}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, color: AppColors.slate600, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: textColor ?? AppColors.slate900)),
      ],
    );
  }

  Widget _buildSummaryStat(String title, String val, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color ?? AppColors.slate900)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.slate500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSel = _mediaFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
      selected: isSel,
      selectedColor: AppColors.primary50,
      onSelected: (_) => setState(() => _mediaFilter = value),
    );
  }

  void _confirmLogout(BuildContext context, AuthController authCtrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar dari Akun Kasir?'),
        content: const Text(
          'Sesi kasir akan diakhiri. Pastikan semua transaksi shift hari ini sudah ditutup atau tercatat.',
          style: TextStyle(fontSize: 13, color: AppColors.slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.slate600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await authCtrl.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }
}
