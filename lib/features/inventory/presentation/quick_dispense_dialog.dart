import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/data/repositories/inventory_repository.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';

class QuickDispenseDialog extends ConsumerStatefulWidget {
  final MedicineWithStock item;

  const QuickDispenseDialog({super.key, required this.item});

  @override
  ConsumerState<QuickDispenseDialog> createState() => _QuickDispenseDialogState();
}

class _QuickDispenseDialogState extends ConsumerState<QuickDispenseDialog> {
  final _qtyController = TextEditingController(text: '1');
  final _reasonController = TextEditingController(text: 'OTC Quick Dispense / Customer Purchase');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _adjustQty(int delta) {
    final current = int.tryParse(_qtyController.text.trim()) ?? 1;
    final next = (current + delta).clamp(1, widget.item.totalQuantity);
    _qtyController.text = next.toString();
  }

  Future<void> _dispenseStock() async {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive quantity.')),
      );
      return;
    }

    if (qty > widget.item.totalQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot reduce more than available stock (${widget.item.totalQuantity}).')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.quickReduceStockFEFO(
        medicineId: widget.item.medicine.id,
        reduceQty: qty,
        userId: 1,
        reason: _reasonController.text.trim().isEmpty
            ? 'OTC Quick Dispense'
            : _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully reduced $qty ${widget.item.medicine.unit} from ${widget.item.medicine.name} (FEFO Batch deducted).',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reducing stock: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final med = widget.item.medicine;
    final available = widget.item.totalQuantity;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.withValues(alpha: 0.2),
                  child: const Icon(Icons.remove_shopping_cart_rounded, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Stock Dispense',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Reduce stock count directly (FEFO Batch Deduct)',
                        style: TextStyle(fontSize: 11, color: theme.disabledColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Medicine Highlight Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (med.genericName != null)
                          Text(
                            med.genericName!,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Available Stock', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        '$available ${med.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: available <= med.reorderLevel ? Colors.red : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quantity Counter Controls
            Text('Quantity to Deduct / Sell:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: () => _adjustQty(-1),
                  icon: const Icon(Icons.remove, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => _adjustQty(1),
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),

            const SizedBox(height: 8),
            // Quick preset chips (+1, +5, +10)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQuickChip('+1', () => _adjustQty(1)),
                const SizedBox(width: 8),
                _buildQuickChip('+5', () => _adjustQty(5)),
                const SizedBox(width: 8),
                _buildQuickChip('+10', () => _adjustQty(10)),
                const SizedBox(width: 8),
                _buildQuickChip('MAX ($available)', () => _qtyController.text = available.toString()),
              ],
            ),

            const SizedBox(height: 14),

            // Reason / Note
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason / Customer Sale Note',
                prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _dispenseStock,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                  label: const Text('Confirm Deduct Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: onTap,
    );
  }
}
