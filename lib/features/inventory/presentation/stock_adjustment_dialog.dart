import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/features/auth/providers/auth_provider.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final Medicine medicine;

  const StockAdjustmentDialog({super.key, required this.medicine});

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  Batch? _selectedBatch;
  final _qtyChangeController = TextEditingController();
  final _customReasonController = TextEditingController();

  bool _isAddition = false; // default subtraction / correction
  String _selectedReason = 'Damaged / Expired';
  bool _isSaving = false;

  final List<String> _predefinedReasons = [
    'Damaged / Expired',
    'Inventory Audit Discrepancy',
    'Breakage / Spill',
    'Supplier Return',
    'Manual Stock Add / Purchase Correction',
    'Other Custom Reason',
  ];

  @override
  void dispose() {
    _qtyChangeController.dispose();
    _customReasonController.dispose();
    super.dispose();
  }

  Future<void> _performAdjustment() async {
    if (_selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a batch to adjust.')),
      );
      return;
    }

    final rawQtyStr = _qtyChangeController.text.trim();
    if (rawQtyStr.isEmpty || int.tryParse(rawQtyStr) == null || int.parse(rawQtyStr) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid non-zero adjustment quantity.')),
      );
      return;
    }

    final changeValue = int.parse(rawQtyStr);
    final finalQtyChange = _isAddition ? changeValue : -changeValue;

    final reason = _selectedReason == 'Other Custom Reason'
        ? _customReasonController.text.trim()
        : _selectedReason;

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for stock adjustment.')),
      );
      return;
    }

    final authState = ref.read(authProvider);
    final userId = authState.currentUser?.id ?? 1;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.adjustStock(
        batchId: _selectedBatch!.id,
        qtyChange: finalQtyChange,
        reason: reason,
        userId: userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock adjusted successfully (${_isAddition ? '+' : ''}$finalQtyChange units for Batch ${_selectedBatch!.batchNo}).',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adjusting stock: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batchesAsync = ref.watch(batchesForMedicineProvider(widget.medicine.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                  child: const Icon(Icons.tune, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Adjustment — ${widget.medicine.name}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'All adjustments are recorded in audit logs.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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

            // Select Batch
            Text(
              '1. Select Target Batch *',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            batchesAsync.when(
              data: (batches) {
                if (batches.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No batches available for this medicine. Create a batch first.'),
                  );
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(6),
                    color: theme.colorScheme.surface,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Batch>(
                      value: _selectedBatch,
                      isExpanded: true,
                      hint: const Text('Choose batch...'),
                      items: batches.map((batch) {
                        return DropdownMenuItem<Batch>(
                          value: batch,
                          child: Text(
                            'Batch: ${batch.batchNo} | Current Qty: ${batch.quantity} | Exp: ${DateFormat('dd/MM/yyyy').format(batch.expiryDate)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (Batch? val) {
                        setState(() {
                          _selectedBatch = val;
                        });
                      },
                    ),
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error: $err'),
            ),

            const SizedBox(height: 16),

            // Select Addition or Reduction
            Text(
              '2. Adjustment Type *',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_circle_outline, size: 16, color: Colors.redAccent),
                        SizedBox(width: 6),
                        Text('Deduct Stock (-)'),
                      ],
                    ),
                    selected: !_isAddition,
                    selectedColor: Colors.redAccent.withValues(alpha: 0.2),
                    onSelected: (selected) {
                      if (selected) setState(() => _isAddition = false);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Text('Add Stock (+)'),
                      ],
                    ),
                    selected: _isAddition,
                    selectedColor: Colors.green.withValues(alpha: 0.2),
                    onSelected: (selected) {
                      if (selected) setState(() => _isAddition = true);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quantity & Reason
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _qtyChangeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _isAddition ? 'Qty to Add *' : 'Qty to Deduct *',
                      prefixText: _isAddition ? '+' : '-',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedReason,
                    decoration: const InputDecoration(labelText: 'Reason for Adjustment *'),
                    items: _predefinedReasons.map((r) {
                      return DropdownMenuItem<String>(
                        value: r,
                        child: Text(r, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedReason = val);
                      }
                    },
                  ),
                ),
              ],
            ),

            if (_selectedReason == 'Other Custom Reason') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customReasonController,
                decoration: const InputDecoration(
                  labelText: 'Specify Custom Reason *',
                ),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _performAdjustment,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Confirm Adjustment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAddition ? Colors.green : Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
