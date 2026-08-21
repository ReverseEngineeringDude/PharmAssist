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
    final borderColor = Colors.grey.withValues(alpha: 0.3);
    
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP HEADER & ACTION BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.inventory_2_rounded, color: theme.colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory & Medicine Master',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Batch-level stock tracking & FEFO monitoring',
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Action Buttons
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const BulkImportDialog(),
                        );
                      },
                      icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: const Text('Bulk Import (AI)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purple.withValues(alpha: 0.1),
                        foregroundColor: Colors.purple.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const MedicineFormDialog(),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Medicine', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. SEARCH & FILTER CONTROL BAR
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Search Input
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        onChanged: (val) {
                          ref.read(medicineSearchQueryProvider.notifier).state = val;
                          setState(() => _currentPage = 1);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by Brand Name, Salt, Manufacturer, HSN...',
                          hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    ref.read(medicineSearchQueryProvider.notifier).state = '';
                                    setState(() => _currentPage = 1);
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Schedule Flag Filter Dropdown
                  Container(
                    height: 40,
                    width: 200,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedSchedule,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        hint: const Text('Schedule: All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Schedules', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: AppConstants.scheduleNone, child: Text('OTC / None', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: AppConstants.scheduleH, child: Text('Schedule H', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: AppConstants.scheduleH1, child: Text('Schedule H1', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: AppConstants.scheduleX, child: Text('Schedule X', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) {
                          ref.read(selectedScheduleFilterProvider.notifier).state = val;
                          setState(() => _currentPage = 1);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. STAT CARDS ROW (Moved below search as requested)
            medicinesAsync.when(
              data: (items) {
                final lowStockCount = items.where((i) => i.totalQuantity <= i.medicine.reorderLevel).length;
                final nearExpiryCount = items.where((i) => i.hasNearExpiry).length;
                final expiredCount = items.where((i) => i.hasExpired).length;

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        label: 'Total Items Catalog',
                        count: items.length.toString(),
                        color: theme.colorScheme.primary,
                        icon: Icons.category_rounded,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'Low Stock Alerts',
                        count: lowStockCount.toString(),
                        color: lowStockCount > 0 ? Colors.orange : Colors.grey,
                        icon: Icons.warning_amber_rounded,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'Near Expiry (<=90d)',
                        count: nearExpiryCount.toString(),
                        color: nearExpiryCount > 0 ? Colors.amber.shade700 : Colors.grey,
                        icon: Icons.access_time_filled_rounded,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'Expired Stock',
                        count: expiredCount.toString(),
                        color: expiredCount > 0 ? Colors.red : Colors.grey,
                        icon: Icons.error_rounded,
                        theme: theme,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 60, child: Center(child: LinearProgressIndicator())),
              error: (_, __) => const SizedBox(),
            ),

            const SizedBox(height: 20),

            // 4. USER FRIENDLY DATA TABLE WITH COLUMN BORDERS
            Expanded(
              child: medicinesAsync.when(
                data: (_) {
                  if (filteredList.isEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.search_off_rounded, size: 40, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No medicines found matching your criteria.',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // TABLE HEADER
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                            border: Border(bottom: BorderSide(color: borderColor)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(), // Match row scrolling
                            child: SizedBox(
                              width: 1080, // Total fixed width of all columns
                              child: Row(
                                children: [
                                  _buildHeaderCell('MEDICINE DETAILS', width: 400, borderColor: borderColor, theme: theme),
                                  _buildHeaderCell('CATEGORY', width: 140, borderColor: borderColor, theme: theme),
                                  _buildHeaderCell('STOCK / BATCH', width: 140, borderColor: borderColor, theme: theme),
                                  _buildHeaderCell('MRP RANGE', width: 130, borderColor: borderColor, theme: theme),
                                  _buildHeaderCell('EXPIRY', width: 130, borderColor: borderColor, theme: theme),
                                  _buildHeaderCell('STATUS', width: 140, borderColor: borderColor, theme: theme, isLast: true),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // TABLE BODY ROWS
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 1080,
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
                                    theme: theme,
                                    borderColor: borderColor,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // PAGINATION FOOTER
                        Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                            border: Border(top: BorderSide(color: borderColor)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                totalItems > 0
                                    ? 'Showing ${startIndex + 1} to $endIndex of $totalItems entries'
                                    : 'Showing 0 entries',
                                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Text('Rows per page:', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: borderColor),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _rowsPerPage,
                                        isDense: true,
                                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
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
                                  ),
                                ],
                              ),
                              const SizedBox(width: 24),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                                    color: theme.colorScheme.primary,
                                    disabledColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                                    onPressed: effectivePage > 1
                                        ? () => setState(() => _currentPage = effectivePage - 1)
                                        : null,
                                  ),
                                  Text(
                                    'Page $effectivePage of $totalPages',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                                    color: theme.colorScheme.primary,
                                    disabledColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
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

  // --- WIDGET BUILDERS ---

  Widget _buildStatCard({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(count, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {required double width, required Color borderColor, required ThemeData theme, bool isLast = false}) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(right: BorderSide(color: borderColor)),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableRow({
    required BuildContext context,
    required MedicineWithStock item,
    required Map<String, String> summary,
    required bool isAltRow,
    required ThemeData theme,
    required Color borderColor,
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
              height: 64,
              decoration: BoxDecoration(
                color: isHovered
                    ? theme.colorScheme.primary.withValues(alpha: 0.05)
                    : (isAltRow ? theme.colorScheme.surface : theme.colorScheme.onSurface.withValues(alpha: 0.02)),
                border: Border(
                  bottom: BorderSide(color: borderColor),
                ),
              ),
              child: Row(
                children: [
                  // 1. MEDICINE DETAILS (Width 400)
                  Container(
                    width: 400,
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                med.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildScheduleBadge(med.scheduleFlag),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'GST ${med.gstRate}%',
                                style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.8), fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (med.genericName != null && med.genericName!.isNotEmpty) ...[
                              Flexible(
                                child: Text(
                                  med.genericName!,
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(' • ', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                            ],
                            if (med.hsnCode != null && med.hsnCode!.isNotEmpty) ...[
                              Text(
                                'HSN: ${med.hsnCode}',
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                              ),
                              Text(' • ', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                            ],
                            Text(
                              'Reorder: ${med.reorderLevel}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isLowStock ? Colors.orange.shade700 : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. CATEGORY (Width 140)
                  Container(
                    width: 140,
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        med.category ?? 'General',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // 3. STOCK / BATCH (Width 140)
                  Container(
                    width: 140,
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${item.totalQuantity}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isOutOfStock
                                    ? Colors.red
                                    : (isLowStock ? Colors.orange.shade700 : const Color(0xFF10B981)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              med.unit,
                              style: TextStyle(
                                fontSize: 11,
                                color: isOutOfStock
                                    ? Colors.red
                                    : (isLowStock ? Colors.orange.shade700 : const Color(0xFF10B981)),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.batchCount} Active Batch${item.batchCount == 1 ? '' : 'es'}',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),

                  // 4. MRP RANGE (Width 130)
                  Container(
                    width: 130,
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
                    child: Text(
                      summary['mrp']!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),

                  // 5. EXPIRY (Width 130)
                  Container(
                    width: 130,
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor))),
                    child: Row(
                      children: [
                        Text(
                          summary['expiry']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item.hasExpired || item.hasNearExpiry ? FontWeight.bold : FontWeight.w500,
                            color: item.hasExpired
                                ? Colors.red
                                : (item.hasNearExpiry ? Colors.amber.shade700 : theme.colorScheme.onSurface),
                          ),
                        ),
                        if (item.hasExpired || item.hasNearExpiry) ...[
                          const SizedBox(width: 6),
                          Icon(
                            item.hasExpired ? Icons.error_rounded : Icons.access_time_filled_rounded,
                            size: 14,
                            color: item.hasExpired ? Colors.red : Colors.amber.shade700,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 6. STATUS (Width 140)
                  Container(
                    width: 140,
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: _buildStatusBadge(item),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
      color = Colors.amber.shade700; // Amber
      text = 'Near Expiry';
    } else if (isLowStock) {
      color = const Color(0xFFF97316); // Orange
      text = 'Low Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBadge(String flag) {
    Color color = Colors.grey.shade600;
    String text = 'OTC';

    switch (flag) {
      case AppConstants.scheduleH:
        color = Colors.orange.shade700;
        text = 'Sched H';
        break;
      case AppConstants.scheduleH1:
        color = Colors.red.shade700;
        text = 'Sched H1';
        break;
      case AppConstants.scheduleX:
        color = Colors.purple.shade700;
        text = 'Sched X';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Map<String, String> _getBatchSummary(MedicineWithStock item, List<Batch> allBatches) {
    final medBatches = item.batches.isNotEmpty
        ? item.batches
        : allBatches.where((b) => b.medicineId == item.medicine.id).toList();

    if (medBatches.isEmpty) {
      return {'mrp': 'N/A', 'expiry': 'N/A'};
    }

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

    final expDates = medBatches.map((b) => b.expiryDate).toList()..sort();
    String expStr = 'N/A';
    if (expDates.isNotEmpty) {
      final earliest = expDates.first;
      expStr = '${earliest.month.toString().padLeft(2, '0')}/${earliest.year}';
    }

    return {'mrp': mrpStr, 'expiry': expStr};
  }

  void _showContextMenu(BuildContext context, Offset globalPosition, MedicineWithStock item) {
    final med = item.medicine;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final theme = Theme.of(context);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'dispense',
          child: Row(
            children: [
              Icon(Icons.shopping_cart_checkout_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text('Quick Dispense / Sell', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'batch',
          child: Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 18, color: Colors.purple),
              const SizedBox(width: 12),
              Text('Manage Batches (${item.batchCount})', style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'adjust',
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: Colors.teal),
              const SizedBox(width: 12),
              Text('Stock Adjustment', style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Text('Edit Medicine Details', style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              SizedBox(width: 12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    backgroundColor: Colors.red,
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