import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/core/widgets/custom_title_bar.dart';
import 'package:pharmassist/features/auth/providers/auth_provider.dart';
import 'package:pharmassist/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pharmassist/features/inventory/presentation/medicine_list_screen.dart';
import 'package:pharmassist/features/settings/presentation/settings_screen.dart';

final activeNavIndexProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final activeIndex = ref.watch(activeNavIndexProvider);

    final navItems = _getNavItemsForRole(authState.role);

    return Scaffold(
      body: Column(
        children: [
          // Custom Desktop Title Bar
          const CustomTitleBar(),

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
                      // Store & Status Banner
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
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.greenAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Offline Mode',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                                  onPressed: () {
                                    ref.read(authProvider.notifier).logout();
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
      NavItem(title: 'Customers & Credit', icon: Icons.people_alt_outlined),
      NavItem(title: 'Reports & Analytics', icon: Icons.assessment_outlined),
      NavItem(title: 'Settings & Backup', icon: Icons.settings_outlined),
    ];

    if (role == AppConstants.roleCashier) {
      return [all[0], all[1], all[4]]; // Dashboard, POS Billing, Customers
    } else if (role == AppConstants.rolePharmacist) {
      return [all[0], all[1], all[2], all[3], all[4]];
    }
    return all; // Admin sees all
  }

  Widget indexToScreen(int index, List<NavItem> items) {
    if (index >= items.length) return const Center(child: Text('Screen not found'));
    final title = items[index].title;

    if (title == 'Dashboard') {
      return const DashboardScreen();
    }
    if (title == 'Inventory Master') {
      return const MedicineListScreen();
    }
    if (title == 'Settings & Backup') {
      return const SettingsScreen();
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
}

class NavItem {
  final String title;
  final IconData icon;
  final String? shortcut;

  NavItem({required this.title, required this.icon, this.shortcut});
}
