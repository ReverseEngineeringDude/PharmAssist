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
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =========================================================
                // LEFT PANEL: PRODUCT CATALOG & FAST SEARCH
                // =========================================================
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Input & Shortcut Tip
                        TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search medicine name, generic name, HSN (Ctrl + F)...',
                            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(posCartProvider.notifier).setSearchQuery('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onChanged: (val) {
                            ref.read(posCartProvider.notifier).setSearchQuery(val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Category Chips Filter
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = _selectedCategory == cat;
                              return ChoiceChip(
                                label: Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                selected: isSelected,
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedCategory = cat;
                                    });
                                  }
                                },
                                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                                side: BorderSide.none,
                                labelStyle: TextStyle(
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Medicines Catalog List
                        Expanded(
                          child: medicinesAsync.when(
                            data: (_) {
                              if (filteredMedicines.isEmpty) {
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
                                        child: Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No matching medicines found',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Try adjusting your search or category filter',
                                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: filteredMedicines.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? Colors.grey.withValues(alpha: 0.05)
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.02),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          // Stock Count Badge Box
                                          Container(
                                            width: 65,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isOutOfStock
                                                  ? Colors.red.withValues(alpha: 0.1)
                                                  : (totalStock <= med.reorderLevel
                                                      ? Colors.orange.withValues(alpha: 0.1)
                                                      : Colors.green.withValues(alpha: 0.1)),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '$totalStock',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 18,
                                                    color: isOutOfStock
                                                        ? Colors.red
                                                        : (totalStock <= med.reorderLevel ? Colors.orange.shade800 : Colors.green.shade700),
                                                  ),
                                                ),
                                                Text(
                                                  med.unit,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: isOutOfStock
                                                        ? Colors.red
                                                        : (totalStock <= med.reorderLevel ? Colors.orange.shade800 : Colors.green.shade700),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),

                                          // Medicine Metadata
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  med.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    color: isOutOfStock ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Generic: ${med.genericName ?? '—'} • HSN: ${med.hsnCode ?? '—'} • GST: ${med.gstRate}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),

                                          // Add to Cart Button
                                          FilledButton.tonalIcon(
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
                                            icon: const Icon(Icons.add_rounded, size: 18),
                                            label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

                const SizedBox(width: 24),

                // =========================================================
                // RIGHT PANEL: POS BILLING TERMINAL & CART SUMMARY
                // =========================================================
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Customer Selection Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_rounded, size: 22, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<Customer?>(
                                    value: cartState.selectedCustomer,
                                    isExpanded: true,
                                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                    hint: const Text('Walk-in Customer (Default)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                    items: [
                                      const DropdownMenuItem<Customer?>(
                                        value: null,
                                        child: Text('Walk-in Customer (Cash Sale)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                      ),
                                      ...customersAsync.asData?.value.map(
                                            (cust) => DropdownMenuItem<Customer?>(
                                              value: cust,
                                              child: Text(
                                                '${cust.name} ${cust.phone != null ? "(${cust.phone})" : ""}${cust.creditBalance > 0 ? " [Due: ₹${cust.creditBalance.toStringAsFixed(2)}]" : ""}',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                                icon: Icon(Icons.person_add_rounded, size: 22, color: theme.colorScheme.primary),
                                tooltip: 'Add New Customer',
                                style: IconButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                ),
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

                        const SizedBox(height: 20),

                        // Cart Data List
                        Expanded(
                          child: cartState.cartItems.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.shopping_cart_outlined, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Cart is empty',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Click medicines from the catalog to add items',
                                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: cartState.cartItems.length,
                                  separatorBuilder: (_, __) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = cartState.cartItems[index];

                                    return Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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
                                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'Batch: ${item.batch.batchNo}',
                                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'MRP: ₹${item.rate.toStringAsFixed(2)}',
                                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
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
                                              IconButton.filledTonal(
                                                icon: const Icon(Icons.remove_rounded, size: 16),
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                padding: EdgeInsets.zero,
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
                                                alignment: Alignment.center,
                                                width: 36,
                                                child: Text(
                                                  '${item.qty}',
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                                ),
                                              ),
                                              IconButton.filledTonal(
                                                icon: const Icon(Icons.add_rounded, size: 16),
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                padding: EdgeInsets.zero,
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
                                          const SizedBox(width: 16),

                                          // Total Item Price
                                          SizedBox(
                                            width: 80,
                                            child: Text(
                                              '₹${item.total.toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Remove Icon Button
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 18),
                                            color: Colors.red.shade700,
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.red.withValues(alpha: 0.1),
                                              padding: EdgeInsets.zero,
                                            ),
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

                        const SizedBox(height: 16),

                        // Financial Summary & Payment Options Box
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Items (${cartState.totalItemCount})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                  Text('₹${cartState.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Estimated GST (CGST+SGST)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                  Text('₹${cartState.totalTax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Discount Input Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Overall Discount (₹)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _discountController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                      decoration: InputDecoration(
                                        prefixText: '₹ ',
                                        prefixStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w800),
                                        isDense: true,
                                        filled: true,
                                        fillColor: theme.colorScheme.surface,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        final d = double.tryParse(val) ?? 0.0;
                                        ref.read(posCartProvider.notifier).setOverallDiscount(d);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
                              ),

                              // Grand Total Box
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                                  Text(
                                    '₹${cartState.grandTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 28,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Payment Method Segmented Buttons
                        Row(
                          children: [
                            _buildPaymentChip('cash', 'Cash', Icons.payments_rounded, cartState.paymentMode, theme),
                            const SizedBox(width: 8),
                            _buildPaymentChip('card', 'Card', Icons.credit_card_rounded, cartState.paymentMode, theme),
                            const SizedBox(width: 8),
                            _buildPaymentChip('upi', 'UPI / QR', Icons.qr_code_2_rounded, cartState.paymentMode, theme),
                            const SizedBox(width: 8),
                            _buildPaymentChip('credit', 'Credit', Icons.account_balance_wallet_rounded, cartState.paymentMode, theme),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Checkout Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: cartState.isProcessing || cartState.cartItems.isEmpty
                                ? null
                                : _handleCheckout,
                            icon: cartState.isProcessing
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : const Icon(Icons.check_circle_rounded, size: 24),
                            label: Text(
                              cartState.isProcessing ? 'Processing Checkout...' : 'COMPLETE SALE & PRINT RECEIPT',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
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
    final color = mode == 'credit' ? Colors.orange : theme.colorScheme.primary;

    return Expanded(
      child: Material(
        color: isSelected ? color.withValues(alpha: 0.15) : theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            ref.read(posCartProvider.notifier).setPaymentMode(mode);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: isSelected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}