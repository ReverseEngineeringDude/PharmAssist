import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/core/services/network_service.dart';
import 'package:pharmassist/core/theme/theme_provider.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/repositories/inventory_repository.dart';
import 'package:pharmassist/data/services/firestore_backup_service.dart';
import 'package:pharmassist/features/auth/providers/auth_provider.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';
import 'package:pharmassist/features/purchases/providers/purchase_providers.dart';

import 'package:pharmassist/features/about/presentation/about_screen.dart';
import 'package:pharmassist/features/inventory/presentation/bulk_import_dialog.dart';
import 'package:pharmassist/features/settings/presentation/firebase_backup_dialog.dart';

class MobileNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  set state(int value) => super.state = value;
}
final mobileNavIndexProvider = NotifierProvider<MobileNavIndexNotifier, int>(MobileNavIndexNotifier.new);

class MobileAppShell extends ConsumerStatefulWidget {
  const MobileAppShell({super.key});

  static void showCloudSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const FirebaseBackupCard(),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: Colors.indigo),
                      title: const Text('About Developer & Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: const Text('Developer profile, contact details & community handlers', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  ConsumerState<MobileAppShell> createState() => _MobileAppShellState();
}

class _MobileAppShellState extends ConsumerState<MobileAppShell> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeIndex = ref.watch(mobileNavIndexProvider);
    final networkState = ref.watch(networkNotifierProvider);
    final backupState = ref.watch(firestoreBackupNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                child: Icon(Icons.medical_services_rounded, color: theme.colorScheme.primary, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                AppConstants.appName,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: networkState.isOnline ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: networkState.isOnline ? Colors.green : Colors.red),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: networkState.isOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      networkState.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: networkState.isOnline ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Quick Cloud Sync Action
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.deepOrange, size: 20),
            tooltip: 'Upload Stocks to Cloud',
            onPressed: () => _triggerMobileCloudSync(context, ref),
          ),

          // Cloud Settings & Credentials Config Icon
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            icon: Icon(
              Icons.cloud_sync_rounded,
              color: backupState.isConfigured ? Colors.green : Colors.orange,
              size: 20,
            ),
            tooltip: backupState.isConfigured ? 'Firestore Configured' : 'Configure Firestore Credentials',
            onPressed: () => MobileAppShell.showCloudSettingsSheet(context),
          ),

          // About Us & Developer Info
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            tooltip: 'About Developer & Contact',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),

          // Dark Mode Toggle
          Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeModeProvider);
              final isDark = themeMode == ThemeMode.dark;
              return IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: isDark ? Colors.amber : theme.colorScheme.onSurface,
                  size: 20,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              );
            },
          ),

          // Logout
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 6, right: 10),
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Log out',
            onPressed: () async {
              ref.read(mobileNavIndexProvider.notifier).state = 0;
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!networkState.isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.red.shade900,
              child: const Text(
                'OFFLINE MODE — Local stock changes will sync when online.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: activeIndex,
              children: const [
                MobileStockDashboard(),
                MobileRestockPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: activeIndex,
          onTap: (index) => ref.read(mobileNavIndexProvider.notifier).state = index,
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Stocks Data',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_shopping_cart_outlined),
              activeIcon: Icon(Icons.add_shopping_cart),
              label: 'Restock & Cloud',
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _triggerMobileCloudSync(BuildContext context, WidgetRef ref) async {
    final state = ref.read(firestoreBackupNotifierProvider);
    if (!state.isConfigured) {
      MobileAppShell.showCloudSettingsSheet(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading stocks data to Cloud Firestore...')),
    );

    final inventoryRepo = ref.read(inventoryRepositoryProvider);
    final purchaseRepo = ref.read(purchaseRepositoryProvider);
    final medicines = await inventoryRepo.getMedicinesWithStock();
    final batches = await inventoryRepo.getAllBatches();

    final result = await ref.read(firestoreBackupNotifierProvider.notifier).backupStocks(
          medicines: medicines,
          allBatches: batches,
          purchaseRepo: purchaseRepo,
        );

    if (context.mounted) {
      if (result != null && result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloud Backup Success! ${result.backedUpCount} medicines synced.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final err = ref.read(firestoreBackupNotifierProvider).errorMessage ?? 'Cloud sync failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ==========================================
// 1. MOBILE STOCKS DASHBOARD (STOCKS DATA)
// ==========================================
class MobileStockDashboard extends ConsumerStatefulWidget {
  const MobileStockDashboard({super.key});

  @override
  ConsumerState<MobileStockDashboard> createState() => _MobileStockDashboardState();
}

class _MobileStockDashboardState extends ConsumerState<MobileStockDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'ALL'; // ALL, LOW_STOCK, EXPIRED

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicinesAsync = ref.watch(medicinesWithStockProvider);
    final searchQuery = ref.watch(medicineSearchQueryProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header KPI Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: medicinesAsync.when(
                data: (list) {
                  final totalMeds = list.length;
                  final totalQty = list.fold<int>(0, (sum, item) => sum + item.totalQuantity);
                  final lowStockCount = list.where((item) => item.totalQuantity <= item.medicine.reorderLevel).length;
                  final expiredCount = list.where((item) => item.hasExpired).length;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          label: 'Total Items',
                          value: '$totalMeds',
                          subtitle: '$totalQty units',
                          icon: Icons.medication_liquid_outlined,
                          color: Colors.cyan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          label: 'Low Stock',
                          value: '$lowStockCount',
                          subtitle: 'Reorder needed',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange,
                          isSelected: _filterStatus == 'LOW_STOCK',
                          onTap: () {
                            setState(() {
                              _filterStatus = _filterStatus == 'LOW_STOCK' ? 'ALL' : 'LOW_STOCK';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          label: 'Expired',
                          value: '$expiredCount',
                          subtitle: 'Check batches',
                          icon: Icons.event_busy_outlined,
                          color: Colors.redAccent,
                          isSelected: _filterStatus == 'EXPIRED',
                          onTap: () {
                            setState(() {
                              _filterStatus = _filterStatus == 'EXPIRED' ? 'ALL' : 'EXPIRED';
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Search & Filter Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      ref.read(medicineSearchQueryProvider.notifier).state = val;
                    },
                    decoration: InputDecoration(
                      hintText: 'Search medicine name, salt, or code...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(medicineSearchQueryProvider.notifier).state = '';
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('ALL', 'All Medicines', _filterStatus == 'ALL'),
                        const SizedBox(width: 6),
                        _buildFilterChip('LOW_STOCK', '⚠️ Low Stock', _filterStatus == 'LOW_STOCK'),
                        const SizedBox(width: 6),
                        _buildFilterChip('EXPIRED', '⛔ Expired Batches', _filterStatus == 'EXPIRED'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Medicine Stocks List
          medicinesAsync.when(
            data: (allList) {
              final query = searchQuery.trim().toLowerCase();
              var filtered = allList.where((item) {
                final med = item.medicine;
                final matchesSearch = query.isEmpty ||
                    med.name.toLowerCase().contains(query) ||
                    (med.genericName?.toLowerCase().contains(query) ?? false) ||
                    (med.manufacturer?.toLowerCase().contains(query) ?? false);

                if (_filterStatus == 'LOW_STOCK') {
                  return matchesSearch && item.totalQuantity <= item.medicine.reorderLevel;
                }
                if (_filterStatus == 'EXPIRED') {
                  return matchesSearch && item.hasExpired;
                }
                return matchesSearch;
              }).toList();

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: theme.disabledColor),
                        const SizedBox(height: 12),
                        Text('No medicines found matching filters', style: TextStyle(color: theme.disabledColor)),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = filtered[index];
                    return _MobileMedicineCard(item: item);
                  },
                  childCount: filtered.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Error loading stocks: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isSelected) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        setState(() {
          _filterStatus = value;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MobileMedicineCard extends StatefulWidget {
  final MedicineWithStock item;

  const _MobileMedicineCard({required this.item});

  @override
  State<_MobileMedicineCard> createState() => _MobileMedicineCardState();
}

class _MobileMedicineCardState extends State<_MobileMedicineCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final med = widget.item.medicine;
    final batches = widget.item.batches;
    final totalQty = widget.item.totalQuantity;
    final isLowStock = totalQty <= med.reorderLevel;
    final hasExpired = widget.item.hasExpired;

    Color statusColor = Colors.green;
    String statusText = 'IN STOCK';
    if (hasExpired) {
      statusColor = Colors.redAccent;
      statusText = 'EXPIRED BATCH';
    } else if (isLowStock) {
      statusColor = Colors.orange;
      statusText = 'LOW STOCK';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (med.genericName != null && med.genericName!.isNotEmpty)
                        Text(
                          med.genericName!,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              med.category ?? 'General',
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'GST ${med.gstRate.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$totalQty ${med.unit}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${batches.length} Active Batches',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16),
                  label: Text(_expanded ? 'Hide Batches' : 'View Batches', style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),

            if (_expanded && batches.isNotEmpty) ...[
              const Divider(height: 12),
              Column(
                children: batches.map((b) {
                  final expStr = DateFormat('dd MMM yyyy').format(b.expiryDate);
                  final isExp = b.expiryDate.isBefore(DateTime.now());
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Batch: ${b.batchNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Text(
                              'Exp: $expStr',
                              style: TextStyle(
                                fontSize: 10,
                                color: isExp ? Colors.redAccent : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: isExp ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('MRP: ₹${b.mrp.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                Text('Qty: ${b.quantity}', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. MOBILE RESTOCK PAGE (RESTOCK & CLOUD SYNC)
// ==========================================
class MobileRestockPage extends ConsumerStatefulWidget {
  const MobileRestockPage({super.key});

  @override
  ConsumerState<MobileRestockPage> createState() => _MobileRestockPageState();
}

class _MobileRestockPageState extends ConsumerState<MobileRestockPage> {
  final _formKey = GlobalKey<FormState>();

  bool _isNewMedicine = false;
  int? _selectedMedicineId;

  // New Medicine fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _genericController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(text: 'Tablet');
  final TextEditingController _unitController = TextEditingController(text: 'Strip');

  // Batch fields
  final TextEditingController _batchNoController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _purchasePriceController = TextEditingController();
  final TextEditingController _mrpController = TextEditingController();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));

  bool _autoUploadCloud = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _genericController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _batchNoController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _mrpController.dispose();
    super.dispose();
  }

  Future<void> _submitRestock() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isNewMedicine && _selectedMedicineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a medicine to restock.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final purchaseRepo = ref.read(purchaseRepositoryProvider);

      int targetMedicineId;

      if (_isNewMedicine) {
        // Create new medicine
        targetMedicineId = await repo.addMedicine(
          MedicinesCompanion.insert(
            name: _nameController.text.trim(),
            genericName: Value(_genericController.text.trim().isNotEmpty ? _genericController.text.trim() : null),
            category: Value(_categoryController.text.trim()),
            unit: Value(_unitController.text.trim()),
            reorderLevel: const Value(10),
          ),
        );
      } else {
        targetMedicineId = _selectedMedicineId!;
      }

      // Add batch
      final batchNo = _batchNoController.text.trim().toUpperCase();
      final qty = int.parse(_quantityController.text.trim());
      final pPrice = double.parse(_purchasePriceController.text.trim());
      final mrpVal = double.parse(_mrpController.text.trim());

      await repo.addBatch(
        BatchesCompanion.insert(
          medicineId: targetMedicineId,
          batchNo: batchNo,
          expiryDate: _expiryDate,
          purchasePrice: pPrice,
          mrp: mrpVal,
          quantity: Value(qty),
        ),
      );

      // Trigger Cloud Sync if requested
      String cloudMessage = '';
      if (_autoUploadCloud) {
        final state = ref.read(firestoreBackupNotifierProvider);
        if (state.isConfigured) {
          final medicines = await repo.getMedicinesWithStock();
          final allBatches = await repo.getAllBatches();

          final res = await ref.read(firestoreBackupNotifierProvider.notifier).backupStocks(
                medicines: medicines,
                allBatches: allBatches,
                purchaseRepo: purchaseRepo,
              );
          if (res != null && res.success) {
            cloudMessage = ' • ☁️ Synced to Cloud Firestore!';
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restocked $batchNo ($qty units)$cloudMessage'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        _batchNoController.clear();
        _quantityController.clear();
        _purchasePriceController.clear();
        _mrpController.clear();
        _nameController.clear();
        _genericController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restock: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicinesAsync = ref.watch(medicinesWithStockProvider);
    final backupState = ref.watch(firestoreBackupNotifierProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!backupState.isConfigured) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cloud Firestore Not Configured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                            Text('Upload google-services.json, firebase.json, or firebase_options.dart to enable auto cloud sync.', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => MobileAppShell.showCloudSettingsSheet(context),
                        child: const Text('Configure', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],

              // Card Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.add_box_rounded, color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mobile Restock & Cloud Upload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Add new batch stock & instantly push changes to Firestore cloud.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Toggle New vs Existing vs Bulk Medicine
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isNewMedicine = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        decoration: BoxDecoration(
                          color: !_isNewMedicine ? theme.colorScheme.primary : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: !_isNewMedicine ? theme.colorScheme.primary : theme.dividerColor,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Restock Existing',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_isNewMedicine ? Colors.white : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isNewMedicine = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        decoration: BoxDecoration(
                          color: _isNewMedicine ? theme.colorScheme.primary : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isNewMedicine ? theme.colorScheme.primary : theme.dividerColor,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+ New Medicine',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isNewMedicine ? Colors.white : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const BulkImportDialog(),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.6)),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, size: 14, color: Colors.purple),
                            SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                'AI Bulk',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (!_isNewMedicine) ...[
                // Medicine Dropdown Selector
                medicinesAsync.when(
                  data: (list) {
                    return DropdownButtonFormField<int>(
                      initialValue: _selectedMedicineId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Medicine *',
                        prefixIcon: Icon(Icons.medication),
                        border: OutlineInputBorder(),
                      ),
                      items: list.map((m) {
                        return DropdownMenuItem<int>(
                          value: m.medicine.id,
                          child: Text(
                            '${m.medicine.name} (Qty: ${m.totalQuantity})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedMedicineId = val;
                        });
                      },
                      validator: (val) => val == null ? 'Please select a medicine' : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Error loading medicines: $err'),
                ),
              ] else ...[
                // New Medicine Fields
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name *',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter medicine name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _genericController,
                  decoration: const InputDecoration(
                    labelText: 'Generic Name / Composition',
                    prefixIcon: Icon(Icons.science_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit (e.g., Strip, Bottle)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              const Text('Batch & Pricing Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),

              // Batch No & Quantity Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _batchNoController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Batch No *',
                        prefixIcon: Icon(Icons.qr_code),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Restock Qty *',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || int.tryParse(val) == null || int.parse(val) <= 0)
                          ? 'Valid Qty'
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Purchase Price & MRP Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Purchase Price (₹) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || double.tryParse(val) == null) ? 'Price' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _mrpController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'MRP (₹) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || double.tryParse(val) == null) ? 'MRP' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Expiry Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setState(() {
                      _expiryDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date *',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_expiryDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Auto-Upload Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.deepOrange,
                title: const Text('Auto-Upload Restock to Cloud Firestore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Immediately syncs updated stock to Google Cloud upon saving.', style: TextStyle(fontSize: 11)),
                value: _autoUploadCloud,
                onChanged: (val) {
                  setState(() {
                    _autoUploadCloud = val ?? true;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitRestock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    _isSaving ? 'Saving & Syncing...' : 'Restock & Sync to Cloud',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
