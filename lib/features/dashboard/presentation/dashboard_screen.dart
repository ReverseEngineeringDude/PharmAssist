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
    final isDark = theme.brightness == Brightness.dark;

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
            // 1. EXECUTIVE DASHBOARD HEADER BANNER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pharmacy Command Center',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Real-time overview of inventory health, stock reorder alerts, and expiry risk monitoring',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Quick Action Buttons
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(activeNavIndexProvider.notifier).state = 1; // POS Billing
                    },
                    icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                    label: const Text('POS Billing (F2)', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. STYLISH KPI CARDS ROW
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Low Stock Items',
                    count: lowStockList.length.toString(),
                    subtitle: lowStockList.isEmpty ? 'All items healthy' : '${lowStockList.length} items below reorder level',
                    icon: Icons.warning_amber_rounded,
                    color: lowStockList.isEmpty ? const Color(0xFF10B981) : Colors.orange,
                    onTap: () => _switchTab(0),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Expired Batches',
                    count: expiredList.length.toString(),
                    subtitle: expiredList.isEmpty
                        ? 'Zero expired stock'
                        : 'Est. Loss: ₹${totalLoss.toStringAsFixed(2)}',
                    icon: Icons.error_outline_rounded,
                    color: expiredList.isEmpty ? const Color(0xFF10B981) : Colors.red,
                    onTap: () => _switchTab(1),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Expiring Soon (<=90d)',
                    count: nearExpiryList.length.toString(),
                    subtitle: nearExpiryList.isEmpty ? 'No immediate expiries' : 'Requires FEFO sales priority',
                    icon: Icons.access_time_rounded,
                    color: nearExpiryList.isEmpty ? const Color(0xFF10B981) : Colors.amber.shade700,
                    onTap: () => _switchTab(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Active Master Catalog',
                    count: (medicinesAsync.asData?.value.length ?? 0).toString(),
                    subtitle: 'Total registered medicines',
                    icon: Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                    onTap: () => _switchTab(3),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 3. PILL SEGMENTED TAB BAR FOR ALERTS
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1.5),
                ),
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    height: 38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Low Stock (${lowStockList.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Expired (${expiredList.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Expiring Soon (${nearExpiryList.length})'),
                      ],
                    ),
                  ),
                  const Tab(
                    height: 38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_active_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('All Urgent Alerts'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4. TAB VIEWS CONTENT AREA
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
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
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
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
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 52, color: Color(0xFF10B981)),
              SizedBox(height: 12),
              Text(
                'Stock levels healthy! No low-stock items detected.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text('All inventory items are above their reorder thresholds.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final med = item.medicine;
          final isZero = item.totalQuantity == 0;
          final statusColor = isZero ? Colors.red : Colors.orange;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(
                    isZero ? Icons.block : Icons.warning_amber_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            med.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isZero ? 'OUT OF STOCK' : 'LOW STOCK',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: ${med.category ?? 'General'} • Generic: ${med.genericName ?? '—'} • Unit: ${med.unit}',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      isZero ? 'Reorder Immediate' : 'Deficit: ${med.reorderLevel - item.totalQuantity} ${med.unit}s',
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => StockAdjustmentDialog(medicine: med),
                    );
                  },
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Restock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined, size: 52, color: Color(0xFF10B981)),
                  SizedBox(height: 12),
                  Text(
                    'No expired stock found in inventory!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 4),
                  Text('All registered batches are within valid shelf life.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final batch = item.batch;
              final med = item.medicine;
              final loss = batch.quantity * batch.purchasePrice;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.red.withValues(alpha: 0.15),
                      child: const Icon(Icons.event_busy, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${med.name} — Batch: ${batch.batchNo}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'EXPIRED',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Expired On: ${dateFormat.format(batch.expiryDate)} • Unit Cost: ₹${batch.purchasePrice.toStringAsFixed(2)} • MRP: ₹${batch.mrp.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Qty: ${batch.quantity} ${med.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.red),
                        ),
                        Text(
                          'Est. Loss: ₹${loss.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
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
                      icon: const Icon(Icons.delete_outline, size: 15),
                      label: const Text('Dispose Stock', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
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
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_up_alt_outlined, size: 52, color: Color(0xFF10B981)),
                  SizedBox(height: 12),
                  Text(
                    'No batches expiring in the next 90 days.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 4),
                  Text('All batch expiries are well in the future.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final batch = item.batch;
              final med = item.medicine;

              final daysRemaining = batch.expiryDate.difference(now).inDays;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                      child: Icon(Icons.access_time_rounded, color: Colors.amber.shade800, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${med.name} — Batch: ${batch.batchNo}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$daysRemaining DAYS LEFT',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Expiry Date: ${dateFormat.format(batch.expiryDate)} • MRP: ₹${batch.mrp.toStringAsFixed(2)} • Cost: ₹${batch.purchasePrice.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Qty: ${batch.quantity} ${med.unit}',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.amber.shade900),
                        ),
                        Text(
                          'Prioritize Sales (FEFO)',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade800, fontWeight: FontWeight.bold),
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
                      icon: const Icon(Icons.qr_code_2, size: 15),
                      label: const Text('Batches', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
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
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 54, color: Color(0xFF10B981)),
              SizedBox(height: 12),
              Text(
                'Zero Inventory Alerts!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (expired.isNotEmpty) ...[
            _buildSectionHeader(theme, 'EXPIRED BATCHES (${expired.length})', Colors.red),
            ...expired.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title: Text('${item.medicine.name} (Batch: ${item.batch.batchNo})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Qty: ${item.batch.quantity} | Expired: ${item.batch.expiryDate.toString().split(' ')[0]}'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => StockAdjustmentDialog(medicine: item.medicine),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Dispose', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          if (lowStock.isNotEmpty) ...[
            _buildSectionHeader(theme, 'LOW STOCK ITEMS (${lowStock.length})', Colors.orange),
            ...lowStock.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  title: Text(item.medicine.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Stock: ${item.totalQuantity} / Reorder Level: ${item.medicine.reorderLevel}'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => StockAdjustmentDialog(medicine: item.medicine),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Restock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          if (nearExpiry.isNotEmpty) ...[
            _buildSectionHeader(theme, 'SOON EXPIRING BATCHES (${nearExpiry.length})', Colors.amber.shade800),
            ...nearExpiry.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.access_time_rounded, color: Colors.amber.shade800),
                  title: Text('${item.medicine.name} (Batch: ${item.batch.batchNo})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Qty: ${item.batch.quantity} | Expiry: ${item.batch.expiryDate.toString().split(' ')[0]}'),
                  trailing: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => BatchManagementDialog(medicine: item.medicine),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Inspect', style: TextStyle(fontSize: 11)),
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

