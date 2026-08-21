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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(28),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load invoice #$saleId',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
            
            final isCredit = sale.paymentMode.toLowerCase() == 'credit';

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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sale Complete',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tax Invoice / Cash Receipt',
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                // Printable Thermal Receipt Container
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Header
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'PHARM ASSIST ERP',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Licensed Retail & Wholesale Pharmacy',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'GSTIN: 32ABCDE1234F1Z5 | DL: KKL/2026/PHARM',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
                          ),

                          // Invoice Meta Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invoice: #${sale.invoiceNo}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(sale.date),
                                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    customer?.name ?? 'Walk-in Customer',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCredit 
                                          ? Colors.orange.withValues(alpha: 0.15) 
                                          : Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      sale.paymentMode.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isCredit ? Colors.orange.shade800 : Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),

                          // Itemized Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3, 
                                  child: Text('ITEM / BATCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.primary))
                                ),
                                Expanded(
                                  flex: 1, 
                                  child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.primary))
                                ),
                                Expanded(
                                  flex: 1, 
                                  child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.primary))
                                ),
                                Expanded(
                                  flex: 1, 
                                  child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.primary))
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Items List
                          ...items.map((it) {
                            final total = (it.item.qty * it.item.rate) - it.item.discount + it.item.taxAmount;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(it.medicine.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Batch: ${it.batch.batchNo} | GST: ${it.medicine.gstRate}%', 
                                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1, 
                                    child: Text('${it.item.qty} ${it.medicine.unit}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))
                                  ),
                                  Expanded(
                                    flex: 1, 
                                    child: Text('₹${it.item.rate.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))
                                  ),
                                  Expanded(
                                    flex: 1, 
                                    child: Text('₹${total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
                                  ),
                                ],
                              ),
                            );
                          }),

                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
                          ),

                          // Calculation Summary
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: [
                                _buildInvoiceSummaryRow(context, 'Subtotal', '₹${sale.subtotal.toStringAsFixed(2)}'),
                                _buildInvoiceSummaryRow(context, 'CGST', '₹${sale.taxCgst.toStringAsFixed(2)}'),
                                _buildInvoiceSummaryRow(context, 'SGST', '₹${sale.taxSgst.toStringAsFixed(2)}'),
                                if (sale.discount > 0)
                                  _buildInvoiceSummaryRow(context, 'Overall Discount', '- ₹${sale.discount.toStringAsFixed(2)}', isDiscount: true),
                                
                                const SizedBox(height: 12),
                                
                                // Grand Total Box
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                      Text(
                                        '₹${sale.total.toStringAsFixed(2)}', 
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.green.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),

                          Center(
                            child: Text(
                              'Thank you for your visit! Wish you good health.',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

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
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Print Thermal Receipt', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('Done / Next Sale', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildInvoiceSummaryRow(BuildContext context, String label, String value, {bool isDiscount = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w500,
              color: isDiscount ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            )
          ),
          Text(
            value, 
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.w700, 
              color: isDiscount ? Colors.red : theme.colorScheme.onSurface,
            )
          ),
        ],
      ),
    );
  }
}