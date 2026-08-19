import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/services/firestore_backup_service.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';
import 'package:pharmassist/features/purchases/providers/purchase_providers.dart';
import 'package:drift/drift.dart' as drift;

class SupplierManagementDialog extends ConsumerStatefulWidget {
  const SupplierManagementDialog({super.key});

  @override
  ConsumerState<SupplierManagementDialog> createState() => _SupplierManagementDialogState();
}

class _SupplierManagementDialogState extends ConsumerState<SupplierManagementDialog> {
  final _nameController = TextEditingController();
  final _gstinController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isAdding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _gstinController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _addSupplier() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter supplier name.')),
      );
      return;
    }

    setState(() => _isAdding = true);
    try {
      final repo = ref.read(purchaseRepositoryProvider);
      await repo.addSupplier(
        SuppliersCompanion.insert(
          name: name,
          gstin: drift.Value(_gstinController.text.trim().isEmpty ? null : _gstinController.text.trim()),
          phone: drift.Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
          address: drift.Value(_addressController.text.trim().isEmpty ? null : _addressController.text.trim()),
        ),
      );

      _nameController.clear();
      _gstinController.clear();
      _phoneController.clear();
      _addressController.clear();

      _triggerCloudSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding supplier: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _triggerCloudSync() {
    final backupState = ref.read(firestoreBackupNotifierProvider);
    if (backupState.isConfigured) {
      final inventoryRepo = ref.read(inventoryRepositoryProvider);
      final purchaseRepo = ref.read(purchaseRepositoryProvider);
      inventoryRepo.getMedicinesWithStock().then((medicines) {
        inventoryRepo.getAllBatches().then((batches) {
          ref.read(firestoreBackupNotifierProvider.notifier).backupStocks(
            medicines: medicines,
            allBatches: batches,
            purchaseRepo: purchaseRepo,
          );
        });
      });
    }
  }

  Future<void> _deleteSupplier(Supplier sup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Delete Distributor?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete distributor "${sup.name}"?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will remove the distributor record and all associated inward invoices from the database.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete Distributor'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final repo = ref.read(purchaseRepositoryProvider);
        final success = await repo.deleteSupplier(sup.id);
        if (mounted) {
          if (success) {
            ref.invalidate(suppliersProvider);
            ref.invalidate(purchaseInvoicesProvider);
            _triggerCloudSync();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Distributor "${sup.name}" deleted from database.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete distributor.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting distributor: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(suppliersProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 750,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.local_shipping_outlined, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distributors & Suppliers Master',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Manage wholesaler contacts, GSTIN tax credentials, and balances due.',
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
            const Divider(height: 24),

            // Content Split (Add Form left, List right)
            Expanded(
              child: Row(
                children: [
                  // Left Pane: Add Supplier Form
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Distributor',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Supplier/Agency Name *',
                              hintText: 'e.g. Apollo Pharma Distributors',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _gstinController,
                            decoration: const InputDecoration(
                              labelText: 'GSTIN Number',
                              hintText: 'e.g. 33AAAAA0000A1Z5',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone / Mobile',
                              hintText: 'e.g. +91 98765 43210',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'City / Address',
                              hintText: 'e.g. Chennai, Tamil Nadu',
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isAdding ? null : _addSupplier,
                              icon: _isAdding
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.add_business_rounded, size: 18),
                              label: const Text('Save Supplier'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right Pane: Existing Suppliers List
                  Expanded(
                    flex: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: suppliersAsync.when(
                        data: (suppliers) {
                          if (suppliers.isEmpty) {
                            return const Center(
                              child: Text('No suppliers added yet.'),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: suppliers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final sup = suppliers[index];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    sup.name[0].toUpperCase(),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                  ),
                                ),
                                title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  'GSTIN: ${sup.gstin ?? '—'} | Phone: ${sup.phone ?? '—'}\nAddress: ${sup.address ?? '—'}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Balance Due',
                                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                        ),
                                        Text(
                                          '₹${sup.balanceDue.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: sup.balanceDue > 0 ? Colors.red : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      tooltip: 'Delete Distributor',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteSupplier(sup),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error: $err')),
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
