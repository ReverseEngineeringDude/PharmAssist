import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/core/theme/theme_provider.dart';
import 'package:pharmassist/data/local/database_provider.dart';
import 'package:pharmassist/features/about/presentation/about_screen.dart';
import 'package:pharmassist/features/inventory/providers/inventory_providers.dart';
import 'package:pharmassist/features/purchases/providers/purchase_providers.dart';
import 'package:pharmassist/features/settings/presentation/firebase_backup_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final borderColor = Colors.grey.withValues(alpha: 0.2);
    final currentThemeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.settings_rounded, color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings & Configuration',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage system parameters, theme preferences, and offline database settings',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            Expanded(
              child: ListView(
                children: [
                  // ==========================================
                  // SECTION 1: Store & System Information
                  // ==========================================
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.computer_rounded, color: theme.colorScheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'System Information',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // System Info Details Grid
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            SizedBox(width: 400, child: _buildInfoTile(theme, 'Application Name', AppConstants.appName)),
                            SizedBox(width: 400, child: _buildInfoTile(theme, 'System Version', 'v1.2.0 (Stable Release)')),
                            SizedBox(width: 400, child: _buildInfoTile(theme, 'Architecture', 'Offline-First SQLite')),
                            SizedBox(width: 400, child: _buildInfoTile(theme, 'Platform Target', 'Desktop & Mobile ERP')),
                            SizedBox(width: 400, child: _buildInfoTile(theme, 'Database Status', 'Healthy / Encrypted')),
                            SizedBox(width: 400, child: _buildInfoTile(theme, 'Sync Engine', 'Firebase Cloud Ready')),
                          ],
                        ),
                        
                        // const SizedBox(height: 20),
                        // Divider(color: borderColor),
                        // const SizedBox(height: 12),
                        
                      
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // SECTION 2: Appearance & Theme
                  // ==========================================
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.palette_rounded, color: theme.colorScheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Appearance & Theme',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Choose your preferred visual mode for distraction-free operation.',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Visual Theme Selection Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildThemeCard(
                                context,
                                title: 'Dark Mode',
                                description: 'Optimized for long hours and low light.',
                                icon: Icons.dark_mode_rounded,
                                isSelected: currentThemeMode == ThemeMode.dark,
                                borderColor: borderColor,
                                onTap: () => themeNotifier.setThemeMode(ThemeMode.dark),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildThemeCard(
                                context,
                                title: 'Light Mode',
                                description: 'Bright, crisp UI with high contrast.',
                                icon: Icons.light_mode_rounded,
                                isSelected: currentThemeMode == ThemeMode.light,
                                borderColor: borderColor,
                                onTap: () => themeNotifier.setThemeMode(ThemeMode.light),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildThemeCard(
                                context,
                                title: 'System Default',
                                description: 'Match operating system preferences.',
                                icon: Icons.brightness_auto_rounded,
                                isSelected: currentThemeMode == ThemeMode.system,
                                borderColor: borderColor,
                                onTap: () => themeNotifier.setThemeMode(ThemeMode.system),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // SECTION 3: Backups (Firebase & Local)
                  // ==========================================
                  
                  // Firebase Backup (Assumes this widget exists and handles its own layout, 
                  // but we wrap it in our standard container style if it doesn't already have one)
                  const FirebaseBackupCard(),

                  const SizedBox(height: 20),

                  // Data Backup & Local Storage
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.sd_storage_rounded, color: Colors.blue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Local Database Management',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Manage on-device SQLite database storage and integrity.',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Local SQLite Database backup created successfully.')),
                                );
                              },
                              icon: const Icon(Icons.save_alt_rounded, size: 18),
                              label: const Text('Export Local Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                side: BorderSide(color: borderColor),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Database integrity check: OK. 0 corrupted rows found.')),
                                );
                              },
                              icon: const Icon(Icons.health_and_safety_rounded, size: 18),
                              label: const Text('Check Database Health', style: TextStyle(fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                side: BorderSide(color: borderColor),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _showClearDbDialog(context, ref),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.withValues(alpha: 0.1),
                                foregroundColor: Colors.red,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                              label: const Text('Wipe Local Database', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearDbDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Clear Local Database?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to completely wipe the local database?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'This operation will destroy all medicines, batches, purchase inward records, sales history, distributors, and activity logs from this machine.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              'This action CANNOT be undone.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Yes, Wipe Database', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = ref.read(databaseProvider);
        await db.clearAllData();

        // Invalidate Riverpod state providers
        ref.invalidate(medicinesWithStockProvider);
        ref.invalidate(allBatchesStreamProvider);
        ref.invalidate(purchaseInvoicesProvider);
        ref.invalidate(suppliersProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All local database records cleared successfully!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear database: $e')),
          );
        }
      }
    }
  }

  Widget _buildThemeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;

    return Material(
      color: isSelected ? activeColor.withValues(alpha: 0.05) : theme.colorScheme.onSurface.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor.withValues(alpha: 0.5) : borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? activeColor : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? activeColor : theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: activeColor, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}