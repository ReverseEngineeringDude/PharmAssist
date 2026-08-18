import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/core/widgets/app_shell.dart';
import 'package:pharmassist/data/repositories/inventory_repository.dart';
import 'package:pharmassist/features/inventory/presentation/batch_management_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/stock_adjustment_dialog.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final medicinesAsync = ref.watch(medicinesWithStockProvider);
    final lowStockList = ref.watch(lowStockMedicinesProvider);
    final expiredAsync = ref.watch(expiredBatchesStreamProvider);
    final nearExpiryAsync = ref.watch(nearExpiryBatchesStreamProvider);

    final expiredList = expiredAsync.asData?.value ?? [];
    final nearExpiryList = nearExpiryAsync.asData?.value ?? [];

    // Calculate total financial loss for expired items
    final totalLoss = expiredList.fold<double>(
      0.0,
      (sum, item) => sum + (item.batch.quantity * item.batch.purchasePrice),
    );

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Dashboard Header Bar
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.dashboard_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pharmacy Dashboard & Alert Center',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Real-time overview of inventory health, stock alerts, and expiry risks',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                const Spacer(),

                // POS Quick Action
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to POS Billing (index 1)
                    ref.read(activeNavIndexProvider.notifier).state = 1;
                  },
                  icon: const Icon(Icons.point_of_sale, size: 18),
                  label: const Text('POS Billing (F2)'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Top KPI Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Low Stock Items',
                    count: lowStockList.length.toString(),
                    subtitle: lowStockList.isEmpty ? 'All items well stocked' : '${lowStockList.length} items below reorder level',
                    icon: Icons.warning_amber_rounded,
                    color: lowStockList.isEmpty ? Colors.green : Colors.orange,
                    onTap: () => _switchTab(0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Expired Items',
                    count: expiredList.length.toString(),
                    subtitle: expiredList.isEmpty
                        ? 'No expired batches'
                        : 'Est. Loss: ₹${totalLoss.toStringAsFixed(2)}',
                    icon: Icons.error_outline_rounded,
                    color: expiredList.isEmpty ? Colors.green : Colors.red,
                    onTap: () => _switchTab(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Soon Expiring Items',
                    count: nearExpiryList.length.toString(),
                    subtitle: nearExpiryList.isEmpty ? 'No batches near expiry' : 'Expiring in <= 90 days',
                    icon: Icons.access_time_rounded,
                    color: nearExpiryList.isEmpty ? Colors.green : Colors.amber.shade700,
                    onTap: () => _switchTab(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Total Medicines Master',
                    count: (medicinesAsync.asData?.value.length ?? 0).toString(),
                    subtitle: 'Active database catalog',
                    icon: Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                    onTap: () => _switchTab(3),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tab Bar for Alert Sections
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text('Low Stock (${lowStockList.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text('Expired (${expiredList.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text('Soon Expiring (${nearExpiryList.length})'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_active_outlined, size: 18),
                        SizedBox(width: 6),
                        Text('All Urgent Alerts'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab Views Content Area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Low Stock Items
                  _buildLowStockTab(context, lowStockList),

                  // Tab 2: Expired Items
                  _buildExpiredTab(context, expiredAsync),

                  // Tab 3: Soon Expiring Items
                  _buildSoonExpiringTab(context, nearExpiryAsync),

                  // Tab 4: All Alerts Combined Feed
                  _buildAllAlertsTab(context, lowStockList, expiredList, nearExpiryList),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockTab(BuildContext context, List<MedicineWithStock> items) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green),
              SizedBox(height: 12),
              Text(
                'Stock levels healthy! No low-stock items detected.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final med = item.medicine;
          final isZero = item.totalQuantity == 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (isZero ? Colors.red : Colors.orange).withValues(alpha: 0.15),
                  child: Icon(
                    isZero ? Icons.block : Icons.warning_amber_rounded,
                    color: isZero ? Colors.red : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Category: ${med.category ?? 'General'} | Generic: ${med.genericName ?? '—'} | Unit: ${med.unit}',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Stock: ${item.totalQuantity} / Min: ${med.reorderLevel}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isZero ? Colors.red : Colors.orange,
                      ),
                    ),
                    Text(
                      isZero ? 'OUT OF STOCK' : 'Deficit: ${med.reorderLevel - item.totalQuantity} ${med.unit}s',
                      style: TextStyle(fontSize: 10, color: isZero ? Colors.red : Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => StockAdjustmentDialog(medicine: med),
                    );
                  },
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Stock'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpiredTab(BuildContext context, AsyncValue<List<BatchWithMedicine>> asyncVal) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    return asyncVal.when(
      data: (items) {
        if (items.isEmpty) {
          return Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined, size: 48, color: Colors.green),
                  SizedBox(height: 12),
                  Text(
                    'No expired stock found in inventory!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final batch = item.batch;
              final med = item.medicine;
              final loss = batch.quantity * batch.purchasePrice;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.red.withValues(alpha: 0.15),
                      child: const Icon(Icons.event_busy, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${med.name} — Batch: ${batch.batchNo}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Expired On: ${dateFormat.format(batch.expiryDate)} | Unit Cost: ₹${batch.purchasePrice.toStringAsFixed(2)} | MRP: ₹${batch.mrp.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Qty: ${batch.quantity} ${med.unit}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                        ),
                        Text(
                          'Loss: ₹${loss.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => StockAdjustmentDialog(medicine: med),
                        );
                      },
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Dispose Stock'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading expired batches: $err')),
    );
  }

  Widget _buildSoonExpiringTab(BuildContext context, AsyncValue<List<BatchWithMedicine>> asyncVal) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');
    final now = DateTime.now();

    return asyncVal.when(
      data: (items) {
        if (items.isEmpty) {
          return Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_up_alt_outlined, size: 48, color: Colors.green),
                  SizedBox(height: 12),
                  Text(
                    'No batches expiring in the next 90 days.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final batch = item.batch;
              final med = item.medicine;

              final daysRemaining = batch.expiryDate.difference(now).inDays;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                      child: const Icon(Icons.access_time_rounded, color: Colors.amber),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${med.name} — Batch: ${batch.batchNo}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$daysRemaining days left',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Expiry Date: ${dateFormat.format(batch.expiryDate)} | MRP: ₹${batch.mrp.toStringAsFixed(2)} | Cost: ₹${batch.purchasePrice.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Qty: ${batch.quantity} ${med.unit}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Text(
                          'Prioritize Sales (FEFO)',
                          style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => BatchManagementDialog(medicine: med),
                        );
                      },
                      icon: const Icon(Icons.qr_code, size: 14),
                      label: const Text('View Batches'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading near-expiry batches: $err')),
    );
  }

  Widget _buildAllAlertsTab(
    BuildContext context,
    List<MedicineWithStock> lowStock,
    List<BatchWithMedicine> expired,
    List<BatchWithMedicine> nearExpiry,
  ) {
    final theme = Theme.of(context);
    final totalAlerts = lowStock.length + expired.length + nearExpiry.length;

    if (totalAlerts == 0) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 54, color: Colors.green),
              SizedBox(height: 12),
              Text(
                'Zero Inventory Alerts!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'All stock levels are optimal and no batches are expired or near expiry.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (expired.isNotEmpty) ...[
            _buildSectionHeader(theme, 'EXPIRED BATCHES (${expired.length})', Colors.red),
            ...expired.map((item) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text('${item.medicine.name} (Batch: ${item.batch.batchNo})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Qty: ${item.batch.quantity} | Expired: ${item.batch.expiryDate.toString().split(' ')[0]}'),
                trailing: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => StockAdjustmentDialog(medicine: item.medicine),
                    );
                  },
                  child: const Text('Dispose', style: TextStyle(color: Colors.red)),
                ),
              );
            }),
            const Divider(),
          ],

          if (lowStock.isNotEmpty) ...[
            _buildSectionHeader(theme, 'LOW STOCK ITEMS (${lowStock.length})', Colors.orange),
            ...lowStock.map((item) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                title: Text(item.medicine.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Stock: ${item.totalQuantity} / Reorder Level: ${item.medicine.reorderLevel}'),
                trailing: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => StockAdjustmentDialog(medicine: item.medicine),
                    );
                  },
                  child: const Text('Restock'),
                ),
              );
            }),
            const Divider(),
          ],

          if (nearExpiry.isNotEmpty) ...[
            _buildSectionHeader(theme, 'SOON EXPIRING BATCHES (${nearExpiry.length})', Colors.amber),
            ...nearExpiry.map((item) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.access_time_rounded, color: Colors.amber),
                title: Text('${item.medicine.name} (Batch: ${item.batch.batchNo})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Qty: ${item.batch.quantity} | Expiry: ${item.batch.expiryDate.toString().split(' ')[0]}'),
                trailing: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => BatchManagementDialog(medicine: item.medicine),
                    );
                  },
                  child: const Text('Inspect'),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
