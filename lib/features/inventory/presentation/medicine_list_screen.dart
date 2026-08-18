import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/features/inventory/presentation/batch_management_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/medicine_form_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/stock_adjustment_dialog.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';

class MedicineListScreen extends ConsumerWidget {
  const MedicineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final medicinesAsync = ref.watch(medicinesWithStockProvider);
    final filteredList = ref.watch(filteredMedicinesProvider);

    final searchQuery = ref.watch(medicineSearchQueryProvider);
    final selectedSchedule = ref.watch(selectedScheduleFilterProvider);

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Toolbar & Stats Row
            Row(
              children: [
                // Title
                Row(
                  children: [
                    Icon(Icons.inventory_2, color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory & Medicine Master',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Batch-level stock tracking & FEFO monitoring',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),

                // Stat Badges
                medicinesAsync.when(
                  data: (items) {
                    final lowStockCount = items.where((i) => i.totalQuantity <= i.medicine.reorderLevel).length;
                    final nearExpiryCount = items.where((i) => i.hasNearExpiry).length;
                    final expiredCount = items.where((i) => i.hasExpired).length;

                    return Row(
                      children: [
                        _buildStatCard(
                          label: 'Total Items',
                          count: items.length.toString(),
                          color: theme.colorScheme.primary,
                          icon: Icons.category_outlined,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          label: 'Low Stock',
                          count: lowStockCount.toString(),
                          color: lowStockCount > 0 ? Colors.orange : Colors.grey,
                          icon: Icons.warning_amber_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          label: 'Near Expiry',
                          count: nearExpiryCount.toString(),
                          color: nearExpiryCount > 0 ? Colors.amber : Colors.grey,
                          icon: Icons.access_time_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          label: 'Expired',
                          count: expiredCount.toString(),
                          color: expiredCount > 0 ? Colors.red : Colors.grey,
                          icon: Icons.error_outline,
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

                const SizedBox(width: 16),

                // Add Medicine Button
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const MedicineFormDialog(),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Medicine'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search & Filter Control Bar
            Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Search Input
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          onChanged: (val) {
                            ref.read(medicineSearchQueryProvider.notifier).state = val;
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by Brand Name, Salt, Manufacturer, HSN...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      ref.read(medicineSearchQueryProvider.notifier).state = '';
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Schedule Flag Filter Dropdown
                    SizedBox(
                      height: 38,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: selectedSchedule,
                            hint: const Text('Schedule Flag: All', style: TextStyle(fontSize: 13)),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All Schedules', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: AppConstants.scheduleNone, child: Text('OTC / None', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: AppConstants.scheduleH, child: Text('Schedule H', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: AppConstants.scheduleH1, child: Text('Schedule H1', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: AppConstants.scheduleX, child: Text('Schedule X', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) {
                              ref.read(selectedScheduleFilterProvider.notifier).state = val;
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Data Table Area
            Expanded(
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: medicinesAsync.when(
                  data: (_) {
                    if (filteredList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: theme.disabledColor),
                            const SizedBox(height: 12),
                            const Text('No medicines found matching your filter criteria.'),
                          ],
                        ),
                      );
                    }

                    return DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      minWidth: 1000,
                      headingRowColor: WidgetStateProperty.all(theme.colorScheme.surface),
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      columns: const [
                        DataColumn2(label: Text('BRAND NAME'), size: ColumnSize.L),
                        DataColumn2(label: Text('GENERIC NAME (SALT)'), size: ColumnSize.L),
                        DataColumn2(label: Text('CATEGORY'), size: ColumnSize.S),
                        DataColumn2(label: Text('HSN'), size: ColumnSize.S),
                        DataColumn2(label: Text('GST'), size: ColumnSize.S, numeric: true),
                        DataColumn2(label: Text('SCHEDULE'), size: ColumnSize.S),
                        DataColumn2(label: Text('TOTAL STOCK'), size: ColumnSize.S, numeric: true),
                        DataColumn2(label: Text('ACTIONS'), size: ColumnSize.L),
                      ],
                      rows: filteredList.map((item) {
                        final med = item.medicine;
                        final isLowStock = item.totalQuantity <= med.reorderLevel;
                        final isOutOfStock = item.totalQuantity == 0;

                        return DataRow2(
                          cells: [
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (med.manufacturer != null && med.manufacturer!.isNotEmpty)
                                    Text(
                                      med.manufacturer!,
                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(med.genericName ?? '—', style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(med.category ?? 'General', style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(med.hsnCode ?? '—', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                            ),
                            DataCell(
                              Text('${med.gstRate}%', style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              _buildScheduleBadge(med.scheduleFlag),
                            ),
                            DataCell(
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.totalQuantity} ${med.unit}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isOutOfStock
                                              ? Colors.red
                                              : (isLowStock ? Colors.orange : Colors.green),
                                        ),
                                      ),
                                      Text(
                                        '${item.batchCount} batch${item.batchCount == 1 ? '' : 'es'}',
                                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                      ),
                                    ],
                                  ),
                                  if (isLowStock) ...[
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Stock at or below reorder level (${med.reorderLevel})',
                                      child: Icon(Icons.warning_amber_rounded, size: 16, color: isOutOfStock ? Colors.red : Colors.orange),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  // Batches Button
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => BatchManagementDialog(medicine: med),
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code, size: 14),
                                    label: const Text('Batches', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Stock Adjust Button
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => StockAdjustmentDialog(medicine: med),
                                      );
                                    },
                                    icon: const Icon(Icons.tune, size: 14),
                                    label: const Text('Adjust', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Edit Medicine
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    tooltip: 'Edit Details',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => MedicineFormDialog(medicine: med),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error loading medicines: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
              Text(count, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBadge(String flag) {
    Color color = Colors.grey;
    String text = 'OTC';

    switch (flag) {
      case AppConstants.scheduleH:
        color = Colors.orange;
        text = 'Sched H';
        break;
      case AppConstants.scheduleH1:
        color = Colors.redAccent;
        text = 'Sched H1';
        break;
      case AppConstants.scheduleX:
        color = Colors.purpleAccent;
        text = 'Sched X';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
