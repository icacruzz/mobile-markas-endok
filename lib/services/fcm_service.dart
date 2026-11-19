import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handler notifikasi background — harus top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// Service untuk Firebase Cloud Messaging (FCM).
/// Mengelola izin notifikasi, token, dan handling pesan.
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _token;
  final ValueNotifier<String?> tokenNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<List<RemoteMessage>> recentMessages =
      ValueNotifier<List<RemoteMessage>>(<RemoteMessage>[]);

  /// FCM token perangkat saat ini
  String? get token => _token;

  /// Inisialisasi FCM: minta izin, ambil token, set handler.
  Future<void> initialize() async {
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Minta izin notifikasi (iOS & Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('[FCM] Izin notifikasi: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Ambil FCM token
      _token = await _messaging.getToken();
      tokenNotifier.value = _token;
      debugPrint('[FCM] Token: $_token');

      // Dengarkan refresh token
      _messaging.onTokenRefresh.listen((newToken) {
        _token = newToken;
        tokenNotifier.value = newToken;
        debugPrint('[FCM] Token diperbarui: $newToken');
      });
    }

    // Handler pesan saat app di foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handler ketika notifikasi diketuk (app dari background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Cek apakah app dibuka dari notifikasi (terminated state)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Callback saat pesan masuk di foreground.
  /// Bisa ditampilkan sebagai SnackBar atau dialog di UI.
  void Function(RemoteMessage)? onForegroundMessage;

  /// Callback saat notifikasi diketuk.
  /// Bisa digunakan untuk deep linking ke halaman terkait.
  void Function(RemoteMessage)? onMessageTapped;

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    _remember(message);
    onForegroundMessage?.call(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Opened from notification: ${message.data}');
    _remember(message);
    onMessageTapped?.call(message);
  }

  void _remember(RemoteMessage message) {
    recentMessages.value = [message, ...recentMessages.value].take(30).toList();
  }
}
