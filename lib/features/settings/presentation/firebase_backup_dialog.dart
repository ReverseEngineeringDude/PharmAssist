import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pharmassist/core/services/network_service.dart';
import 'package:pharmassist/data/services/firestore_backup_service.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';
import 'package:pharmassist/features/purchases/providers/purchase_providers.dart';

class FirebaseBackupCard extends ConsumerStatefulWidget {
  const FirebaseBackupCard({super.key});

  @override
  ConsumerState<FirebaseBackupCard> createState() => _FirebaseBackupCardState();
}

class _FirebaseBackupCardState extends ConsumerState<FirebaseBackupCard> {
  final TextEditingController _jsonInputController = TextEditingController();

  @override
  void dispose() {
    _jsonInputController.dispose();
    super.dispose();
  }

  Future<void> _pickFirebaseJsonFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Firebase Credential Files (json, dart)',
        extensions: ['json', 'dart'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      final content = await file.readAsString();
      final success = await ref
          .read(firestoreBackupNotifierProvider.notifier)
          .setConfigFromJson(content, filePath: file.name);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded ${file.name} successfully! Firebase connection verified.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final err = ref.read(firestoreBackupNotifierProvider).errorMessage ?? 'Invalid credential file format.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read credential file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showManualJsonInputDialog(BuildContext context) {
    _jsonInputController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.code_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Paste Firebase Credentials'),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the content of your google-services.json, firebase.json, or firebase_options.dart below:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _jsonInputController,
                maxLines: 8,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'Paste google-services.json, firebase.json, or DefaultFirebaseOptions content here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final text = _jsonInputController.text.trim();
                if (text.isEmpty) return;

                Navigator.of(ctx).pop();
                final ok = await ref
                    .read(firestoreBackupNotifierProvider.notifier)
                    .setConfigFromJson(text, filePath: 'User Pasted Content');

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Firebase credentials configured!'
                            : (ref.read(firestoreBackupNotifierProvider).errorMessage ?? 'Configuration error'),
                      ),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save & Verify Credentials'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleBackupStocks() async {
    final state = ref.read(firestoreBackupNotifierProvider);
    if (!state.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load Firebase credentials first.')),
      );
      return;
    }

    final repo = ref.read(inventoryRepositoryProvider);
    final purchaseRepo = ref.read(purchaseRepositoryProvider);
    final medicines = await repo.getMedicinesWithStock();
    final batches = await repo.getAllBatches();

    final result = await ref
        .read(firestoreBackupNotifierProvider.notifier)
        .backupStocks(medicines: medicines, allBatches: batches, purchaseRepo: purchaseRepo);

    if (mounted && result != null) {
      if (result.success) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Cloud Backup Successful'),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target Collections: stocks, purchases, suppliers', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Medicines Backed Up: ${result.backedUpCount}', style: const TextStyle(fontSize: 12)),
                      Text('Batches Included: ${batches.length}', style: const TextStyle(fontSize: 12)),
                      Text('Cloud Destination: Firebase Firestore (${state.config?.projectId})', style: const TextStyle(fontSize: 12)),
                      Text('Timestamp: ${DateFormat('dd MMM yyyy, hh:mm:ss a').format(result.timestamp)}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup Error: ${result.error ?? result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRestoreStocks() async {
    final state = ref.read(firestoreBackupNotifierProvider);
    if (!state.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure Firebase options first.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_download_rounded, color: Colors.indigo, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Restore Stocks from Cloud?'),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This operation will fetch the latest stock records & batch details from Google Cloud Firestore and update your local SQLite database.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              'Are you sure you want to proceed with restoring the cloud backup?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Restore Cloud Backup'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final repo = ref.read(inventoryRepositoryProvider);
    final purchaseRepo = ref.read(purchaseRepositoryProvider);
    final summary = await ref
        .read(firestoreBackupNotifierProvider.notifier)
        .restoreBackup(repo, purchaseRepo: purchaseRepo);

    if (mounted && summary != null) {
      // Invalidate stream providers so UI updates immediately across all screens
      ref.invalidate(medicinesWithStockProvider);
      ref.invalidate(allBatchesStreamProvider);
      ref.invalidate(purchaseInvoicesProvider);
      ref.invalidate(suppliersProvider);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Cloud Restore Complete'),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Successfully imported ${summary['medicines']} medicines, ${summary['batches']} batches, and ${summary['purchases'] ?? 0} purchase invoices from Cloud Firestore into your local database.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Medicines Updated/Inserted: ${summary['medicines']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Batches Updated/Inserted: ${summary['batches']}', style: const TextStyle(fontSize: 12)),
                    Text('Purchases Restored: ${summary['purchases'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Distributors Restored: ${summary['suppliers'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Source Collections: stocks, purchases, suppliers (${state.config?.projectId})', style: const TextStyle(fontSize: 12)),
                    Text('Restored At: ${DateFormat('dd MMM yyyy, hh:mm:ss a').format(DateTime.now())}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backupState = ref.watch(firestoreBackupNotifierProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    final isConnected = backupState.isConnected && isOnline;
    final isConfigured = backupState.isConfigured;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isConnected
              ? Colors.green.withValues(alpha: 0.5)
              : (isConfigured ? Colors.orange.withValues(alpha: 0.5) : theme.dividerColor),
          width: isConnected || isConfigured ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Firebase Logo / Icon and Connection Badge
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.orange.withValues(alpha: 0.15),
                      child: const Icon(Icons.cloud_sync_rounded, color: Colors.orange, size: 22),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All-in-One Cloud Backup & Restore (Firestore)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Full backup of medicines, stock batches, inward purchases & distributors.',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.green.withValues(alpha: 0.15)
                        : (isConfigured ? Colors.orange.withValues(alpha: 0.15) : theme.disabledColor.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isConnected ? Colors.green : (isConfigured ? Colors.orange : theme.disabledColor),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : (isConfigured ? Icons.cloud_queue : Icons.cloud_off),
                        size: 14,
                        color: isConnected ? Colors.green : (isConfigured ? Colors.orange : theme.disabledColor),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnected
                            ? 'CONNECTED'
                            : (isConfigured ? 'CONFIGURED' : 'NOT CONNECTED'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.green : (isConfigured ? Colors.orange : theme.disabledColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Credentials Info Row
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Firebase Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    isConfigured
                        ? 'Project ID: "${backupState.config!.projectId}" • Source: ${backupState.config!.filePath ?? 'Auto-Detected'}'
                        : 'No credentials loaded. Upload google-services.json, firebase.json, or firebase_options.dart.',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: isConfigured ? 'monospace' : null,
                      color: isConfigured ? theme.colorScheme.primary : theme.disabledColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFirebaseJsonFile,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Upload File'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showManualJsonInputDialog(context),
                        icon: const Icon(Icons.paste_rounded, size: 16),
                        label: const Text('Paste Credentials'),
                      ),
                      if (isConfigured) ...[
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(firestoreBackupNotifierProvider.notifier).clearConfig();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Firebase credentials cleared.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.cleaning_services_rounded, color: Colors.grey, size: 16),
                          label: const Text('Clear Config'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            if (!isOnline) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade800),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.amber.shade800, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Offline Mode Active: Internet connection is unavailable. Connect to Wi-Fi/Ethernet to perform cloud backups or restores.',
                        style: TextStyle(color: Colors.amber.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (backupState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        backupState.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons & Sync Status Footer
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // All-in-One Cloud Backup Button
                ElevatedButton.icon(
                  onPressed: (backupState.isBackingUp || backupState.isRestoring || !isConfigured || !isOnline)
                      ? null
                      : _handleBackupStocks,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: backupState.isBackingUp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    backupState.isBackingUp ? 'Syncing All Data...' : 'All-in-One Cloud Backup',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                // All-in-One Cloud Restore Button
                ElevatedButton.icon(
                  onPressed: (backupState.isBackingUp || backupState.isRestoring || !isConfigured || !isOnline)
                      ? null
                      : _handleRestoreStocks,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: backupState.isRestoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_download_rounded, size: 18),
                  label: Text(
                    backupState.isRestoring ? 'Restoring All Data...' : 'All-in-One Cloud Restore',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                // Test Connection Button
                OutlinedButton.icon(
                  onPressed: !isConfigured
                      ? null
                      : () async {
                          final ok = await ref
                              .read(firestoreBackupNotifierProvider.notifier)
                              .testConnection();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Firestore Connection Test: SUCCESS' : 'Firestore Connection Test: FAILED'),
                                backgroundColor: ok ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.network_check_rounded, size: 16),
                  label: const Text('Test Connection'),
                ),

                // Last Sync Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last Online Backup:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        backupState.lastBackupTime != null
                            ? dateFormat.format(backupState.lastBackupTime!)
                            : 'Never backed up',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
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
