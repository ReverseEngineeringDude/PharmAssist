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

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Sidebar width state for drag-to-resize functionality
  double _sidebarWidth = 260.0;
  
  // Dynamically determine if the sidebar is considered "minimized" based on width
  bool get _isMinimized => _sidebarWidth < 140.0;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to securely log out of the system?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(activeNavIndexProvider.notifier).state = 0;
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final activeIndex = ref.watch(activeNavIndexProvider);
    final networkState = ref.watch(networkNotifierProvider);

    final navItems = _getNavItemsForRole(authState.role);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Custom Desktop Title Bar
          if (isDesktop) const CustomTitleBar(),

          // Offline Warning Banner
          if (!networkState.isOnline) _buildOfflineTopBanner(context, ref, networkState),

          // Main ERP Content Area
          Expanded(
            child: Row(
              children: [
                // Resizable Navigation Sidebar
                Container(
                  width: _sidebarWidth,
                  color: theme.colorScheme.surface,
                  child: Column(
                    children: [
                      // Sidebar Header (Logo Space & Pharmacy Name with Bottom Gray Line)
                      Container(
                        height: 72,
                        padding: EdgeInsets.symmetric(horizontal: _isMinimized ? 0 : 20),
                        decoration: BoxDecoration(
                          border: Border(
bottom: BorderSide(
  color: theme.colorScheme.outline.withValues(alpha: 0.25),
  width: 1,
),                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: _isMinimized ? MainAxisAlignment.center : MainAxisAlignment.start,
                          children: [
                            // Dedicated space for your manual logo upload
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: Image.asset(
                                'assets/images/logo.png', // Upload your logo here
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(), // No fallback icon
                              ),
                            ),
                            if (!_isMinimized) ...[
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Main Pharmacy',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.3),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Navigation List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: navItems.length,
                          itemBuilder: (context, index) {
                            final item = navItems[index];
                            final isSelected = activeIndex == index;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () {
                                    ref.read(activeNavIndexProvider.notifier).state = index;
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: _isMinimized ? MainAxisAlignment.center : MainAxisAlignment.start,
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 22,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                        if (!_isMinimized) ...[
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (item.shortcut != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                                    : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                item.shortcut!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: isSelected
                                                      ? theme.colorScheme.primary
                                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Bottom Logout Box (Only Logout button, Top Gray Line)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border(
top: BorderSide(
  color: theme.colorScheme.outline.withValues(alpha: 0.25),
  width: 1,
),                          ),
                        ),
                        child: _isMinimized
                            ? Center(
                                child: IconButton(
                                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                                  tooltip: 'Log out',
                                  onPressed: _handleLogout,
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: _handleLogout,
                                icon: const Icon(Icons.logout_rounded, size: 18),
                                label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                                  foregroundColor: Colors.red,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  minimumSize: const Size(double.infinity, 48), // Stretch button
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // Resizable separation area with gray line and cursor change
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _sidebarWidth += details.delta.dx;
                        // Constrain the sidebar width between 80 (minimized) and 350 (max width)
                        if (_sidebarWidth < 80) _sidebarWidth = 80;
                        if (_sidebarWidth > 350) _sidebarWidth = 350;
                      });
                    },
                    child: Container(
                      width: 5, // Invisible hit-box area for easier dragging
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor, // Blend with background
                        border: Border(
left: BorderSide(
  color: theme.colorScheme.outline.withValues(alpha: 0.25),
  width: 1,
),                        ),
                      ),
                    ),
                  ),
                ),

                // Active Screen Body
                Expanded(
                  child: ClipRect(
                    child: Container(
                      color: theme.scaffoldBackgroundColor,
                      child: indexToScreen(activeIndex, navItems),
                    ),
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
      NavItem(title: 'Dashboard', icon: Icons.dashboard_rounded),
      NavItem(title: 'POS Billing', icon: Icons.point_of_sale_rounded, shortcut: 'F2'),
      NavItem(title: 'Inventory Master', icon: Icons.inventory_2_rounded),
      NavItem(title: 'Purchases', icon: Icons.shopping_bag_rounded),
      NavItem(title: 'Reports & Analytics', icon: Icons.assessment_rounded),
      NavItem(title: 'Settings & Backup', icon: Icons.settings_rounded),
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

    if (title == 'Dashboard') return const DashboardScreen();
    if (title == 'POS Billing') return const PosScreen();
    if (title == 'Inventory Master') return const MedicineListScreen();
    if (title == 'Purchases') return const PurchaseListScreen();
    if (title == 'Reports & Analytics') return const ReportsScreen();
    if (title == 'Settings & Backup') return const SettingsScreen();
    if (title == 'About Us') return const AboutScreen();

    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626), // Modern red
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'NO INTERNET CONNECTION — You are offline. Local operations are functional, but Cloud Backup is paused.',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2),
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () {
              ref.read(networkNotifierProvider.notifier).checkConnection();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (networkState.isChecking)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    networkState.isChecking ? 'Checking...' : 'Retry',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
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