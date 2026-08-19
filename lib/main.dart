import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:pharmassist/core/theme/app_theme.dart';
import 'package:pharmassist/core/theme/theme_provider.dart';
import 'package:pharmassist/core/widgets/app_shell.dart';
import 'package:pharmassist/features/auth/presentation/login_screen.dart';
import 'package:pharmassist/features/auth/providers/auth_provider.dart';

import 'package:pharmassist/features/mobile/presentation/mobile_app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Window Manager for Desktop ONLY
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1366, 768),
      minimumSize: Size(AppConstants.minWindowWidth, AppConstants.minWindowHeight),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: AppConstants.appName,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    const ProviderScope(
      child: PharmAssistApp(),
    ),
  );
}

class PharmAssistApp extends ConsumerWidget {
  const PharmAssistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f11): () async {
          if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
            final isFullScreen = await windowManager.isFullScreen();
            await windowManager.setFullScreen(!isFullScreen);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: authState.isLoading
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : (authState.isAuthenticated
                  ? _getResponsiveShell(context)
                  : const LoginScreen()),
        ),
      ),
    );
  }

  Widget _getResponsiveShell(BuildContext context) {
    final isMobilePlatform = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final isSmallScreen = MediaQuery.of(context).size.width < 700;

    if (isMobilePlatform || isSmallScreen) {
      return const MobileAppShell();
    }
    return const AppShell();
  }
}
