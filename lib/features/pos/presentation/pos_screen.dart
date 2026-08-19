import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/features/auth/providers/auth_provider.dart';
import 'package:pharmassist/features/customers/presentation/customer_form_dialog.dart';
import 'package:pharmassist/features/customers/providers/customer_providers.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';
import 'package:pharmassist/features/pos/presentation/pos_invoice_dialog.dart';
import 'package:pharmassist/features/pos/providers/pos_providers.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final FocusNode _searchFocusNode = FocusNode();

  String _selectedCategory = 'All';

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
    _searchController.dispose();
    _discountController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleCheckout() async {
    final cartState = ref.read(posCartProvider);
    if (cartState.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty. Add medicines to proceed.')),
      );
      return;
    }

    if (cartState.paymentMode == 'credit' && cartState.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a registered customer for Credit sales!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authState = ref.read(authProvider);

    try {
      final saleId = await ref.read(posCartProvider.notifier).checkout(authState.userId ?? 1);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PosInvoiceDialog(saleId: saleId),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicinesAsync = ref.watch(medicinesWithStockProvider);
    final cartState = ref.watch(posCartProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    final searchQuery = cartState.searchQuery.toLowerCase();

    // Filter medicines
    final medicinesList = medicinesAsync.asData?.value ?? [];
    final filteredMedicines = medicinesList.where((item) {
      final med = item.medicine;
      final matchesSearch = searchQuery.isEmpty ||
          med.name.toLowerCase().contains(searchQuery) ||
          (med.genericName != null && med.genericName!.toLowerCase().contains(searchQuery)) ||
          (med.hsnCode != null && med.hsnCode!.contains(searchQuery));

      final matchesCategory = _selectedCategory == 'All' || med.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    // Unique Categories
    final categories = ['All', ...{...medicinesList.map((m) => m.medicine.category).whereType<String>()}];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyC, alt: true): () {
          ref.read(posCartProvider.notifier).clearCart();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =========================================================
                // LEFT PANEL: PRODUCT CATALOG & FAST SEARCH
                // =========================================================
                Expanded(
                  flex: 5,
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Input & Shortcut Tip
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Search medicine name, generic name, HSN (Ctrl + F)...',
                                    prefixIcon: const Icon(Icons.search_rounded),
                                    suffixIcon: searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 18),
                                            onPressed: () {
                                              _searchController.clear();
                                              ref.read(posCartProvider.notifier).setSearchQuery('');
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  onChanged: (val) {
                                    ref.read(posCartProvider.notifier).setSearchQuery(val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Category Chips Filter
                          SizedBox(
                            height: 34,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                final isSelected = _selectedCategory == cat;
                                return ChoiceChip(
                                  label: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedCategory = cat;
                                      });
                                    }
                                  },
                                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  labelStyle: TextStyle(
                                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Medicines Catalog List / Grid
                          Expanded(
                            child: medicinesAsync.when(
                              data: (_) {
                                if (filteredMedicines.isEmpty) {
                                  return const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text('No matching medicines found in catalog', style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  itemCount: filteredMedicines.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final item = filteredMedicines[index];
                                    final med = item.medicine;
                                    final totalStock = item.totalQuantity;
                                    final isOutOfStock = totalStock <= 0;

                                    return InkWell(
                                      onTap: isOutOfStock
                                          ? null
                                          : () async {
                                              try {
                                                await ref.read(posCartProvider.notifier).addMedicineToCart(item);
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                                                  );
                                                }
                                              }
                                            },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isOutOfStock
                                              ? Colors.grey.withValues(alpha: 0.05)
                                              : theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isOutOfStock
                                                ? Colors.red.withValues(alpha: 0.2)
                                                : theme.dividerColor.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Stock Count Badge Box
                                            Container(
                                              width: 60,
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isOutOfStock
                                                    ? Colors.red.withValues(alpha: 0.12)
                                                    : (totalStock <= med.reorderLevel
                                                        ? Colors.orange.withValues(alpha: 0.12)
                                                        : Colors.green.withValues(alpha: 0.12)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '$totalStock',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 16,
                                                      color: isOutOfStock
                                                          ? Colors.red
                                                          : (totalStock <= med.reorderLevel ? Colors.orange : Colors.green),
                                                    ),
                                                  ),
                                                  Text(
                                                    med.unit,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: isOutOfStock
                                                          ? Colors.red
                                                          : (totalStock <= med.reorderLevel ? Colors.orange : Colors.green),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Medicine Metadata
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    med.name,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: isOutOfStock ? Colors.grey : null,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Generic: ${med.genericName ?? '—'} • HSN: ${med.hsnCode ?? '—'} • GST: ${med.gstRate}%',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Add to Cart Button
                                            ElevatedButton.icon(
                                              onPressed: isOutOfStock
                                                  ? null
                                                  : () async {
                                                      try {
                                                        await ref.read(posCartProvider.notifier).addMedicineToCart(item);
                                                      } catch (e) {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                                                          );
                                                        }
                                                      }
                                                    },
                                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                                              label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: theme.colorScheme.primary,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
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
                  ),
                ),

                const SizedBox(width: 16),

                // =========================================================
                // RIGHT PANEL: POS BILLING TERMINAL & CART SUMMARY
                // =========================================================
                Expanded(
                  flex: 6,
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Customer Selection Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<Customer?>(
                                      value: cartState.selectedCustomer,
                                      isExpanded: true,
                                      hint: const Text('Walk-in Customer (Default)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      items: [
                                        const DropdownMenuItem<Customer?>(
                                          value: null,
                                          child: Text('Walk-in Customer (Cash Sale)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        ),
                                        ...customersAsync.asData?.value.map(
                                              (cust) => DropdownMenuItem<Customer?>(
                                                value: cust,
                                                child: Text(
                                                  '${cust.name} ${cust.phone != null ? "(${cust.phone})" : ""}${cust.creditBalance > 0 ? " [Due: ₹${cust.creditBalance.toStringAsFixed(2)}]" : ""}',
                                                  style: const TextStyle(fontSize: 13),
                                                ),
                                              ),
                                            ) ??
                                            [],
                                      ],
                                      onChanged: (cust) {
                                        ref.read(posCartProvider.notifier).setCustomer(cust);
                                      },
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.person_add_outlined, size: 20),
                                  tooltip: 'Add New Customer',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => const CustomerFormDialog(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Cart Data Table Area
                          Expanded(
                            child: cartState.cartItems.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shopping_cart_outlined, size: 54, color: theme.dividerColor),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Cart is empty',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const Text(
                                          'Click medicines from the catalog to add items for billing',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: cartState.cartItems.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = cartState.cartItems[index];

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          children: [
                                            // Medicine & Batch Info
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.medicine.name,
                                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          'Batch: ${item.batch.batchNo}',
                                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'MRP: ₹${item.rate.toStringAsFixed(2)}',
                                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Qty Modifier Controls
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                  onPressed: () {
                                                    try {
                                                      ref.read(posCartProvider.notifier).updateItemQty(index, item.qty - 1);
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                                                      );
                                                    }
                                                  },
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${item.qty}',
                                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.add_circle_outline, size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                  onPressed: () {
                                                    try {
                                                      ref.read(posCartProvider.notifier).updateItemQty(index, item.qty + 1);
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),

                                            // Total Item Price
                                            SizedBox(
                                              width: 75,
                                              child: Text(
                                                '₹${item.total.toStringAsFixed(2)}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                              ),
                                            ),

                                            // Remove Icon Button
                                            IconButton(
                                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                              onPressed: () {
                                                ref.read(posCartProvider.notifier).removeItem(index);
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          const Divider(height: 16),

                          // Financial Summary & Payment Options Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Items (${cartState.totalItemCount})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text('₹${cartState.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Estimated GST (CGST+SGST)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text('₹${cartState.totalTax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Discount Input Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Overall Discount (₹)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    SizedBox(
                                      width: 90,
                                      height: 32,
                                      child: TextField(
                                        controller: _discountController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          prefixText: '₹',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onChanged: (val) {
                                          final d = double.tryParse(val) ?? 0.0;
                                          ref.read(posCartProvider.notifier).setOverallDiscount(d);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 12),

                                // Grand Total Box
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                    Text(
                                      '₹${cartState.grandTotal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Payment Method Segmented Buttons
                          Row(
                            children: [
                              _buildPaymentChip('cash', 'Cash', Icons.payments_outlined, cartState.paymentMode, theme),
                              const SizedBox(width: 6),
                              _buildPaymentChip('card', 'Card', Icons.credit_card_outlined, cartState.paymentMode, theme),
                              const SizedBox(width: 6),
                              _buildPaymentChip('upi', 'UPI / QR', Icons.qr_code_2_outlined, cartState.paymentMode, theme),
                              const SizedBox(width: 6),
                              _buildPaymentChip('credit', 'Credit', Icons.account_balance_wallet_outlined, cartState.paymentMode, theme),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Checkout Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: cartState.isProcessing || cartState.cartItems.isEmpty
                                  ? null
                                  : _handleCheckout,
                              icon: cartState.isProcessing
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_circle_rounded, size: 20),
                              label: Text(
                                cartState.isProcessing ? 'Processing Checkout...' : 'COMPLETE SALE & PRINT RECEIPT',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String mode, String label, IconData icon, String currentMode, ThemeData theme) {
    final isSelected = mode == currentMode;
    final color = mode == 'credit' ? Colors.orange : (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface);

    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(posCartProvider.notifier).setPaymentMode(mode);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : theme.dividerColor.withValues(alpha: 0.6),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? color : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
