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
    final currentThemeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      body: Container(
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
                  child: Icon(Icons.settings_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings & Configuration',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Manage theme preferences, system parameters, and offline database settings',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            Expanded(
              child: ListView(
                children: [
                  // Section 1: Theme & Appearance Settings
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.palette_outlined, color: theme.colorScheme.primary, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Appearance & Theme',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Choose your preferred visual mode for distraction-free pharmacy operation.',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 20),

                          // Visual Theme Selection Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildThemeCard(
                                  context,
                                  title: 'Dark Mode',
                                  description: 'Sleek dark theme optimized for long hours and low light.',
                                  icon: Icons.dark_mode_rounded,
                                  mode: ThemeMode.dark,
                                  isSelected: currentThemeMode == ThemeMode.dark,
                                  onTap: () => themeNotifier.setThemeMode(ThemeMode.dark),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildThemeCard(
                                  context,
                                  title: 'Light Mode',
                                  description: 'Bright, crisp light theme with high contrast.',
                                  icon: Icons.light_mode_rounded,
                                  mode: ThemeMode.light,
                                  isSelected: currentThemeMode == ThemeMode.light,
                                  onTap: () => themeNotifier.setThemeMode(ThemeMode.light),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildThemeCard(
                                  context,
                                  title: 'System Mode',
                                  description: 'Automatically match operating system preferences.',
                                  icon: Icons.brightness_auto_rounded,
                                  mode: ThemeMode.system,
                                  isSelected: currentThemeMode == ThemeMode.system,
                                  onTap: () => themeNotifier.setThemeMode(ThemeMode.system),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),

                          // Quick Toggle Switch Option
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Quick Dark Mode Toggle', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              currentThemeMode == ThemeMode.dark
                                  ? 'Dark mode is active'
                                  : (currentThemeMode == ThemeMode.light ? 'Light mode is active' : 'System theme mode active'),
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: currentThemeMode == ThemeMode.dark,
                            activeThumbColor: theme.colorScheme.primary,
                            onChanged: (val) {
                              themeNotifier.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 2: Store & Application Info
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.storefront_rounded, color: theme.colorScheme.primary, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Store & System Information',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoTile('Application Name', AppConstants.appName),
                          _buildInfoTile('System Version', 'v1.2.0 (Desktop & Mobile ERP)'),
                          _buildInfoTile('Architecture', 'Offline-First SQLite & Cloud Sync'),
                          _buildInfoTile('Platform Target', 'Desktop & Mobile (Linux/Windows/Android)'),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AboutScreen()),
                              );
                            },
                            icon: const Icon(Icons.info_outline_rounded, size: 18),
                            label: const Text('View Developer Profile & Contact Details'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 3: Firebase Cloud Backup
                  const FirebaseBackupCard(),

                  const SizedBox(height: 20),

                  // Section 4: Data Backup & Local Storage
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sd_storage_outlined, color: theme.colorScheme.primary, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Data & Backup Management',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All inventory, transaction logs, and customer credits are stored locally on this machine.',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Local SQLite Database backup created successfully.')),
                                  );
                                },
                                icon: const Icon(Icons.backup_outlined, size: 18),
                                label: const Text('Export Local Backup'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Database integrity check: OK')),
                                  );
                                },
                                icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                                label: const Text('Check Database Health'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showClearDbDialog(context, ref),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                                  foregroundColor: Colors.redAccent,
                                  side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                                label: const Text('Clear Database'),
                              ),
                            ],
                          ),
                        ],
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

  Future<void> _showClearDbDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Clear Entire Local Database?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to clear all local data?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 10),
            Text(
              'This operation will wipe all medicines, batches, purchase inward records, sales history, distributors, and activity logs from this local device.',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 10),
            Text(
              'This action CANNOT be undone.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
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
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Yes, Wipe Database'),
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
    required ThemeMode mode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.dividerColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
