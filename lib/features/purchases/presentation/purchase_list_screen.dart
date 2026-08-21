import 'dart:math' as math;
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/data/repositories/purchase_repository.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';
import 'package:pharmassist/features/purchases/presentation/purchase_details_dialog.dart';
import 'package:pharmassist/features/purchases/presentation/purchase_entry_dialog.dart';
import 'package:pharmassist/features/purchases/presentation/supplier_management_dialog.dart';
import 'package:pharmassist/features/purchases/providers/purchase_providers.dart';

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  
  // Pagination State
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
    
    final invoicesAsync = ref.watch(purchaseInvoicesProvider);
    final filteredInvoices = ref.watch(filteredPurchaseInvoicesProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final searchQuery = ref.watch(purchaseSearchQueryProvider);

    final dateFormat = DateFormat('dd/MM/yyyy');

    // Calculate Pagination
    final totalItems = filteredInvoices.length;
    final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 99999);
    final effectivePage = _currentPage.clamp(1, totalPages);
    final startIndex = (effectivePage - 1) * _rowsPerPage;
    final endIndex = math.min(startIndex + _rowsPerPage, totalItems);
    final paginatedList = totalItems > 0 ? filteredInvoices.sublist(startIndex, endIndex) : <PurchaseInvoiceWithDetails>[];

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
                      child: Icon(Icons.add_shopping_cart_rounded, color: theme.colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchases',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage inward supplies and distributor invoices',
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
                          builder: (_) => const SupplierManagementDialog(),
                        );
                      },
                      icon: const Icon(Icons.local_shipping_rounded, size: 18),
                      label: const Text('Distributors', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const PurchaseEntryDialog(),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New Purchase Entry', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. SEARCH BAR
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                focusNode: _searchFocusNode,
                autofocus: true,
                onChanged: (val) {
                  ref.read(purchaseSearchQueryProvider.notifier).state = val;
                  setState(() => _currentPage = 1); // Reset to page 1 on search
                },
                decoration: InputDecoration(
                  hintText: 'Search invoice or distributor...',
                  hintStyle: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            ref.read(purchaseSearchQueryProvider.notifier).state = '';
                            setState(() => _currentPage = 1);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.02),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. STAT CARDS ROW
            invoicesAsync.when(
              data: (items) {
                final totalValue = items.fold(0.0, (sum, i) => sum + i.invoice.totalAmount);
                final totalSuppliers = suppliersAsync.value?.length ?? 0;
                final totalBalanceDue = suppliersAsync.value?.fold(0.0, (sum, s) => sum + s.balanceDue) ?? 0.0;

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        label: 'Total Invoices',
                        count: items.length.toString(),
                        color: theme.colorScheme.primary,
                        icon: Icons.receipt_long_rounded,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'Total Purchase Value',
                        count: '₹${totalValue.toStringAsFixed(0)}',
                        color: Colors.green,
                        icon: Icons.account_balance_wallet_rounded,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'Active Distributors',
                        count: totalSuppliers.toString(),
                        color: Colors.purple,
                        icon: Icons.local_shipping_rounded,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'Outstanding Balance',
                        count: '₹${totalBalanceDue.toStringAsFixed(0)}',
                        color: totalBalanceDue > 0 ? Colors.red : Colors.grey,
                        icon: Icons.error_rounded,
                        theme: theme,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 72, child: Center(child: LinearProgressIndicator())),
              error: (_, __) => const SizedBox(),
            ),

            const SizedBox(height: 20),

            // 4. DATATABLE VIEW WITH COLUMN BORDERS
            Expanded(
              child: Container(
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
                child: invoicesAsync.when(
                  data: (_) {
                    if (filteredInvoices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.inventory_2_outlined, size: 40, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No purchase invoices found.',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const PurchaseEntryDialog(),
                                );
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Create First Purchase Entry'),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: DataTable2(
                            columnSpacing: 16,
                            horizontalMargin: 16,
                            minWidth: 850,
                            dividerThickness: 1,
                            // Adding column borders using TableBorder
                            border: TableBorder(
                              verticalInside: BorderSide(color: borderColor),
                              bottom: BorderSide(color: borderColor),
                            ),
                            // Styling header for both light/dark modes
                            headingRowColor: WidgetStateProperty.all(theme.colorScheme.onSurface.withValues(alpha: 0.03)),
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.w800, 
                              fontSize: 12, 
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                            columns: const [
                              DataColumn2(label: Text('DATE'), size: ColumnSize.S),
                              DataColumn2(label: Text('INVOICE NO'), size: ColumnSize.M),
                              DataColumn2(label: Text('DISTRIBUTOR / SUPPLIER'), size: ColumnSize.L),
                              DataColumn2(label: Text('ITEMS'), size: ColumnSize.S, numeric: true),
                              DataColumn2(label: Text('TOTAL AMOUNT'), size: ColumnSize.M, numeric: true),
                              DataColumn2(label: Text('ACTIONS'), fixedWidth: 120),
                            ],
                            rows: paginatedList.map((item) {
                              final inv = item.invoice;
                              final sup = item.supplier;

                              return DataRow2(
                                cells: [
                                  DataCell(
                                    Text(dateFormat.format(inv.date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ),
                                  DataCell(
                                    Text(inv.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  ),
                                  DataCell(
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(sup.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                        if (sup.gstin != null)
                                          Text('GSTIN: ${sup.gstin}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text('${item.items.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹${inv.totalAmount.toStringAsFixed(2)}',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: theme.colorScheme.primary),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton.filledTonal(
                                          icon: const Icon(Icons.visibility_rounded, size: 16),
                                          tooltip: 'View Details',
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => PurchaseDetailsDialog(invoiceDetails: item),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                          tooltip: 'Delete Invoice',
                                          color: Colors.red,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          padding: EdgeInsets.zero,
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                                          ),
                                          onPressed: () => _deleteInvoice(context, ref, item),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                        // 5. PAGINATION FOOTER (Only shows if there are multiple pages)
                        if (totalPages > 1)
                          Container(
                            height: 54,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Showing ${startIndex + 1} to $endIndex of $totalItems entries',
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
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading purchases: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteInvoice(BuildContext context, WidgetRef ref, PurchaseInvoiceWithDetails item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Invoice?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete Invoice #${item.invoice.invoiceNo} from ${item.supplier.name}?',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action will permanently remove the inward purchase record and its associated batch stock items if they are not yet sold.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(purchaseRepositoryProvider);
      final success = await repo.deletePurchaseInvoice(item.invoice.id);
      if (context.mounted) {
        if (success) {
          ref.invalidate(purchaseInvoicesProvider);
          ref.invalidate(medicinesWithStockProvider);
          ref.invalidate(allBatchesStreamProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase Invoice #${item.invoice.invoiceNo} deleted successfully.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete purchase invoice.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

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
}