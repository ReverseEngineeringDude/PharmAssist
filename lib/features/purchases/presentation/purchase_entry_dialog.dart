import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/repositories/inventory_repository.dart';
import 'package:pharmassist/data/repositories/purchase_repository.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';
import 'package:pharmassist/features/purchases/presentation/supplier_management_dialog.dart';
import 'package:pharmassist/features/purchases/providers/purchase_providers.dart';

class PurchaseEntryDialog extends ConsumerStatefulWidget {
  const PurchaseEntryDialog({super.key});

  @override
  ConsumerState<PurchaseEntryDialog> createState() => _PurchaseEntryDialogState();
}

class _PurchaseEntryDialogState extends ConsumerState<PurchaseEntryDialog> {
  final _invoiceNoController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  Supplier? _selectedSupplier;

  // Current Item Form State
  MedicineWithStock? _selectedMedicine;
  final _batchNoController = TextEditingController();
  DateTime? _mfgDate;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  final _purchasePriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _quantityController = TextEditingController();

  final List<PurchaseItemInput> _addedItems = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _batchNoController.dispose();
    _purchasePriceController.dispose();
    _mrpController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _addItemToInvoice() {
    if (_selectedMedicine == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a medicine.')));
      return;
    }
    final batchNo = _batchNoController.text.trim();
    if (batchNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter batch number.')));
      return;
    }
    final purPrice = double.tryParse(_purchasePriceController.text.trim());
    if (purPrice == null || purPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid purchase price.')));
      return;
    }
    final mrp = double.tryParse(_mrpController.text.trim());
    if (mrp == null || mrp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid MRP.')));
      return;
    }
    final qty = int.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid quantity.')));
      return;
    }

    setState(() {
      _addedItems.add(
        PurchaseItemInput(
          medicineId: _selectedMedicine!.medicine.id,
          batchNo: batchNo,
          mfgDate: _mfgDate,
          expiryDate: _expiryDate,
          purchasePrice: purPrice,
          mrp: mrp,
          quantity: qty,
        ),
      );

      // Reset item inputs
      _batchNoController.clear();
      _purchasePriceController.clear();
      _mrpController.clear();
      _quantityController.clear();
      _selectedMedicine = null;
    });
  }

  double get _totalInvoiceAmount {
    return _addedItems.fold(0.0, (sum, item) => sum + (item.purchasePrice * item.quantity));
  }

  Future<void> _savePurchaseInvoice() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a distributor/supplier.')));
      return;
    }
    final invNo = _invoiceNoController.text.trim();
    if (invNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter invoice number.')));
      return;
    }
    if (_addedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one line item.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(purchaseRepositoryProvider);
      await repo.createPurchaseInvoice(
        supplierId: _selectedSupplier!.id,
        invoiceNo: invNo,
        invoiceDate: _invoiceDate,
        items: _addedItems,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase Invoice #$invNo saved successfully! Stock updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving purchase invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(suppliersProvider);
    final medicinesAsync = ref.watch(medicinesWithStockProvider);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 950,
        height: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.add_shopping_cart_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Purchase Inward Entry',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Enter stock invoice from distributor to register batches and update stock.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Top Supplier & Invoice Metadata Row
            Row(
              children: [
                // Supplier Select
                Expanded(
                  flex: 3,
                  child: suppliersAsync.when(
                    data: (suppliers) {
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Supplier>(
                              initialValue: _selectedSupplier,
                              decoration: const InputDecoration(labelText: 'Distributor / Supplier *'),
                              isExpanded: true,
                              items: suppliers.map((sup) {
                                return DropdownMenuItem<Supplier>(
                                  value: sup,
                                  child: Text(sup.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedSupplier = val),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_business_rounded),
                            tooltip: 'Add Supplier',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const SupplierManagementDialog(),
                              );
                            },
                          ),
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Error loading suppliers: $err'),
                  ),
                ),

                const SizedBox(width: 12),

                // Invoice Number
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _invoiceNoController,
                    decoration: const InputDecoration(
                      labelText: 'Purchase Invoice No *',
                      hintText: 'e.g. INV-2026-9812',
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Invoice Date Picker
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _invoiceDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Invoice Date *'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dateFormat.format(_invoiceDate)),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Item Input Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Line Item to Invoice:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Select Medicine
                      Expanded(
                        flex: 3,
                        child: medicinesAsync.when(
                          data: (medicines) {
                            return DropdownButtonFormField<MedicineWithStock>(
                              initialValue: _selectedMedicine,
                              decoration: const InputDecoration(labelText: 'Select Medicine *'),
                              isExpanded: true,
                              items: medicines.map((m) {
                                return DropdownMenuItem<MedicineWithStock>(
                                  value: m,
                                  child: Text(m.medicine.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedMedicine = val;
                                });
                              },
                            );
                          },
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Batch No
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _batchNoController,
                          decoration: const InputDecoration(labelText: 'Batch No *'),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Expiry Date Picker
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expiryDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) setState(() => _expiryDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Expiry Date *'),
                            child: Text(dateFormat.format(_expiryDate), style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Pur Price
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _purchasePriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          decoration: const InputDecoration(labelText: 'Pur. Price (₹) *'),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // MRP
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _mrpController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          decoration: const InputDecoration(labelText: 'MRP (₹) *'),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Qty
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Quantity *'),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Add Item Button
                      ElevatedButton.icon(
                        onPressed: _addItemToInvoice,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Added Items List Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: _addedItems.isEmpty
                    ? const Center(
                        child: Text('No line items added yet. Fill form above and click "Add Item".'),
                      )
                    : ListView.separated(
                        itemCount: _addedItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _addedItems[index];
                          final medList = medicinesAsync.value ?? [];
                          final med = medList.firstWhere((m) => m.medicine.id == item.medicineId).medicine;
                          final itemTotal = item.purchasePrice * item.quantity;

                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                              child: Text('${index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                            ),
                            title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(
                              'Batch: ${item.batchNo} | Exp: ${dateFormat.format(item.expiryDate)} | MRP: ₹${item.mrp.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${item.quantity} ${med.unit} × ₹${item.purchasePrice.toStringAsFixed(2)} = ', style: const TextStyle(fontSize: 12)),
                                Text('₹${itemTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _addedItems.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Footer Total & Actions
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Added Items: ${_addedItems.length}', style: const TextStyle(fontSize: 12)),
                    Text(
                      'Total Invoice Amount: ₹${_totalInvoiceAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: (_addedItems.isEmpty || _isSaving) ? null : _savePurchaseInvoice,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Save & Post Purchase Invoice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
