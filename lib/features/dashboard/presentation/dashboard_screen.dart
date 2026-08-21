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

class _DashboardScreenState extends ConsumerState<DashboardScreen> with TickerProviderStateMixin {
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. EXECUTIVE DASHBOARD HEADER BANNER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                // gradient: LinearGradient(
                  // colors: isDark
                  //     ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  //     : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.85)],
                //   begin: Alignment.topLeft,
                //   end: Alignment.bottomRight,
                // ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time overview of inventory health, stock reorder alerts, and expiry risk monitoring',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Quick Action Buttons
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(activeNavIndexProvider.notifier).state = 1; // POS Billing
                    },
                    icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                    label: const Text('POS Billing (F2)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. STYLISH KPI CARDS ROW (Added cascade fade-in animation)
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
                    delayIndex: 0,
                  ),
                ),
                const SizedBox(width: 16),
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
                    delayIndex: 1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Expiring Soon (<=90d)',
                    count: nearExpiryList.length.toString(),
                    subtitle: nearExpiryList.isEmpty ? 'No immediate expiries' : 'Requires FEFO sales priority',
                    icon: Icons.access_time_rounded,
                    color: nearExpiryList.isEmpty ? const Color(0xFF10B981) : Colors.amber.shade700,
                    onTap: () => _switchTab(2),
                    delayIndex: 2,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    context,
                    title: 'Active Master Catalog',
                    count: (medicinesAsync.asData?.value.length ?? 0).toString(),
                    subtitle: 'Total registered medicines',
                    icon: Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                    onTap: () => _switchTab(3),
                    delayIndex: 3,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. CLEAN SEGMENTED TAB BAR
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: [
                  Tab(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Low Stock (${lowStockList.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Expired (${expiredList.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Expiring Soon (${nearExpiryList.length})'),
                      ],
                    ),
                  ),
                  const Tab(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_active_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('All Urgent Alerts'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. TAB VIEWS CONTENT AREA
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLowStockTab(context, lowStockList),
                  _buildExpiredTab(context, expiredAsync),
                  _buildSoonExpiringTab(context, nearExpiryAsync),
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
    required int delayIndex,
  }) {
    final theme = Theme.of(context);
    
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (delayIndex * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: color.withValues(alpha: 0.05),
          highlightColor: color.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 26, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockTab(BuildContext context, List<MedicineWithStock> items) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return _buildEmptyState(
        'Stock levels healthy!', 
        'All inventory items are above their reorder thresholds.', 
        Icons.check_circle_rounded, 
        const Color(0xFF10B981)
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final med = item.medicine;
        final isZero = item.totalQuantity == 0;
        final statusColor = isZero ? Colors.red : Colors.orange;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isZero ? Icons.block : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          med.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isZero ? 'OUT OF STOCK' : 'LOW STOCK',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Category: ${med.category ?? 'General'} • Generic: ${med.genericName ?? '—'} • Unit: ${med.unit}',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isZero ? 'Reorder Immediate' : 'Deficit: ${med.reorderLevel - item.totalQuantity} ${med.unit}s',
                    style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => StockAdjustmentDialog(medicine: med),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Restock', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpiredTab(BuildContext context, AsyncValue<List<BatchWithMedicine>> asyncVal) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    return asyncVal.when(
      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState(
            'No expired stock found!', 
            'All registered batches are within valid shelf life.', 
            Icons.verified_rounded, 
            const Color(0xFF10B981)
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24, top: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final batch = item.batch;
            final med = item.medicine;
            final loss = batch.quantity * batch.purchasePrice;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_busy, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              med.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'EXPIRED',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Batch: ${batch.batchNo} • Expired On: ${dateFormat.format(batch.expiryDate)}',
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Qty: ${batch.quantity} ${med.unit}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.red),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Est. Loss: ₹${loss.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  FilledButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => StockAdjustmentDialog(medicine: med),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Dispose'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            );
          },
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
          return _buildEmptyState(
            'No near expiries!', 
            'All batch expiries are well in the future.', 
            Icons.thumb_up_alt_rounded, 
            const Color(0xFF10B981)
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24, top: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final batch = item.batch;
            final med = item.medicine;
            final daysRemaining = batch.expiryDate.difference(now).inDays;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.access_time_filled_rounded, color: Colors.amber.shade800, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              med.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$daysRemaining DAYS LEFT',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amber.shade800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Batch: ${batch.batchNo} • Expiry: ${dateFormat.format(batch.expiryDate)}',
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Qty: ${batch.quantity} ${med.unit}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prioritize (FEFO)',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade800, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  FilledButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => BatchManagementDialog(medicine: med),
                      );
                    },
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Manage'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            );
          },
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
      return _buildEmptyState(
        'Zero Inventory Alerts!', 
        'All stock levels are optimal and no batches are expired.', 
        Icons.shield_rounded, 
        const Color(0xFF10B981)
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      children: [
        if (expired.isNotEmpty) ...[
          _buildSectionHeader('EXPIRED BATCHES (${expired.length})', Colors.red),
          ...expired.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_rounded, color: Colors.red, size: 20),
                ),
                title: Text('${item.medicine.name} (Batch: ${item.batch.batchNo})', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Qty: ${item.batch.quantity} | Expired: ${item.batch.expiryDate.toString().split(' ')[0]}'),
                trailing: FilledButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => StockAdjustmentDialog(medicine: item.medicine),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Dispose', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        if (lowStock.isNotEmpty) ...[
          _buildSectionHeader('LOW STOCK ITEMS (${lowStock.length})', Colors.orange),
          ...lowStock.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded, color: Colors.orange, size: 20),
                ),
                title: Text(item.medicine.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Stock: ${item.totalQuantity} / Reorder Level: ${item.medicine.reorderLevel}'),
                trailing: FilledButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => StockAdjustmentDialog(medicine: item.medicine),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    foregroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Restock', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        if (nearExpiry.isNotEmpty) ...[
          _buildSectionHeader('SOON EXPIRING (${nearExpiry.length})', Colors.amber.shade700),
          ...nearExpiry.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.access_time_filled_rounded, color: Colors.amber.shade800, size: 20),
                ),
                title: Text('${item.medicine.name} (Batch: ${item.batch.batchNo})', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Qty: ${item.batch.quantity} | Expiry: ${item.batch.expiryDate.toString().split(' ')[0]}'),
                trailing: FilledButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => BatchManagementDialog(medicine: item.medicine),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Inspect', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}