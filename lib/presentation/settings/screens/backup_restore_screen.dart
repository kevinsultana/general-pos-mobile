import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/backup_info.dart';
import '../../products/controllers/product_controller.dart';
import '../../products/controllers/category_controller.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isLoading = false;

  Future<String?> _pickDirectoryHelper() async {
    try {
      final selectedDir = await FilePicker.getDirectoryPath(
        dialogTitle: 'Pilih Folder Penyimpanan Cadangan',
      );
      if (selectedDir != null && selectedDir.isNotEmpty) {
        final service = ref.read(backupServiceProvider);
        return service.normalizeDirectoryPath(selectedDir);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih folder: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
    return null;
  }

  Future<void> _showCreateBackupDialog() async {
    final backupRepo = ref.read(backupRepositoryProvider);
    final suggestedDirs = await backupRepo.getSuggestedBackupDirectories();

    final pathController = TextEditingController(
      text: suggestedDirs.isNotEmpty ? suggestedDirs.first : '',
    );
    final passwordController = TextEditingController();
    bool hidePassword = true;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Buat Cadangan Baru'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data toko akan dienkripsi dengan algoritma AES-256 dan dilindungi dengan checksum SHA-256.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),

                // Custom Storage Path
                const Text(
                  'Folder Tempat Penyimpanan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: pathController,
                  decoration: InputDecoration(
                    hintText: 'Pilih folder atau ketik path...',
                    prefixIcon: const Icon(Icons.folder_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.drive_file_move_outline,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Pilih Folder dari File Manager',
                      onPressed: () async {
                        final dir = await _pickDirectoryHelper();
                        if (dir != null) {
                          setDialogState(() {
                            pathController.text = dir;
                          });
                        }
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Button to open File Manager folder picker
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text(
                      'Buka File Manager (Pilih Folder)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      final dir = await _pickDirectoryHelper();
                      if (dir != null) {
                        setDialogState(() {
                          pathController.text = dir;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Suggested Preset Chips
                if (suggestedDirs.isNotEmpty) ...[
                  const Text(
                    'Atau klik folder cepat:',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestedDirs.map((dir) {
                      String label = dir;
                      if (dir.contains('Download')) {
                        label = 'Folder Download HP';
                      } else if (dir.contains('backups')) {
                        label = 'Folder Cadangan Internal';
                      }
                      return ActionChip(
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        avatar: const Icon(Icons.folder_outlined, size: 14),
                        onPressed: () {
                          setDialogState(() {
                            pathController.text = dir;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),

                // Password (Optional)
                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi Cadangan (Opsional)',
                    hintText: 'Biarkan kosong untuk proteksi default',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Jika diisi kata sandi khusus, kata sandi tersebut harus diingat saat memulihkan file.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
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
              child: const Text('Mulai Cadangkan'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final activeStoreId = ref.read(activeStoreIdProvider);
        final backupInfo = await backupRepo.createBackup(
          storeId: activeStoreId,
          password: passwordController.text.trim().isEmpty
              ? null
              : passwordController.text.trim(),
          targetDirectoryPath: pathController.text.trim().isEmpty
              ? null
              : pathController.text.trim(),
        );

        ref.invalidate(backupListProvider);

        if (mounted) {
          _showBackupSuccessDialog(backupInfo);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal membuat cadangan: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showBackupSuccessDialog(BackupFileInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('Cadangan Berhasil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File cadangan terenkripsi (.posbak) telah berhasil dibuat dan disimpan.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            _infoRow('Nama File', info.fileName),
            _infoRow('Ukuran', info.formattedSize),
            _infoRow('Transaksi', '${info.transactionCount ?? 0} transaksi'),
            _infoRow('Produk', '${info.productCount ?? 0} produk'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lokasi: ${info.filePath}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Salin Path',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: info.filePath));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Path file disalin ke clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndRestoreBackup() async {
    try {
      final pickedFile = await FilePicker.pickFile(
        type: FileType.any,
        dialogTitle: 'Pilih File Cadangan POS (.posbak)',
      );

      if (pickedFile == null) {
        return; // User cancelled
      }

      final filePath = pickedFile.path;
      if (filePath == null || filePath.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat mengakses path file yang dipilih'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      if (!filePath.toLowerCase().endsWith('.posbak')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File harus berformat .posbak'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File tidak ditemukan pada: $filePath'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      final backupRepo = ref.read(backupRepositoryProvider);
      final info = await backupRepo.inspectBackupFile(filePath);
      if (info == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Format file bukan file cadangan .posbak yang valid',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      if (mounted) {
        await _confirmRestore(info);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih file: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _showCustomPathRestoreDialog() async {
    final pathController = TextEditingController();
    final passwordController = TextEditingController();
    bool hidePassword = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.file_open_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Pulihkan File Cadangan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih file .posbak langsung dari File Manager atau ketik path file:',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pathController,
                decoration: InputDecoration(
                  labelText: 'Path File (.posbak)',
                  hintText: 'Pilih file atau ketik path...',
                  prefixIcon: const Icon(
                    Icons.insert_drive_file_outlined,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.folder_open_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: 'Cari di File Manager',
                    onPressed: () async {
                      try {
                        final pickedFile = await FilePicker.pickFile(
                          type: FileType.any,
                          dialogTitle: 'Pilih File Cadangan POS (.posbak)',
                        );
                        if (pickedFile != null && pickedFile.path != null) {
                          setDialogState(() {
                            pathController.text = pickedFile.path!;
                          });
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Gagal membuka file manager: $e'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text(
                    'Buka File Manager (Pilih File)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    try {
                      final pickedFile = await FilePicker.pickFile(
                        type: FileType.any,
                        dialogTitle: 'Pilih File Cadangan POS (.posbak)',
                      );
                      if (pickedFile != null && pickedFile.path != null) {
                        setDialogState(() {
                          pathController.text = pickedFile.path!;
                        });
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Gagal membuka file manager: $e'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi (Opsional)',
                  hintText: 'Kosongkan jika proteksi default',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePassword ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
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
              child: const Text('Cek & Pulihkan'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final filePath = pathController.text.trim();
      if (filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Path file tidak boleh kosong'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File tidak ditemukan pada path: $filePath'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      final backupRepo = ref.read(backupRepositoryProvider);
      final info = await backupRepo.inspectBackupFile(filePath);
      if (info == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Format file bukan file cadangan .posbak yang valid',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      await _confirmRestore(
        info,
        prefilledPassword: passwordController.text.trim().isEmpty
            ? null
            : passwordController.text.trim(),
      );
    }
  }

  Future<void> _confirmRestore(
    BackupFileInfo backup, {
    String? prefilledPassword,
  }) async {
    final passwordController = TextEditingController(
      text: prefilledPassword ?? '',
    );
    bool hidePassword = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Konfirmasi Pemulihan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PERINGATAN: Memulihkan cadangan "${backup.fileName}" akan menimpa seluruh data toko saat ini dengan data dalam file cadangan ini.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Transaksi atau produk baru yang dibuat setelah tanggal cadangan ini akan terhapus.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Cadangan',
                  hintText: 'Kosongkan jika proteksi default',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePassword ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pulihkan Data'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final backupRepo = ref.read(backupRepositoryProvider);
        await backupRepo.restoreBackup(
          backup.filePath,
          password: passwordController.text.trim().isEmpty
              ? null
              : passwordController.text.trim(),
        );

        // Invalidate all reactive streams & providers
        _invalidateAllDatabaseProviders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data toko berhasil dipulihkan secara utuh!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memulihkan cadangan: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _confirmDelete(BackupFileInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus File Cadangan'),
        content: Text(
          'Yakin ingin menghapus file cadangan "${backup.fileName}"? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final backupRepo = ref.read(backupRepositoryProvider);
        await backupRepo.deleteBackup(backup.filePath);
        ref.invalidate(backupListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File cadangan berhasil dihapus'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _showResetDatabaseDialog() async {
    final confirmationController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_forever_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Reset Semua Data Toko'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    'PERHATIAN: Tindakan ini akan MENGHAPUS SEMUA transaksi, produk, inventori, riwayat mutasi stok, pelanggan, dan promosi secara permanen.\n\nDatabase akan dikembalikan bersih seperti baru pertama kali diinstal.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Untuk mengonfirmasi, ketik kata "RESET" di bawah ini:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmationController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Ketik RESET',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    setDialogState(() {});
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
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed:
                  confirmationController.text.trim().toUpperCase() == 'RESET'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Hapus & Reset Database'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final backupRepo = ref.read(backupRepositoryProvider);
        final activeStoreId = ref.read(activeStoreIdProvider);
        await backupRepo.resetDatabaseToInitial(
          storeId: activeStoreId,
        );

        _invalidateAllDatabaseProviders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Database berhasil di-reset! Semua data telah bersih kembali seperti baru.',
              ),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mereset database: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _invalidateAllDatabaseProviders() {
    ref.invalidate(currentStoreStreamProvider);
    ref.invalidate(productListStreamProvider);
    ref.invalidate(categoryListStreamProvider);
    ref.invalidate(transactionListStreamProvider);
    ref.invalidate(customerListStreamProvider);
    ref.invalidate(promotionListStreamProvider);
    ref.invalidate(inventoryReportProvider);
    ref.invalidate(backupListProvider);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupsAsync = ref.watch(backupListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cadangkan & Pulihkan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => ref.refresh(backupListProvider),
            child: ListView(
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
                      Icon(
                        Icons.security_rounded,
                        size: 32,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Simpan cadangan database lokal Anda secara berkala. File cadangan terenkripsi (.posbak) dapat disimpan di folder kustom atau dipindahkan ke perangkat lain.',
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

                // Action Card: Create Backup
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.blue.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.backup_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Cadangkan Data Sekarang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Mencadangkan seluruh transaksi, daftar produk, riwayat mutasi stok, pelanggan, dan promosi ke folder pilihan Anda.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : _showCreateBackupDialog,
                                icon: const Icon(Icons.add_moderator_rounded),
                                label: const Text(
                                  'Buat Cadangan Baru (.posbak)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                              foregroundColor: AppColors.primary,
                            ),
                            onPressed: _isLoading
                                ? null
                                : _pickAndRestoreBackup,
                            icon: const Icon(Icons.file_open_rounded, size: 20),
                            label: const Text(
                              'Buka File Manager (Pilih & Pulihkan .posbak)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton.icon(
                            onPressed: _isLoading
                                ? null
                                : _showCustomPathRestoreDialog,
                            icon: const Icon(Icons.keyboard_outlined, size: 16),
                            label: const Text(
                              'Atau ketik path file manual...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section Header: Stored Backups
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Riwayat Cadangan Tersimpan:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Muat Ulang',
                      onPressed: () => ref.refresh(backupListProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // List of Backups
                backupsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) =>
                      Center(child: Text('Error memuat cadangan: $err')),
                  data: (backups) {
                    if (backups.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_rounded,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum Ada File Cadangan',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tekan tombol "Buat Cadangan Baru" di atas untuk menyimpan data toko Anda.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: backups.map((b) {
                        final dateStr =
                            '${b.createdAt.day.toString().padLeft(2, '0')}/${b.createdAt.month.toString().padLeft(2, '0')}/${b.createdAt.year} ${b.createdAt.hour.toString().padLeft(2, '0')}:${b.createdAt.minute.toString().padLeft(2, '0')}';

                        return Card(
                          elevation: 0.5,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
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
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.file_present_rounded,
                                        color: Colors.blue.shade700,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.fileName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dateStr,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        b.formattedSize,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  b.filePath,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (b.transactionCount != null)
                                      _Tag(
                                        icon: Icons.receipt_long_rounded,
                                        text: '${b.transactionCount} Transaksi',
                                      ),
                                    const SizedBox(width: 8),
                                    if (b.productCount != null)
                                      _Tag(
                                        icon: Icons.inventory_2_outlined,
                                        text: '${b.productCount} Produk',
                                      ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                      tooltip: 'Salin Path',
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: b.filePath),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text('Path disalin'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                      },
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.danger,
                                      ),
                                      onPressed: () => _confirmDelete(b),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Hapus'),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _confirmRestore(b),
                                      icon: const Icon(
                                        Icons.restore_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Pulihkan'),
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
                const SizedBox(height: 32),

                // DANGER ZONE: Reset Semua Database
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.red.shade300, width: 1.5),
                  ),
                  color: Colors.red.shade50.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: Colors.red.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Reset Database ke Kondisi Awal',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mengosongkan semua transaksi, inventori, produk, dan pengaturan. Database akan kembali bersih seperti baru pertama kali instal.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading
                                ? null
                                : _showResetDatabaseDialog,
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text(
                              'Reset Semua Database',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Memproses data database...',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
