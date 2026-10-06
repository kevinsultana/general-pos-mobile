import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/controllers/auth_controller.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final LocalRepository _repo = LocalRepository();
  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final tenant = context.read<AuthController>().currentTenant;
    if (tenant != null) {
      _customers = await _repo.getCustomers(tenant.id);
    }
    setState(() => _isLoading = false);
  }

  List<CustomerModel> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((c) {
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.phone != null && c.phone!.contains(_searchQuery));
    }).toList();
  }

  void _showAddCustomerDialog([CustomerModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existing == null ? 'Tambah Pelanggan' : 'Edit Pelanggan',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nama Lengkap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Misal: Budi Santoso',
                  filled: true,
                  fillColor: AppColors.slate100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Nomor WhatsApp / HP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '08123456789',
                  filled: true,
                  fillColor: AppColors.slate100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Email (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'budi@email.com',
                  filled: true,
                  fillColor: AppColors.slate100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Alamat (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  hintText: 'Alamat tempat tinggal / kantor',
                  filled: true,
                  fillColor: AppColors.slate100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final tenant = context.read<AuthController>().currentTenant;
              if (tenant == null) return;

              final customer = CustomerModel(
                id: existing?.id ?? IdGenerator.v4(),
                tenantId: tenant.id,
                name: name,
                phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                address: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
              );

              await _repo.insertCustomer(customer);
              if (!mounted) return;
              Navigator.pop(ctx);
              _loadCustomers();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredCustomers;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Daftar Pelanggan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900)),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tambah Pelanggan', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddCustomerDialog(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              backgroundColor: Colors.white.withOpacity(0.9),
              child: TextField(
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Cari nama atau nomor HP pelanggan...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.slate400),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 48, color: AppColors.slate300),
                            const SizedBox(height: 12),
                            const Text('Belum ada pelanggan', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
                        itemCount: list.length,
                        separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final c = list[idx];
                          return GlassCard(
                            borderRadius: 16,
                            padding: const EdgeInsets.all(14),
                            backgroundColor: Colors.white.withOpacity(0.9),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.person_rounded, color: AppColors.primaryDark),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900)),
                                      const SizedBox(height: 2),
                                      Text(c.phone ?? 'Tidak ada no. telp', style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                                  onPressed: () async {
                                    await _repo.deleteCustomer(c.id);
                                    _loadCustomers();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
