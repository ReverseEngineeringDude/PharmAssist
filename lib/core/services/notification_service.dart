import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      linux: initializationSettingsLinux,
    );

    try {
      await _notificationsPlugin.initialize(initializationSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('Notification initialization warning: $e');
    }
  }

  static Future<void> showLowStockAlert({
    required String medicineName,
    required int currentStock,
    required int reorderLevel,
  }) async {
    if (!_initialized) await initialize();

    const LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      linux: linuxPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin.show(
        medicineName.hashCode,
        'Low Stock Alert: $medicineName',
        'Current stock ($currentStock) is at or below reorder level ($reorderLevel).',
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('Error showing low stock notification: $e');
    }
  }

  static Future<void> showExpiryAlert({
    required String medicineName,
    required String batchNo,
    required String expiryDateStr,
    required bool isExpired,
  }) async {
    if (!_initialized) await initialize();

    const LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      linux: linuxPlatformChannelSpecifics,
    );

    final title = isExpired ? 'EXPIRED BATCH: $medicineName' : 'Near Expiry Alert: $medicineName';
    final body = isExpired
        ? 'Batch $batchNo expired on $expiryDateStr. Please remove from active rack.'
        : 'Batch $batchNo expires on $expiryDateStr.';

    try {
      await _notificationsPlugin.show(
        (medicineName + batchNo).hashCode,
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('Error showing expiry notification: $e');
    }
  }
}
