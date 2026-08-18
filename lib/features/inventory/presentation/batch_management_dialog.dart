import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';

class BatchManagementDialog extends ConsumerStatefulWidget {
  final Medicine medicine;

  const BatchManagementDialog({super.key, required this.medicine});

  @override
  ConsumerState<BatchManagementDialog> createState() => _BatchManagementDialogState();
}

class _BatchManagementDialogState extends ConsumerState<BatchManagementDialog> {
  final _formKey = GlobalKey<FormState>();

  final _batchNoController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _qtyController = TextEditingController();

  DateTime? _mfgDate;
  DateTime? _expiryDate;
  bool _isAddingBatch = false;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _batchNoController.dispose();
    _purchasePriceController.dispose();
    _mrpController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isExpiry) async {
    final now = DateTime.now();
    final initialDate = isExpiry ? now.add(const Duration(days: 365)) : now.subtract(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _mfgDate = picked;
        }
      });
    }
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;

    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Expiry Date for the batch.')),
      );
      return;
    }

    setState(() => _isAddingBatch = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
      final mrp = double.tryParse(_mrpController.text) ?? 0.0;
      final qty = int.tryParse(_qtyController.text) ?? 0;

      await repo.addBatch(
        BatchesCompanion.insert(
          medicineId: widget.medicine.id,
          batchNo: _batchNoController.text.trim(),
          mfgDate: drift.Value(_mfgDate),
          expiryDate: _expiryDate!,
          purchasePrice: purchasePrice,
          mrp: mrp,
          quantity: drift.Value(qty),
        ),
      );

      _batchNoController.clear();
      _purchasePriceController.clear();
      _mrpController.clear();
      _qtyController.clear();
      setState(() {
        _mfgDate = null;
        _expiryDate = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New Batch added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding batch: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingBatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batchesAsync = ref.watch(batchesForMedicineProvider(widget.medicine.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 840,
        height: 620,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.qr_code_2, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batch Management — ${widget.medicine.name}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Category: ${widget.medicine.category ?? 'General'} | Unit: ${widget.medicine.unit} | GST: ${widget.medicine.gstRate}%',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
            const Divider(height: 24),

            // Content Area Split: Left = Existing Batches List, Right = Add New Batch Form
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Pane: Batches List
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXISTING BATCHES (Sorted by Expiry - FEFO)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: batchesAsync.when(
                            data: (batches) {
                              if (batches.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inventory_outlined, size: 40, color: theme.disabledColor),
                                      const SizedBox(height: 8),
                                      const Text('No batches registered for this medicine.'),
                                    ],
                                  ),
                                );
                              }

                              final now = DateTime.now();
                              final nearExpiryCutoff = now.add(const Duration(days: 90));

                              return ListView.separated(
                                itemCount: batches.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final batch = batches[index];
                                  final isExpired = batch.expiryDate.isBefore(now);
                                  final isNearExpiry = !isExpired && batch.expiryDate.isBefore(nearExpiryCutoff);

                                  Color statusColor = Colors.green;
                                  String statusText = 'GOOD';
                                  if (isExpired) {
                                    statusColor = Colors.red;
                                    statusText = 'EXPIRED';
                                  } else if (isNearExpiry) {
                                    statusColor = Colors.orange;
                                    statusText = 'NEAR EXPIRY';
                                  }

                                  return Card(
                                    elevation: 0,
                                    color: theme.colorScheme.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Batch: ${batch.batchNo}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        statusText,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: statusColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Expiry: ${_dateFormat.format(batch.expiryDate)} ${batch.mfgDate != null ? '| Mfg: ${_dateFormat.format(batch.mfgDate!)}' : ''}',
                                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Qty: ${batch.quantity}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              Text(
                                                'MRP: ₹${batch.mrp.toStringAsFixed(2)} | Cost: ₹${batch.purchasePrice.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
                            error: (err, stack) => Text('Error loading batches: $err'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const VerticalDivider(width: 24),

                  // Right Pane: Add New Batch Form
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ADD NEW BATCH',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _batchNoController,
                                decoration: const InputDecoration(
                                  labelText: 'Batch Number *',
                                  hintText: 'e.g. BATCH-2026-X',
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _qtyController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Initial Quantity *',
                                  hintText: 'e.g. 50',
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _purchasePriceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Cost Price (₹)',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _mrpController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'MRP (₹) *',
                                      ),
                                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Date Pickers
                              OutlinedButton.icon(
                                onPressed: () => _selectDate(context, true),
                                icon: const Icon(Icons.event, size: 16),
                                label: Text(
                                  _expiryDate == null
                                      ? 'Select Expiry Date *'
                                      : 'Expiry: ${_dateFormat.format(_expiryDate!)}',
                                  style: TextStyle(
                                    fontWeight: _expiryDate != null ? FontWeight.bold : FontWeight.normal,
                                    color: _expiryDate != null ? theme.colorScheme.primary : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () => _selectDate(context, false),
                                icon: const Icon(Icons.event_available, size: 16),
                                label: Text(
                                  _mfgDate == null
                                      ? 'Select Mfg Date (Optional)'
                                      : 'Mfg: ${_dateFormat.format(_mfgDate!)}',
                                ),
                              ),
                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isAddingBatch ? null : _saveBatch,
                                  icon: _isAddingBatch
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.add_shopping_cart, size: 16),
                                  label: const Text('Add Batch'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
