import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Background message handler (MUST be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Silent background handler
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _requestPermission();
      await _getFcmToken();
      await _initializeLocalNotifications();
      _setupMessageHandlers();
      _setupTokenRefreshListener();
      await _checkInitialMessage();

      _initialized = true;
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _requestPermission() async {
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      // Silent fail
    }
  }

  Future<String?> _getFcmToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      return _fcmToken;
    } catch (e) {
      return null;
    }
  }

  /// ✅ FCM Token'ı Firebase'e kaydet
  Future<void> saveFcmTokenToDatabase(String userId) async {
    if (_fcmToken == null) return;

    try {
      final db = FirebaseDatabase.instance.ref();
      await db.child('users/$userId/fcmToken').set(_fcmToken);
    } catch (e) {
      // Silent fail
    }
  }

  /// ✅ Otomatik token kaydetme (Giriş/Kayıt sonrası)
  Future<void> autoSaveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await saveFcmTokenToDatabase(user.uid);
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _createNotificationChannel();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'ai_spor_pro_channel',
      'AI Spor Pro Bildirimleri',
      description: 'Uygulama bildirimleri',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
  }

  void _setupTokenRefreshListener() {
    _fcm.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      autoSaveToken();
    });
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'ai_spor_pro_channel',
      'AI Spor Pro Bildirimleri',
      channelDescription: 'Uygulama bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        details,
        payload: message.data.toString(),
      );
    } catch (e) {
      // Silent fail
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // TODO: Navigate based on message.data
  }

  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Handle notification tap
  }

  Future<void> sendTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'ai_spor_pro_channel',
      'AI Spor Pro Bildirimleri',
      channelDescription: 'Uygulama bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _localNotifications.show(
        999,
        '🎉 Test Bildirimi',
        'Bildirim sistemi çalışıyor!',
        details,
      );
    } catch (e) {
      // Silent fail
    }
  }
}
