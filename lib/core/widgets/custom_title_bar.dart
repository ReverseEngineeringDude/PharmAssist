import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/core/theme/theme_provider.dart';
import 'package:pharmassist/features/auth/providers/auth_provider.dart';

class CustomTitleBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const CustomTitleBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(38);

  @override
  ConsumerState<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends ConsumerState<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;
  bool _isFullScreen = false;

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      _checkWindowState();
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() => _checkWindowState();

  @override
  void onWindowUnmaximize() => _checkWindowState();

  @override
  void onWindowEnterFullScreen() => _checkWindowState();

  @override
  void onWindowLeaveFullScreen() => _checkWindowState();

  Future<void> _checkWindowState() async {
    if (!_isDesktop) return;
    final maximized = await windowManager.isMaximized();
    final fullScreen = await windowManager.isFullScreen();
    if (mounted) {
      setState(() {
        _isMaximized = maximized;
        _isFullScreen = fullScreen;
      });
    }
  }

  void _toggleMaximize() async {
    if (!_isDesktop) return;
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    _checkWindowState();
  }

  void _toggleFullScreen() async {
    if (!_isDesktop) return;
    final fullScreen = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!fullScreen);
    _checkWindowState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    return Container(
     height: 38,

decoration: BoxDecoration(
  color: theme.colorScheme.surface,
  border: Border(
    bottom: BorderSide(
      color: theme.colorScheme.outline.withValues(alpha: 0.20),
      width: 1,
    ),
  ),
),
      child: Row(
        children: [
          // App Icon & Title
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.medical_services_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'v${AppConstants.appVersion}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    if (authState.isAuthenticated) ...[
                      const SizedBox(width: 16),
                      Container(
                        height: 14,
                        width: 1,
                        color: theme.dividerColor,
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.person_outline, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        authState.userName,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleColor(authState.role).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getRoleColor(authState.role).withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          authState.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getRoleColor(authState.role),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Window Controls & Quick Theme Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final themeMode = ref.watch(themeModeProvider);
                  final isDark = themeMode == ThemeMode.dark;
                  return Tooltip(
                    message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    child: InkWell(
                      onTap: () {
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                      hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      child: SizedBox(
                        width: 40,
                        height: 38,
                        child: Icon(
                          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          size: 16,
                          color: isDark ? Colors.amber : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_isDesktop) ...[
                _WindowButton(
                  icon: _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  onPressed: _toggleFullScreen,
                  tooltip: _isFullScreen ? 'Exit Fullscreen (F11)' : 'Fullscreen (F11)',
                ),
                _WindowButton(
                  icon: Icons.remove,
                  onPressed: () {
                    if (_isDesktop) windowManager.minimize();
                  },
                  tooltip: 'Minimize',
                ),
                _WindowButton(
                  icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
                  onPressed: _toggleMaximize,
                  tooltip: _isMaximized ? 'Restore' : 'Maximize',
                ),
                _WindowButton(
                  icon: Icons.close,
                  isClose: true,
                  onPressed: () {
                    if (_isDesktop) windowManager.close();
                  },
                  tooltip: 'Close',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purpleAccent;
      case 'pharmacist':
        return Colors.lightBlueAccent;
      case 'cashier':
        return const Color(0xFF10B981);
      default:
        return Colors.tealAccent;
    }
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.1),
        child: SizedBox(
          width: 44,
          height: 38,
          child: Icon(
            icon,
            size: 16,
            color: isClose ? null : theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
