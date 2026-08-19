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
    final invoicesAsync = ref.watch(purchaseInvoicesProvider);
    final filteredInvoices = ref.watch(filteredPurchaseInvoicesProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final searchQuery = ref.watch(purchaseSearchQueryProvider);

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Toolbar & Stat Cards
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.add_shopping_cart_rounded, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Purchase Entry & Inward Register',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Track stock purchases from wholesalers, batch details, and GST inward invoices.',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right Toolbar Controls & Stats
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      // Stat Cards
                      invoicesAsync.when(
                        data: (items) {
                          final totalValue = items.fold(0.0, (sum, i) => sum + i.invoice.totalAmount);
                          final totalSuppliers = suppliersAsync.value?.length ?? 0;
                          final totalBalanceDue = suppliersAsync.value?.fold(0.0, (sum, s) => sum + s.balanceDue) ?? 0.0;

                          return Row(
                            children: [
                              _buildStatCard(
                                label: 'Total Invoices',
                                count: items.length.toString(),
                                color: theme.colorScheme.primary,
                                icon: Icons.receipt_long,
                              ),
                              const SizedBox(width: 8),
                              _buildStatCard(
                                label: 'Total Purchase',
                                count: '₹${totalValue.toStringAsFixed(0)}',
                                color: Colors.green,
                                icon: Icons.account_balance_wallet,
                              ),
                              const SizedBox(width: 8),
                              _buildStatCard(
                                label: 'Distributors',
                                count: totalSuppliers.toString(),
                                color: Colors.purple,
                                icon: Icons.local_shipping,
                              ),
                              const SizedBox(width: 8),
                              _buildStatCard(
                                label: 'Balance Due',
                                count: '₹${totalBalanceDue.toStringAsFixed(0)}',
                                color: totalBalanceDue > 0 ? Colors.red : Colors.grey,
                                icon: Icons.error_outline,
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                      ),

                      const SizedBox(width: 12),

                      // Distributors Button
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const SupplierManagementDialog(),
                          );
                        },
                        icon: const Icon(Icons.local_shipping_outlined, size: 18),
                        label: const Text('Distributors'),
                      ),

                      const SizedBox(width: 8),

                      // New Purchase Entry Button
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const PurchaseEntryDialog(),
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Purchase Entry'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search Bar
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
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          onChanged: (val) {
                            ref.read(purchaseSearchQueryProvider.notifier).state = val;
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by Purchase Invoice No or Distributor / Supplier Name...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      ref.read(purchaseSearchQueryProvider.notifier).state = '';
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Purchases DataTable View
            Expanded(
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: invoicesAsync.when(
                  data: (_) {
                    if (filteredInvoices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_rounded, size: 48, color: theme.disabledColor),
                            const SizedBox(height: 12),
                            const Text('No purchase invoices found.'),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const PurchaseEntryDialog(),
                                );
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create First Purchase Entry'),
                            ),
                          ],
                        ),
                      );
                    }

                    return DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      minWidth: 850,
                      headingRowColor: WidgetStateProperty.all(theme.colorScheme.surface),
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      columns: const [
                        DataColumn2(label: Text('DATE'), size: ColumnSize.S),
                        DataColumn2(label: Text('INVOICE NO'), size: ColumnSize.M),
                        DataColumn2(label: Text('DISTRIBUTOR / SUPPLIER'), size: ColumnSize.L),
                        DataColumn2(label: Text('ITEMS COUNT'), size: ColumnSize.S, numeric: true),
                        DataColumn2(label: Text('TOTAL AMOUNT'), size: ColumnSize.M, numeric: true),
                        DataColumn2(label: Text('ACTIONS'), fixedWidth: 150),
                      ],
                      rows: filteredInvoices.map((item) {
                        final inv = item.invoice;
                        final sup = item.supplier;

                        return DataRow2(
                          cells: [
                            DataCell(
                              Text(dateFormat.format(inv.date), style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(inv.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                            ),
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (sup.gstin != null)
                                    Text('GSTIN: ${sup.gstin}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                ],
                              ),
                            ),
                            DataCell(
                              Text('${item.items.length} items', style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(
                                '₹${inv.totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
                              ),
                            ),
                            DataCell(
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => PurchaseDetailsDialog(invoiceDetails: item),
                                        );
                                      },
                                      icon: const Icon(Icons.visibility_outlined, size: 14),
                                      label: const Text('View', style: TextStyle(fontSize: 11)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      tooltip: 'Delete Purchase Invoice',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () => _deleteInvoice(context, ref, item),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Delete Purchase Invoice?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete Purchase Invoice #${item.invoice.invoiceNo} from ${item.supplier.name}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action will remove the inward purchase record and its associated batch stock items if not yet sold.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete Invoice'),
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
            SnackBar(content: Text('Purchase Invoice #${item.invoice.invoiceNo} deleted successfully.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete purchase invoice.')),
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
}
