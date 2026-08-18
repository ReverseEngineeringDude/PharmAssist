import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/data/repositories/inventory_repository.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';

class BulkImportDialog extends ConsumerStatefulWidget {
  const BulkImportDialog({super.key});

  @override
  ConsumerState<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends ConsumerState<BulkImportDialog> {
  final TextEditingController _jsonController = TextEditingController();
  List<BulkImportItem> _parsedItems = [];
  String? _parseError;
  bool _isImporting = false;

  static const String sampleAiPrompt = '''
I want you to act as a Pharmacy Data Assistant for my Pharm Assist ERP system.

Here is the exact JSON structure schema required for bulk importing medicines into my inventory database:

```json
[
  {
    "name": "Exact Brand Name (e.g. Crocin 650mg)",
    "genericName": "Generic Composition / Salt Name (e.g. Paracetamol)",
    "category": "Tablet / Capsule / Syrup / Injection / Ointment",
    "manufacturer": "Pharma Company Name (e.g. GSK)",
    "hsnCode": "30049099",
    "gstRate": 12.0,
    "scheduleFlag": "NONE / H / H1 / X",
    "unit": "Strip / Bottle / Box / Tablet",
    "reorderLevel": 20,
    "batchNo": "BATCH-NUMBER",
    "expiryDate": "YYYY-MM-DD",
    "mrp": 35.00,
    "purchasePrice": 22.50,
    "quantity": 100
  }
]
```

Instructions:
1. Please confirm you understand this JSON structure schema.
2. I will send you a list of medicine names and quantities (or purchase invoice items).
3. Whenever I send you medicine names, fill in all technical pharmacy details (Generic Salt, HSN Code, GST %, Schedule, Prices in INR, Batch No, Expiry Date) and output a valid JSON array matching this exact schema.
4. Output ONLY valid JSON inside a json code block so I can copy it directly.

Please reply with: "Ready! Please send your list of medicine names and quantities."
''';

  void _copyAiPrompt() {
    Clipboard.setData(const ClipboardData(text: sampleAiPrompt));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI Data Prompt copied! Paste into ChatGPT/Gemini/Claude first. Then send your medicine list to the AI to get the JSON.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _parseJsonInput() {
    setState(() {
      _parseError = null;
      _parsedItems.clear();
    });

    String raw = _jsonController.text.trim();
    if (raw.isEmpty) {
      setState(() => _parseError = 'Please paste your AI-generated JSON data first.');
      return;
    }

    // Strip markdown code block wrappers ```json ... ```
    if (raw.contains('```')) {
      final lines = raw.split('\n');
      final filtered = lines.where((l) => !l.trim().startsWith('```')).join('\n');
      raw = filtered.trim();
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        setState(() => _parseError = 'Invalid JSON: Top-level structure must be a JSON array [...].');
        return;
      }

      final List<BulkImportItem> items = [];
      for (int i = 0; i < decoded.length; i++) {
        final map = decoded[i];
        if (map is! Map<String, dynamic>) continue;

        final String? name = map['name']?.toString();
        if (name == null || name.trim().isEmpty) {
          continue;
        }

        DateTime? expDate;
        final expStr = map['expiryDate']?.toString();
        if (expStr != null && expStr.isNotEmpty) {
          try {
            expDate = DateTime.parse(expStr);
          } catch (_) {
            expDate = DateTime.now().add(const Duration(days: 365));
          }
        }

        items.add(
          BulkImportItem(
            name: name.trim(),
            genericName: map['genericName']?.toString(),
            category: map['category']?.toString() ?? 'General',
            manufacturer: map['manufacturer']?.toString(),
            hsnCode: map['hsnCode']?.toString(),
            gstRate: double.tryParse(map['gstRate']?.toString() ?? '12') ?? 12.0,
            scheduleFlag: map['scheduleFlag']?.toString().toUpperCase() ?? 'NONE',
            unit: map['unit']?.toString() ?? 'Strip',
            reorderLevel: int.tryParse(map['reorderLevel']?.toString() ?? '10') ?? 10,
            batchNo: map['batchNo']?.toString(),
            expiryDate: expDate,
            mrp: double.tryParse(map['mrp']?.toString() ?? '0'),
            purchasePrice: double.tryParse(map['purchasePrice']?.toString() ?? '0'),
            quantity: int.tryParse(map['quantity']?.toString() ?? '0'),
          ),
        );
      }

      if (items.isEmpty) {
        setState(() => _parseError = 'No valid medicines found in the provided JSON data.');
      } else {
        setState(() {
          _parsedItems = items;
        });
      }
    } catch (e) {
      setState(() => _parseError = 'JSON Parsing Error: ${e.toString()}');
    }
  }

  Future<void> _handleImport() async {
    if (_parsedItems.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final count = await repo.bulkImportMedicines(_parsedItems);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported $count medicines & initial batches into inventory!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _parseError = 'Import Failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Powered Bulk Inventory Import',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Copy AI prompt schema, generate data using any AI (ChatGPT/Gemini/Claude), paste JSON & import instantly!',
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

            const SizedBox(height: 16),

            // Step Bar Actions
            Row(
              children: [
                // Step 1: Copy AI Prompt
                ElevatedButton.icon(
                  onPressed: _copyAiPrompt,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Step 1: Copy AI Prompt Template'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(width: 12),

                // Step 2: Parse Button
                OutlinedButton.icon(
                  onPressed: _parseJsonInput,
                  icon: const Icon(Icons.code_rounded, size: 16),
                  label: const Text('Step 2: Parse & Validate JSON'),
                ),

                const Spacer(),

                if (_parsedItems.isNotEmpty)
                  Text(
                    '${_parsedItems.length} Medicines Validated',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Input / Preview Split View
            Expanded(
              child: Row(
                children: [
                  // Left Pane: Raw JSON Input Box
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paste AI-Generated JSON Data Below:',
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: TextField(
                            controller: _jsonController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Paste JSON array here...\nExample:\n[\n  {\n    "name": "Paracetamol 500mg",\n    "genericName": "Paracetamol",\n    "hsnCode": "30049099",\n    "gstRate": 12.0,\n    "batchNo": "PAR-2026A",\n    "expiryDate": "2027-12-31",\n    "mrp": 25.0,\n    "purchasePrice": 15.0,\n    "quantity": 100\n  }\n]',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right Pane: Data Preview Table
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Data Preview & Validation:',
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: _parseError != null
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 42),
                                          const SizedBox(height: 10),
                                          Text(
                                            _parseError!,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : (_parsedItems.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.fact_check_outlined, size: 48, color: theme.disabledColor),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'No JSON data parsed yet.\nClick "Step 1: Copy AI Prompt Template", ask AI to fill it, then paste here and click "Step 2: Parse & Validate JSON".',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: _parsedItems.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final item = _parsedItems[index];
                                          return ListTile(
                                            dense: true,
                                            leading: CircleAvatar(
                                              radius: 14,
                                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${item.gstRate}% GST | Sched ${item.scheduleFlag}',
                                                    style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            subtitle: Text(
                                              'Generic: ${item.genericName ?? '—'} | HSN: ${item.hsnCode ?? '—'}\nBatch: ${item.batchNo ?? 'None'} | Exp: ${item.expiryDate?.toString().split(' ')[0] ?? '—'} | MRP: ₹${item.mrp ?? 0} | Qty: ${item.quantity ?? 0} ${item.unit}',
                                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                                            ),
                                          );
                                        },
                                      )),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dialog Footer Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: (_parsedItems.isEmpty || _isImporting) ? null : _handleImport,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(_isImporting ? 'Importing...' : 'Import All ${_parsedItems.length} Medicines'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
