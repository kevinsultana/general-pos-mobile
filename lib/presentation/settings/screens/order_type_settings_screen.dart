import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/app_database.dart' show Store;
import '../../../domain/models/store_ext.dart';
import '../../../domain/repositories/i_store_repository.dart';

/// Screen to manage Order Types (Dine In, Takeaway, etc.) and toggle active status.
class OrderTypeSettingsScreen extends ConsumerWidget {
  const OrderTypeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(currentStoreStreamProvider);
    final storeRepo = ref.read(storeRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Pilihan Tipe Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Terjadi kesalahan: $err')),
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Data toko tidak ditemukan'));
          }

          final orderTypes = store.orderTypesList;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Card 1: Status Saklar (On / Off)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SwitchListTile(
                    key: const Key('order_type_switch'),
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: store.orderTypeEnabled
                            ? Colors.teal.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.room_service_rounded,
                        color: store.orderTypeEnabled
                            ? Colors.teal.shade700
                            : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Status Pilihan Tipe Pesanan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      store.orderTypeEnabled
                          ? 'Aktif — Pilihan tipe pesanan akan ditampilkan saat checkout di kasir POS.'
                          : 'Nonaktif — Transaksi kasir tidak akan meminta pilihan tipe pesanan.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: store.orderTypeEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                      final messenger = ScaffoldMessenger.of(context);
                      await storeRepo.setOrderTypeEnabled(store.id, val);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                                ? 'Pilihan Tipe Pesanan diaktifkan'
                                : 'Pilihan Tipe Pesanan dinonaktifkan',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: Header Daftar Pilihan
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'Daftar Pilihan Aktif',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: store.orderTypeEnabled
                          ? Colors.teal.shade50
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${orderTypes.length} Opsi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: store.orderTypeEnabled
                            ? Colors.teal.shade800
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _confirmResetOrderTypes(
                      context,
                      store,
                      storeRepo,
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Reset Default',
                        style: TextStyle(fontSize: 12)),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('add_order_type_button'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showAddOrderTypeDialog(
                      context,
                      store,
                      storeRepo,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Tambah Opsi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (!store.orderTypeEnabled) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pilihan tipe pesanan sedang nonaktif. Aktifkan saklar di atas agar opsi di bawah muncul di kasir.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Card Daftar Tipe Pesanan
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: orderTypes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.room_service_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada pilihan tipe pesanan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _confirmResetOrderTypes(
                                context,
                                store,
                                storeRepo,
                              ),
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('Gunakan Opsi Standar'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orderTypes.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (context, index) {
                          final opt = orderTypes[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: store.orderTypeEnabled
                                    ? Colors.teal.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: store.orderTypeEnabled
                                        ? Colors.teal.shade800
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              opt,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: store.orderTypeEnabled
                                    ? AppColors.textPrimaryLight
                                    : Colors.grey.shade600,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  color: AppColors.primary,
                                  tooltip: 'Ubah Nama',
                                  onPressed: () => _showEditOrderTypeDialog(
                                    context,
                                    store,
                                    storeRepo,
                                    opt,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                  color: AppColors.danger,
                                  tooltip: 'Hapus Opsi',
                                  onPressed: () => _deleteOrderType(
                                    context,
                                    store,
                                    storeRepo,
                                    opt,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // Chip preview
              if (orderTypes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tampilan Tombol di Kasir POS:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: orderTypes.map((opt) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  opt,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddOrderTypeDialog(
    BuildContext context,
    Store store,
    IStoreRepository storeRepo,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Tipe Pesanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama Tipe Pesanan *',
                hintText: 'Cth: Ojol, Katering, Drive Thru',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                final trimmed = val?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Nama tipe pesanan tidak boleh kosong';
                }
                final currentList = store.orderTypesList;
                if (currentList.any(
                    (e) => e.toLowerCase() == trimmed.toLowerCase())) {
                  return 'Tipe pesanan "$trimmed" sudah ada';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newType = controller.text.trim();
                final updatedList = [...store.orderTypesList, newType];
                await storeRepo.updateOrderTypes(
                  storeId: store.id,
                  orderTypes: updatedList,
                );
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Tipe pesanan "$newType" berhasil ditambahkan'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditOrderTypeDialog(
    BuildContext context,
    Store store,
    IStoreRepository storeRepo,
    String oldName,
  ) async {
    final controller = TextEditingController(text: oldName);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ubah Tipe Pesanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama Tipe Pesanan *',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                final trimmed = val?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Nama tipe pesanan tidak boleh kosong';
                }
                if (trimmed.toLowerCase() != oldName.toLowerCase()) {
                  final currentList = store.orderTypesList;
                  if (currentList.any(
                      (e) => e.toLowerCase() == trimmed.toLowerCase())) {
                    return 'Tipe pesanan "$trimmed" sudah ada';
                  }
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final updatedName = controller.text.trim();
                final updatedList = store.orderTypesList
                    .map((e) => e == oldName ? updatedName : e)
                    .toList();
                await storeRepo.updateOrderTypes(
                  storeId: store.id,
                  orderTypes: updatedList,
                );
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Tipe pesanan berhasil diubah menjadi "$updatedName"'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteOrderType(
    BuildContext context,
    Store store,
    IStoreRepository storeRepo,
    String targetName,
  ) async {
    final currentList = store.orderTypesList;
    if (currentList.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 tipe pesanan yang aktif.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final updatedList = currentList.where((e) => e != targetName).toList();
    await storeRepo.updateOrderTypes(
      storeId: store.id,
      orderTypes: updatedList,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tipe pesanan "$targetName" dihapus'),
          action: SnackBarAction(
            label: 'Batal',
            onPressed: () async {
              await storeRepo.updateOrderTypes(
                storeId: store.id,
                orderTypes: currentList,
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _confirmResetOrderTypes(
    BuildContext context,
    Store store,
    IStoreRepository storeRepo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Tipe Pesanan?'),
        content: const Text(
          'Kembalikan daftar pilihan tipe pesanan ke default:\n• Dine In\n• Takeaway\n• Delivery\n• Online',
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
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await storeRepo.updateOrderTypes(
        storeId: store.id,
        orderTypes: const ['Dine In', 'Takeaway', 'Delivery', 'Online'],
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilihan tipe pesanan dikembalikan ke default'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    }
  }
}
