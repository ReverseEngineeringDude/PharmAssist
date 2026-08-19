import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/features/customers/presentation/credit_payment_dialog.dart';
import 'package:pharmassist/features/customers/presentation/customer_form_dialog.dart';
import 'package:pharmassist/features/customers/providers/customer_providers.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
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
    final customersAsync = ref.watch(customersStreamProvider);
    final filteredCustomers = ref.watch(filteredCustomersProvider);
    final searchQuery = ref.watch(customerSearchQueryProvider);
    final creditOnlyFilter = ref.watch(creditOnlyFilterProvider);

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Responsive Top Toolbar
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.people_alt_rounded, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customers & Credit Ledger',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Manage customer master accounts, credit balances, and payment settlements.',
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
                      customersAsync.when(
                        data: (customers) {
                          final totalCredit = customers.fold(0.0, (sum, c) => sum + c.creditBalance);
                          final debtCount = customers.where((c) => c.creditBalance > 0).length;

                          return Row(
                            children: [
                              _buildStatCard(
                                label: 'Total Customers',
                                count: customers.length.toString(),
                                color: theme.colorScheme.primary,
                                icon: Icons.people_outline,
                              ),
                              const SizedBox(width: 8),
                              _buildStatCard(
                                label: 'Total Credit Due',
                                count: '₹${totalCredit.toStringAsFixed(0)}',
                                color: totalCredit > 0 ? Colors.red : Colors.green,
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                              const SizedBox(width: 8),
                              _buildStatCard(
                                label: 'Accounts with Debt',
                                count: debtCount.toString(),
                                color: debtCount > 0 ? Colors.orange : Colors.grey,
                                icon: Icons.warning_amber_rounded,
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                      ),

                      const SizedBox(width: 16),

                      // Add Customer Button
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const CustomerFormDialog(),
                          );
                        },
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add Customer'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search Bar & Credit Only Toggle Bar
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
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          onChanged: (val) {
                            ref.read(customerSearchQueryProvider.notifier).state = val;
                          },
                          decoration: InputDecoration(
                            hintText: 'Search customer by Name or Phone Number...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      ref.read(customerSearchQueryProvider.notifier).state = '';
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Filter Switch
                    Row(
                      children: [
                        Switch(
                          value: creditOnlyFilter,
                          onChanged: (val) {
                            ref.read(creditOnlyFilterProvider.notifier).state = val;
                          },
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Show Credit Due Only',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Customer DataTable View
            Expanded(
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: customersAsync.when(
                  data: (_) {
                    if (filteredCustomers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off_outlined, size: 48, color: theme.disabledColor),
                            const SizedBox(height: 12),
                            const Text('No customer records found.'),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const CustomerFormDialog(),
                                );
                              },
                              icon: const Icon(Icons.person_add_rounded, size: 16),
                              label: const Text('Add First Customer'),
                            ),
                          ],
                        ),
                      );
                    }

                    return DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      minWidth: 800,
                      headingRowColor: WidgetStateProperty.all(theme.colorScheme.surface),
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      columns: const [
                        DataColumn2(label: Text('CUSTOMER NAME'), size: ColumnSize.L),
                        DataColumn2(label: Text('PHONE'), size: ColumnSize.M),
                        DataColumn2(label: Text('ADDRESS / CITY'), size: ColumnSize.L),
                        DataColumn2(label: Text('CREDIT BALANCE'), size: ColumnSize.M, numeric: true),
                        DataColumn2(label: Text('ACTIONS'), fixedWidth: 200),
                      ],
                      rows: filteredCustomers.map((c) {
                        final hasCredit = c.creditBalance > 0;

                        return DataRow2(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: (hasCredit ? Colors.red : theme.colorScheme.primary).withValues(alpha: 0.15),
                                    child: Text(
                                      c.name[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: hasCredit ? Colors.red : theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(c.phone ?? '—', style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(c.address ?? '—', style: const TextStyle(fontSize: 12)),
                            ),
                            DataCell(
                              Text(
                                '₹${c.creditBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: hasCredit ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                            DataCell(
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasCredit) ...[
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => CreditPaymentDialog(customer: c),
                                          );
                                        },
                                        icon: const Icon(Icons.payments, size: 14),
                                        label: const Text('Settle Due', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => CustomerFormDialog(customer: c),
                                        );
                                      },
                                      icon: const Icon(Icons.edit_outlined, size: 14),
                                      label: const Text('Edit', style: TextStyle(fontSize: 11)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
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
                  error: (err, _) => Center(child: Text('Error loading customers: $err')),
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
}
