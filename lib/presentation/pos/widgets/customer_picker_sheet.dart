import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/app_database.dart';
import '../../customers/widgets/customer_form_dialog.dart';

class CustomerPickerSheet extends ConsumerStatefulWidget {
  final String? selectedCustomerId;

  const CustomerPickerSheet({super.key, this.selectedCustomerId});

  static Future<Customer?> show(
    BuildContext context, {
    String? selectedCustomerId,
  }) {
    return showModalBottomSheet<Customer?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerPickerSheet(
        selectedCustomerId: selectedCustomerId,
      ),
    );
  }

  @override
  ConsumerState<CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListStreamProvider);

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_pin_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Pilih Pelanggan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search + Add Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari pelanggan...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    final newId = await CustomerFormDialog.show(context);
                    if (newId != null && context.mounted) {
                      final newCust = await ref
                          .read(customerRepositoryProvider)
                          .getCustomerById(newId);
                      if (context.mounted && newCust != null) {
                        Navigator.pop(context, newCust);
                      }
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Baru'),
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (customers) {
                final filtered = customers.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return c.name.toLowerCase().contains(q) ||
                      (c.phone != null && c.phone!.toLowerCase().contains(q));
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Belum ada pelanggan tersimpan'
                                : 'Pelanggan "$_searchQuery" tidak ditemukan',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () async {
                              final newId =
                                  await CustomerFormDialog.show(context);
                              if (newId != null && context.mounted) {
                                final newCust = await ref
                                    .read(customerRepositoryProvider)
                                    .getCustomerById(newId);
                                if (context.mounted && newCust != null) {
                                  Navigator.pop(context, newCust);
                                }
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text('Tambah Pelanggan Ini'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    final isSelected = customer.id == widget.selectedCustomerId;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor:
                            isSelected ? Colors.white : AppColors.primary,
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        customer.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      subtitle: customer.phone != null &&
                              customer.phone!.isNotEmpty
                          ? Text(
                              customer.phone!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            )
                          : null,
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, customer),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}
