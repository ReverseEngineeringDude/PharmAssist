import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';

class MedicineFormDialog extends ConsumerStatefulWidget {
  final Medicine? medicine;

  const MedicineFormDialog({super.key, this.medicine});

  @override
  ConsumerState<MedicineFormDialog> createState() => _MedicineFormDialogState();
}

class _MedicineFormDialogState extends ConsumerState<MedicineFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _genericNameController;
  late TextEditingController _manufacturerController;
  late TextEditingController _categoryController;
  late TextEditingController _hsnCodeController;
  late TextEditingController _gstRateController;
  late TextEditingController _unitController;
  late TextEditingController _reorderLevelController;

  String _scheduleFlag = AppConstants.scheduleNone;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final med = widget.medicine;
    _nameController = TextEditingController(text: med?.name ?? '');
    _genericNameController = TextEditingController(text: med?.genericName ?? '');
    _manufacturerController = TextEditingController(text: med?.manufacturer ?? '');
    _categoryController = TextEditingController(text: med?.category ?? 'Tablets');
    _hsnCodeController = TextEditingController(text: med?.hsnCode ?? '3004');
    _gstRateController = TextEditingController(text: med?.gstRate.toString() ?? '12.0');
    _unitController = TextEditingController(text: med?.unit ?? 'Strip');
    _reorderLevelController = TextEditingController(text: med?.reorderLevel.toString() ?? '10');
    _scheduleFlag = med?.scheduleFlag ?? AppConstants.scheduleNone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genericNameController.dispose();
    _manufacturerController.dispose();
    _categoryController.dispose();
    _hsnCodeController.dispose();
    _gstRateController.dispose();
    _unitController.dispose();
    _reorderLevelController.dispose();
    super.dispose();
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final gstRate = double.tryParse(_gstRateController.text) ?? 12.0;
      final reorderLevel = int.tryParse(_reorderLevelController.text) ?? 10;

      if (widget.medicine == null) {
        // Add new
        await repo.addMedicine(
          MedicinesCompanion.insert(
            name: _nameController.text.trim(),
            genericName: drift.Value(_genericNameController.text.trim().isEmpty ? null : _genericNameController.text.trim()),
            manufacturer: drift.Value(_manufacturerController.text.trim().isEmpty ? null : _manufacturerController.text.trim()),
            category: drift.Value(_categoryController.text.trim().isEmpty ? null : _categoryController.text.trim()),
            hsnCode: drift.Value(_hsnCodeController.text.trim().isEmpty ? null : _hsnCodeController.text.trim()),
            gstRate: drift.Value(gstRate),
            unit: drift.Value(_unitController.text.trim().isEmpty ? 'Strip' : _unitController.text.trim()),
            reorderLevel: drift.Value(reorderLevel),
            scheduleFlag: drift.Value(_scheduleFlag),
          ),
        );
      } else {
        // Update existing
        final updated = widget.medicine!.copyWith(
          name: _nameController.text.trim(),
          genericName: drift.Value(_genericNameController.text.trim().isEmpty ? null : _genericNameController.text.trim()),
          manufacturer: drift.Value(_manufacturerController.text.trim().isEmpty ? null : _manufacturerController.text.trim()),
          category: drift.Value(_categoryController.text.trim().isEmpty ? null : _categoryController.text.trim()),
          hsnCode: drift.Value(_hsnCodeController.text.trim().isEmpty ? null : _hsnCodeController.text.trim()),
          gstRate: gstRate,
          unit: _unitController.text.trim().isEmpty ? 'Strip' : _unitController.text.trim(),
          reorderLevel: reorderLevel,
          scheduleFlag: _scheduleFlag,
        );
        await repo.updateMedicine(updated);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving medicine: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.medicine != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Header
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note : Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Medicine Master' : 'Add New Medicine',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Form Fields Grid
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Brand / Medicine Name *',
                                hintText: 'e.g. Paracetamol 650mg',
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _genericNameController,
                              decoration: const InputDecoration(
                                labelText: 'Generic Name (Salt)',
                                hintText: 'e.g. Acetaminophen',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _manufacturerController,
                              decoration: const InputDecoration(
                                labelText: 'Manufacturer',
                                hintText: 'e.g. Cipla / Sun Pharma',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _categoryController,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                hintText: 'e.g. Tablets, Syrup, Injection',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _hsnCodeController,
                              decoration: const InputDecoration(
                                labelText: 'HSN Code',
                                hintText: 'e.g. 3004',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _gstRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              decoration: const InputDecoration(
                                labelText: 'GST Rate %',
                                suffixText: '%',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _unitController,
                              decoration: const InputDecoration(
                                labelText: 'Unit of Packing',
                                hintText: 'e.g. Strip / Bottle / Box',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _reorderLevelController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Reorder Stock Level',
                                hintText: 'e.g. 10',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Schedule Drug Flag Picker
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule Drug Classification (Govt Compliance)',
                            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildScheduleChip(AppConstants.scheduleNone, 'None / OTC', Colors.grey),
                              const SizedBox(width: 8),
                              _buildScheduleChip(AppConstants.scheduleH, 'Schedule H', Colors.orange),
                              const SizedBox(width: 8),
                              _buildScheduleChip(AppConstants.scheduleH1, 'Schedule H1', Colors.redAccent),
                              const SizedBox(width: 8),
                              _buildScheduleChip(AppConstants.scheduleX, 'Schedule X', Colors.purpleAccent),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

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
                    onPressed: _isSaving ? null : _saveMedicine,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 18),
                    label: Text(isEditing ? 'Update Medicine' : 'Save Medicine'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleChip(String code, String label, Color color) {
    final isSelected = _scheduleFlag == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
      ),
      side: BorderSide(color: isSelected ? color : Theme.of(context).dividerColor),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _scheduleFlag = code;
          });
        }
      },
    );
  }
}
