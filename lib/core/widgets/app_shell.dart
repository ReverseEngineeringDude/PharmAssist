import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/core/services/network_service.dart';
import 'package:pharmassist/core/widgets/custom_title_bar.dart';
import 'package:pharmassist/features/auth/providers/auth_provider.dart';
import 'package:pharmassist/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pharmassist/features/inventory/presentation/medicine_list_screen.dart';
import 'package:pharmassist/features/pos/presentation/pos_screen.dart';
import 'package:pharmassist/features/purchases/presentation/purchase_list_screen.dart';
import 'package:pharmassist/features/reports/presentation/reports_screen.dart';
import 'package:pharmassist/features/about/presentation/about_screen.dart';
import 'package:pharmassist/features/settings/presentation/settings_screen.dart';

class ActiveNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  set state(int value) => super.state = value;
}
final activeNavIndexProvider = NotifierProvider<ActiveNavIndexNotifier, int>(ActiveNavIndexNotifier.new);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final activeIndex = ref.watch(activeNavIndexProvider);
    final networkState = ref.watch(networkNotifierProvider);

    final navItems = _getNavItemsForRole(authState.role);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Scaffold(
      body: Column(
        children: [
          // Custom Desktop Title Bar
          if (isDesktop) const CustomTitleBar(),

          // Offline Warning Banner (Displayed when user is not connected to internet)
          if (!networkState.isOnline) _buildOfflineTopBanner(context, ref, networkState),

          // Main ERP Content Area
          Expanded(
            child: Row(
              children: [
                // Navigation Sidebar
                Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      right: BorderSide(color: theme.dividerColor, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Store & Network Status Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.dividerColor, width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                              child: Icon(Icons.storefront, color: theme.colorScheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Main Pharmacy',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: networkState.isOnline ? const Color(0xFF10B981) : Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          networkState.isOnline ? 'Online Sync' : 'No Internet',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: networkState.isOnline
                                                ? const Color(0xFF10B981)
                                                : Colors.redAccent,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Navigation List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: navItems.length,
                          itemBuilder: (context, index) {
                            final item = navItems[index];
                            final isSelected = activeIndex == index;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: Material(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                child: ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  leading: Icon(
                                    item.icon,
                                    size: 20,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: item.shortcut != null
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.shortcut!,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    ref.read(activeNavIndexProvider.notifier).state = index;
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Bottom User Profile & Logout Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: theme.dividerColor, width: 1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: theme.colorScheme.primary,
                                  child: Text(
                                    authState.userName.isNotEmpty
                                        ? authState.userName.substring(0, 1).toUpperCase()
                                        : 'U',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        authState.userName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        authState.role.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.logout, size: 18),
                                  tooltip: 'Log out',
                                  onPressed: () async {
                                    ref.read(activeNavIndexProvider.notifier).state = 0;
                                    await ref.read(authProvider.notifier).logout();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Active Screen Body
                Expanded(
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: indexToScreen(activeIndex, navItems),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<NavItem> _getNavItemsForRole(String role) {
    final all = [
      NavItem(title: 'Dashboard', icon: Icons.dashboard_outlined),
      NavItem(title: 'POS Billing', icon: Icons.point_of_sale, shortcut: 'F2'),
      NavItem(title: 'Inventory Master', icon: Icons.inventory_2_outlined),
      NavItem(title: 'Purchases', icon: Icons.shopping_bag_outlined),
      NavItem(title: 'Reports & Analytics', icon: Icons.assessment_outlined),
      NavItem(title: 'Settings & Backup', icon: Icons.settings_outlined),
      NavItem(title: 'About Us', icon: Icons.info_outline_rounded),
    ];

    if (role == AppConstants.roleCashier) {
      return [all[0], all[1], all[6]]; // Dashboard, POS Billing, About Us
    } else if (role == AppConstants.rolePharmacist) {
      return [all[0], all[1], all[2], all[3], all[6]];
    }
    return all; // Admin sees all
  }

  Widget indexToScreen(int index, List<NavItem> items) {
    if (index >= items.length) return const Center(child: Text('Screen not found'));
    final title = items[index].title;

    if (title == 'Dashboard') {
      return const DashboardScreen();
    }
    if (title == 'POS Billing') {
      return const PosScreen();
    }
    if (title == 'Inventory Master') {
      return const MedicineListScreen();
    }
    if (title == 'Purchases') {
      return const PurchaseListScreen();
    }
    if (title == 'Reports & Analytics') {
      return const ReportsScreen();
    }
    if (title == 'Settings & Backup') {
      return const SettingsScreen();
    }
    if (title == 'About Us') {
      return const AboutScreen();
    }

    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(items[index].icon, size: 64, color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scaffold ready for feature implementation in upcoming milestones.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineTopBanner(BuildContext context, WidgetRef ref, NetworkState networkState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFB91C1C), // Rich warning crimson red
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'NO INTERNET CONNECTION — You are currently offline. Local billing & inventory operations remain fully functional, but Cloud Backup is paused.',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              ref.read(networkNotifierProvider.notifier).checkConnection();
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (networkState.isChecking)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                    )
                  else
                    const Icon(Icons.refresh, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    networkState.isChecking ? 'Checking...' : 'Retry',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NavItem {
  final String title;
  final IconData icon;
  final String? shortcut;

  NavItem({required this.title, required this.icon, this.shortcut});
}
