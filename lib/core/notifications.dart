import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper over `flutter_local_notifications` for the (currently single)
/// referral-earnings alert. Initializes lazily on first use and requests the
/// runtime permission then, so a user who never earns a commission is never
/// prompted.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Stable id so repeated "you earned" alerts replace rather than stack up.
  static const int _referralId = 8801;

  Future<void> _ensureInit() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    // Android 13+ needs an explicit runtime grant.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// Fire (or refresh) the referral commission alert.
  Future<void> showCommission({
    required String title,
    required String body,
  }) async {
    try {
      await _ensureInit();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'referral_earnings',
          'Referral earnings',
          channelDescription: 'Alerts when you earn a referral commission',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(_referralId, title, body, details,
          payload: 'referral');
    } catch (e) {
      // Never let a notification failure affect app flow.
      debugPrint('Referral notification failed: $e');
    }
  }
}
