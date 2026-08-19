import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/data/repositories/sales_repository.dart';
import 'package:pharmassist/features/pos/providers/pos_providers.dart';

class PosInvoiceDialog extends ConsumerWidget {
  final int saleId;

  const PosInvoiceDialog({super.key, required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final salesRepo = ref.watch(salesRepositoryProvider);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<SaleWithItems?>(
          future: salesRepo.getSaleDetails(saleId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return SizedBox(
                height: 250,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load invoice #$saleId'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }

            final details = snapshot.data!;
            final sale = details.sale;
            final customer = details.customer;
            final items = details.items;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green.withValues(alpha: 0.15),
                          child: const Icon(Icons.check_circle_rounded, color: Colors.green),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sale Complete',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            Text(
                              'Tax Invoice / Cash Receipt',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Printable Thermal Receipt Container
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Header
                          const Center(
                            child: Column(
                              children: [
                                Text(
                                  'PHARM ASSIST ERP',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                                ),
                                Text(
                                  'Licensed Retail & Wholesale Pharmacy',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                Text(
                                  'GSTIN: 32ABCDE1234F1Z5 | DL: KKL/2026/PHARM',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 16),

                          // Invoice Meta Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invoice: ${sale.invoiceNo}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    'Date: ${dateFormat.format(sale.date)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Customer: ${customer?.name ?? 'Walk-in Customer'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    'Payment: ${sale.paymentMode.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: sale.paymentMode == 'credit' ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Itemized Table
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Text('ITEM / BATCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),

                          ...items.map((it) {
                            final total = (it.item.qty * it.item.rate) - it.item.discount + it.item.taxAmount;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(it.medicine.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('Batch: ${it.batch.batchNo} | GST: ${it.medicine.gstRate}%', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Expanded(flex: 1, child: Text('${it.item.qty} ${it.medicine.unit}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                                  Expanded(flex: 1, child: Text('₹${it.item.rate.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                                  Expanded(flex: 1, child: Text('₹${total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            );
                          }),

                          const Divider(height: 16),

                          // Calculation Summary
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              children: [
                                _buildInvoiceSummaryRow('Subtotal', '₹${sale.subtotal.toStringAsFixed(2)}'),
                                _buildInvoiceSummaryRow('CGST', '₹${sale.taxCgst.toStringAsFixed(2)}'),
                                _buildInvoiceSummaryRow('SGST', '₹${sale.taxSgst.toStringAsFixed(2)}'),
                                if (sale.discount > 0)
                                  _buildInvoiceSummaryRow('Overall Discount', '- ₹${sale.discount.toStringAsFixed(2)}', isDiscount: true),
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                    Text('₹${sale.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF10B981))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          const Center(
                            child: Text(
                              'Thank you for your visit! Wish you good health.',
                              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dialog Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Receipt sent to thermal printer pool!')),
                          );
                        },
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print Thermal Receipt'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.done_all_rounded),
                        label: const Text('Done / Next Sale'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvoiceSummaryRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDiscount ? Colors.red : Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDiscount ? Colors.red : null)),
        ],
      ),
    );
  }
}
