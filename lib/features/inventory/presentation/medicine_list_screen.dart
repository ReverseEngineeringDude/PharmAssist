import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/repositories/inventory_repository.dart';
import 'package:pharmassist/features/inventory/presentation/batch_management_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/bulk_import_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/medicine_form_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/quick_dispense_dialog.dart';
import 'package:pharmassist/features/inventory/presentation/stock_adjustment_dialog.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';

class MedicineListScreen extends ConsumerStatefulWidget {
  const MedicineListScreen({super.key});

  @override
  ConsumerState<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends ConsumerState<MedicineListScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  int _currentPage = 1;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicinesAsync = ref.watch(medicinesWithStockProvider);
    final filteredList = ref.watch(filteredMedicinesProvider);
    final allBatches = ref.watch(allBatchesStreamProvider).value ?? [];

    final searchQuery = ref.watch(medicineSearchQueryProvider);
    final selectedSchedule = ref.watch(selectedScheduleFilterProvider);

    // Calculate Pagination
    final totalItems = filteredList.length;
    final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 99999);
    final effectivePage = _currentPage.clamp(1, totalPages);
    final startIndex = (effectivePage - 1) * _rowsPerPage;
    final endIndex = math.min(startIndex + _rowsPerPage, totalItems);
    final paginatedList = totalItems > 0 ? filteredList.sublist(startIndex, endIndex) : <MedicineWithStock>[];

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
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          onChanged: (val) {
                            ref.read(medicineSearchQueryProvider.notifier).state = val;
                            setState(() => _currentPage = 1);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by Brand Name, Salt, Manufacturer, HSN...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      ref.read(medicineSearchQueryProvider.notifier).state = '';
                                      setState(() => _currentPage = 1);
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
                              setState(() => _currentPage = 1);
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

            // PREMIUM DARK-MODE ERP TABLE CONTAINER
            Expanded(
              child: medicinesAsync.when(
                data: (_) {
                  if (filteredList.isEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A), // Dark Navy
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: const Color(0xFF64748B)),
                            const SizedBox(height: 12),
                            const Text(
                              'No medicines found matching your filter criteria.',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A), // Dark Navy Container
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // ERP TABLE HEADER
                        Container(
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B), // Dark Navy Header
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            border: Border(
                              bottom: BorderSide(color: Color(0xFF334155), width: 1.5),
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 1140,
                              child: Row(
                                children: [
                                  _buildHeaderCell('MEDICINE DETAILS', width: 450),
                                  _buildHeaderCell('CATEGORY', width: 150),
                                  _buildHeaderCell('STOCK / BATCH', width: 150),
                                  _buildHeaderCell('MRP', width: 120),
                                  _buildHeaderCell('EXPIRY', width: 130),
                                  _buildHeaderCell('STATUS', width: 140),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // DENSE TABLE ROWS (WITH HORIZONTAL & VERTICAL SCROLL)
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 1140,
                              child: ListView.builder(
                                itemCount: paginatedList.length,
                                itemBuilder: (context, index) {
                                  final item = paginatedList[index];
                                  final isAltRow = index % 2 == 1;
                                  final summary = _getBatchSummary(item, allBatches);

                                  return _buildTableRow(
                                    context: context,
                                    item: item,
                                    summary: summary,
                                    isAltRow: isAltRow,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // PAGINATION FOOTER
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                            border: Border(
                              top: BorderSide(color: Color(0xFF334155), width: 1.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Showing items range
                              Text(
                                totalItems > 0
                                    ? 'Showing ${startIndex + 1} to $endIndex of $totalItems items'
                                    : 'Showing 0 items',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),

                              const Spacer(),

                              // Rows per page dropdown selector
                              Row(
                                children: [
                                  const Text('Rows per page:', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                  const SizedBox(width: 8),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _rowsPerPage,
                                      dropdownColor: const Color(0xFF1E293B),
                                      isDense: true,
                                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                      items: const [
                                        DropdownMenuItem(value: 10, child: Text('10')),
                                        DropdownMenuItem(value: 25, child: Text('25')),
                                        DropdownMenuItem(value: 50, child: Text('50')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _rowsPerPage = val;
                                            _currentPage = 1;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 24),

                              // Page Navigation
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, size: 20),
                                    color: Colors.white,
                                    disabledColor: const Color(0xFF64748B),
                                    onPressed: effectivePage > 1
                                        ? () => setState(() => _currentPage = effectivePage - 1)
                                        : null,
                                  ),
                                  Text(
                                    'Page $effectivePage of $totalPages',
                                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, size: 20),
                                    color: Colors.white,
                                    disabledColor: const Color(0xFF64748B),
                                    onPressed: effectivePage < totalPages
                                        ? () => setState(() => _currentPage = effectivePage + 1)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading inventory: $err', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HEADER CELL HELPER
  Widget _buildHeaderCell(String title, {required double width, Alignment alignment = Alignment.centerLeft}) {
    return SizedBox(
      width: width,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF38BDF8), // Cyan Accent
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  // DENSE TABLE ROW WITH HOVER & RIGHT CLICK
  Widget _buildTableRow({
    required BuildContext context,
    required MedicineWithStock item,
    required Map<String, String> summary,
    required bool isAltRow,
  }) {
    final med = item.medicine;
    final isLowStock = item.totalQuantity <= med.reorderLevel;
    final isOutOfStock = item.totalQuantity == 0;

    bool isHovered = false;

    Offset clickPos = Offset.zero;

    return StatefulBuilder(
      builder: (context, setStateRow) {
        return MouseRegion(
          onEnter: (_) => setStateRow(() => isHovered = true),
          onExit: (_) => setStateRow(() => isHovered = false),
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => QuickDispenseDialog(item: item),
              );
            },
            onSecondaryTapDown: (details) => clickPos = details.globalPosition,
            onSecondaryTapUp: (details) => _showContextMenu(context, clickPos, item),
            onLongPressStart: (details) => _showContextMenu(context, details.globalPosition, item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 56,
              decoration: BoxDecoration(
                color: isHovered
                    ? const Color(0xFF1E293B) // Hover Cyan Navy
                    : (isAltRow ? const Color(0xFF0F172A) : const Color(0xFF131C31)),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // 1. MEDICINE DETAILS
                  SizedBox(
                    width: 450,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  med.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildScheduleBadge(med.scheduleFlag),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'GST ${med.gstRate}%',
                                  style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (med.genericName != null && med.genericName!.isNotEmpty) ...[
                                Flexible(
                                  child: Text(
                                    med.genericName!,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (med.hsnCode != null && med.hsnCode!.isNotEmpty) ...[
                                Text(
                                  'HSN: ${med.hsnCode}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                'Reorder: ${med.reorderLevel}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isLowStock ? Colors.orange : const Color(0xFF64748B),
                                  fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. CATEGORY
                  SizedBox(
                    width: 140,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text(
                            med.category ?? 'General',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. STOCK / BATCH
                  SizedBox(
                    width: 140,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${item.totalQuantity}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isOutOfStock
                                      ? Colors.red.shade400
                                      : (isLowStock ? Colors.orange.shade400 : const Color(0xFF10B981)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                med.unit,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isOutOfStock
                                      ? Colors.red.shade400
                                      : (isLowStock ? Colors.orange.shade400 : const Color(0xFF10B981)),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${item.batchCount} Active Batch${item.batchCount == 1 ? '' : 'es'}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. MRP
                  SizedBox(
                    width: 110,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          summary['mrp']!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 5. EXPIRY
                  SizedBox(
                    width: 120,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Text(
                              summary['expiry']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: item.hasExpired || item.hasNearExpiry ? FontWeight.bold : FontWeight.normal,
                                color: item.hasExpired
                                    ? Colors.red.shade400
                                    : (item.hasNearExpiry ? Colors.amber.shade400 : const Color(0xFFCBD5E1)),
                              ),
                            ),
                            if (item.hasExpired || item.hasNearExpiry) ...[
                              const SizedBox(width: 4),
                              Icon(
                                item.hasExpired ? Icons.error_outline : Icons.access_time_rounded,
                                size: 12,
                                color: item.hasExpired ? Colors.red.shade400 : Colors.amber.shade400,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 6. STATUS
                  SizedBox(
                    width: 140,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildStatusBadge(item),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // STATUS BADGE BUILDER
  Widget _buildStatusBadge(MedicineWithStock item) {
    final med = item.medicine;
    final isOutOfStock = item.totalQuantity == 0;
    final isLowStock = item.totalQuantity <= med.reorderLevel;

    Color color = const Color(0xFF10B981); // Emerald Green
    String text = 'In Stock';

    if (isOutOfStock) {
      color = const Color(0xFFEF4444); // Red
      text = 'Out of Stock';
    } else if (item.hasExpired) {
      color = const Color(0xFFEF4444); // Red
      text = 'Expired';
    } else if (item.hasNearExpiry) {
      color = const Color(0xFFF59E0B); // Amber
      text = 'Near Expiry';
    } else if (isLowStock) {
      color = const Color(0xFFF97316); // Orange
      text = 'Low Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // BATCH SUMMARY HELPER (MRP RANGE & EARLIEST EXPIRY)
  Map<String, String> _getBatchSummary(MedicineWithStock item, List<Batch> allBatches) {
    // 1. Combine batches attached to item or from allBatches stream
    final medBatches = item.batches.isNotEmpty
        ? item.batches
        : allBatches.where((b) => b.medicineId == item.medicine.id).toList();

    if (medBatches.isEmpty) {
      return {'mrp': 'N/A', 'expiry': 'N/A'};
    }

    // 2. Calculate MRP Range
    final mrpList = medBatches.map((b) => b.mrp).toList();
    String mrpStr = 'N/A';
    if (mrpList.isNotEmpty) {
      final minMrp = mrpList.reduce(math.min);
      final maxMrp = mrpList.reduce(math.max);
      if (minMrp == 0 && maxMrp == 0) {
        mrpStr = '₹0.00';
      } else if ((minMrp - maxMrp).abs() < 0.01) {
        mrpStr = '₹${minMrp.toStringAsFixed(2)}';
      } else {
        mrpStr = '₹${minMrp.toStringAsFixed(0)} - ₹${maxMrp.toStringAsFixed(0)}';
      }
    }

    // 3. Calculate Earliest Expiry
    final expDates = medBatches.map((b) => b.expiryDate).toList()..sort();
    String expStr = 'N/A';
    if (expDates.isNotEmpty) {
      final earliest = expDates.first;
      expStr = '${earliest.month.toString().padLeft(2, '0')}/${earliest.year}';
    }

    return {'mrp': mrpStr, 'expiry': expStr};
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset globalPosition, MedicineWithStock item) {
    final med = item.medicine;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'dispense',
          child: Row(
            children: [
              Icon(Icons.shopping_cart_checkout_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Quick Dispense / Sell', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'batch',
          child: Row(
            children: [
              const Icon(Icons.qr_code_2, size: 18, color: Color(0xFFA855F7)),
              const SizedBox(width: 10),
              Text('Manage Batches (${item.batchCount})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'adjust',
          child: Row(
            children: [
              Icon(Icons.tune, size: 18, color: Color(0xFF14B8A6)),
              SizedBox(width: 10),
              Text('Stock Adjustment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: Color(0xFFF59E0B)),
              SizedBox(width: 10),
              Text('Edit Medicine Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('Delete Medicine', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'dispense':
          showDialog(
            context: context,
            builder: (_) => QuickDispenseDialog(item: item),
          );
          break;
        case 'batch':
          showDialog(
            context: context,
            builder: (_) => BatchManagementDialog(medicine: med),
          );
          break;
        case 'adjust':
          showDialog(
            context: context,
            builder: (_) => StockAdjustmentDialog(medicine: med),
          );
          break;
        case 'edit':
          showDialog(
            context: context,
            builder: (_) => MedicineFormDialog(medicine: med),
          );
          break;
        case 'delete':
          _confirmDelete(context, ref, med);
          break;
      }
    });
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Medicine medicine) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete ${medicine.name}?', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${medicine.name}"? '
          'This action cannot be undone and will remove all stock history and active batches.',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
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
