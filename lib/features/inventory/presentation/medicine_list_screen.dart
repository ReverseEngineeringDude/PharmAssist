import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/features/inventory/presentation/batch_management_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/bulk_import_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/medicine_form_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/quick_dispense_dialog.dart';
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

                // Bulk Import AI Button
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const BulkImportDialog(),
                    );
                  },
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Bulk Import (AI)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(width: 8),

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
                      width: 185,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: selectedSchedule,
                            isExpanded: true,
                            isDense: true,
                            hint: const Text('Schedule: All', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All Schedules', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: AppConstants.scheduleNone, child: Text('OTC / None', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: AppConstants.scheduleH, child: Text('Schedule H', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: AppConstants.scheduleH1, child: Text('Schedule H1', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: AppConstants.scheduleX, child: Text('Schedule X', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
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

            // ListView Area
            Expanded(
              child: medicinesAsync.when(
                data: (_) {
                  if (filteredList.isEmpty) {
                    return Card(
                      elevation: 0,
                      color: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: theme.dividerColor),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: theme.disabledColor),
                            const SizedBox(height: 12),
                            const Text('No medicines found matching your filter criteria.'),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final med = item.medicine;
                      final isLowStock = item.totalQuantity <= med.reorderLevel;
                      final isOutOfStock = item.totalQuantity == 0;

                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isOutOfStock
                                ? Colors.red.withValues(alpha: 0.5)
                                : (isLowStock ? Colors.orange.withValues(alpha: 0.5) : theme.dividerColor),
                            width: (isOutOfStock || isLowStock) ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              // Icon & Brand Details
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: (isOutOfStock
                                        ? Colors.red
                                        : (isLowStock ? Colors.orange : theme.colorScheme.primary))
                                    .withValues(alpha: 0.12),
                                child: Icon(
                                  Icons.medication_rounded,
                                  size: 20,
                                  color: isOutOfStock
                                      ? Colors.red
                                      : (isLowStock ? Colors.orange : theme.colorScheme.primary),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Name & Metadata Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          med.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildScheduleBadge(med.scheduleFlag),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'GST ${med.gstRate}%',
                                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (med.genericName != null && med.genericName!.isNotEmpty) ...[
                                          Text(
                                            med.genericName!,
                                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                                          ),
                                          Text(' • ', style: TextStyle(color: theme.disabledColor)),
                                        ],
                                        Text(
                                          'Cat: ${med.category ?? "General"}',
                                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                        ),
                                        if (med.hsnCode != null && med.hsnCode!.isNotEmpty) ...[
                                          Text(' • ', style: TextStyle(color: theme.disabledColor)),
                                          Text(
                                            'HSN: ${med.hsnCode}',
                                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontFamily: 'monospace'),
                                          ),
                                        ],
                                        if (med.manufacturer != null && med.manufacturer!.isNotEmpty) ...[
                                          Text(' • ', style: TextStyle(color: theme.disabledColor)),
                                          Text(
                                            med.manufacturer!,
                                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // PROMINENT CLICKABLE STOCK BADGE
                              Tooltip(
                                message: 'Click to Quick Dispense / Reduce Stock (Buyed someone)',
                                child: InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => QuickDispenseDialog(item: item),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (isOutOfStock
                                              ? Colors.red
                                              : (isLowStock ? Colors.orange : Colors.green))
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (isOutOfStock
                                                ? Colors.red
                                                : (isLowStock ? Colors.orange : Colors.green))
                                            .withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${item.totalQuantity}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 17,
                                                    color: isOutOfStock
                                                        ? Colors.red
                                                        : (isLowStock ? Colors.orange : Colors.green),
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  med.unit,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isOutOfStock
                                                        ? Colors.red
                                                        : (isLowStock ? Colors.orange : Colors.green),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${item.batchCount} batch${item.batchCount == 1 ? '' : 'es'}',
                                              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.remove_circle_outline_rounded,
                                          size: 18,
                                          color: isOutOfStock
                                              ? Colors.red
                                              : (isLowStock ? Colors.orange : Colors.green),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Actions Buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Quick Sell / Dispense Button
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => QuickDispenseDialog(item: item),
                                      );
                                    },
                                    icon: const Icon(Icons.remove, size: 14),
                                    label: const Text('- Quick Sell', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Batches Button
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => BatchManagementDialog(medicine: med),
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code, size: 13),
                                    label: const Text('Batches', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Stock Adjust Button
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => StockAdjustmentDialog(medicine: med),
                                      );
                                    },
                                    icon: const Icon(Icons.tune, size: 13),
                                    label: const Text('Adjust', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Edit Button
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    tooltip: 'Edit Details',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => MedicineFormDialog(medicine: med),
                                      );
                                    },
                                  ),

                                  // Delete Button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    tooltip: 'Delete Product',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    onPressed: () => _confirmDelete(context, ref, med),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading inventory: $err')),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Medicine medicine) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete ${medicine.name}?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${medicine.name}"? '
          'This action cannot be undone and will remove all stock history and active batches.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final repo = ref.read(inventoryRepositoryProvider);
              await repo.deleteMedicine(medicine.id);
              ref.invalidate(medicinesWithStockProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${medicine.name}" deleted successfully.'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
