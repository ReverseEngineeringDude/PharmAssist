import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/data/repositories/purchase_repository.dart';

class PurchaseDetailsDialog extends StatelessWidget {
  final PurchaseInvoiceWithDetails invoiceDetails;

  const PurchaseDetailsDialog({super.key, required this.invoiceDetails});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inv = invoiceDetails.invoice;
    final sup = invoiceDetails.supplier;
    final items = invoiceDetails.items;

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Invoice #${inv.invoiceNo}',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Date: ${dateFormat.format(inv.date)} | Registered Stock Inward',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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

            // Supplier Details Card
            Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DISTRIBUTOR / SUPPLIER', style: TextStyle(fontSize: 10, color: theme.disabledColor, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (sup.address != null) Text(sup.address!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GSTIN CREDENTIALS', style: TextStyle(fontSize: 10, color: theme.disabledColor, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(sup.gstin ?? 'Unregistered / None', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                          if (sup.phone != null) Text('Phone: ${sup.phone}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Itemized Table
            Text('Invoice Line Items (${items.length}):', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Text('${index + 1}', style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        item.medicine.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Batch: ${item.batch.batchNo} | Exp: ${dateFormat.format(item.batch.expiryDate)} | MRP: ₹${item.batch.mrp.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${item.qty} ${item.medicine.unit} × ₹${item.rate.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '₹${item.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Footer Totals
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Grand Total Invoice Amount', style: TextStyle(fontSize: 12, color: theme.disabledColor)),
                    Text(
                      '₹${inv.totalAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
