import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ✅ Background message handler (MUST be top-level function)
/// Bu fonksiyon uygulama kapalıyken gelen bildirimleri yönetir
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Background bildirim alındı: ${message.messageId}');
  debugPrint('   Başlık: ${message.notification?.title}');
  debugPrint('   İçerik: ${message.notification?.body}');
}

/// NotificationService - FCM Push Notification Yönetimi
/// 
/// Görevler:
/// 1. FCM token alma ve yönetme
/// 2. Bildirimleri dinleme (foreground, background, terminated)
/// 3. Local notification gösterme
/// 4. Token'ı Firebase Realtime Database'e kaydetme
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  String? _fcmToken;

  /// FCM Token'ı dışarıdan okumak için getter
  String? get fcmToken => _fcmToken;
  
  /// Servis başlatıldı mı?
  bool get isInitialized => _initialized;

  /// ✅ INITIALIZE: Notification servisini başlat
  /// Bu fonksiyon main.dart'ta çağrılacak
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ Notification service zaten başlatılmış');
      return;
    }

    try {
      debugPrint('🔔 Notification Service başlatılıyor...');

      // 1. İzin iste (iOS & Android 13+)
      await _requestPermission();

      // 2. FCM token'ı al
      await _getFcmToken();

      // 3. Local notification'ları başlat
      await _initializeLocalNotifications();

      // 4. Message listener'ları kur
      _setupMessageHandlers();

      // 5. Token yenilenme listener'ı
      _setupTokenRefreshListener();

      // 6. Uygulama kapalıyken gelen bildirime tıklanmış mı kontrol et
      await _checkInitialMessage();

      _initialized = true;
      debugPrint('✅ Notification Service başarıyla başlatıldı');
      debugPrint('📱 FCM Token: $_fcmToken');
    } catch (e) {
      debugPrint('❌ Notification Service başlatma hatası: $e');
    }
  }

  /// İzin iste (iOS & Android 13+)
  Future<void> _requestPermission() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Bildirim izni verildi');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ Geçici bildirim izni verildi');
      } else {
        debugPrint('❌ Bildirim izni reddedildi');
      }
    } catch (e) {
      debugPrint('❌ İzin isteme hatası: $e');
    }
  }

  /// ✅ GET TOKEN: FCM token'ı al
  Future<String?> _getFcmToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      
      if (_fcmToken != null) {
        debugPrint('✅ FCM Token alındı: $_fcmToken');
        return _fcmToken;
      } else {
        debugPrint('⚠️ FCM Token alınamadı');
        return null;
      }
    } catch (e) {
      debugPrint('❌ FCM Token alma hatası: $e');
      return null;
    }
  }

  /// ✅ SAVE TOKEN: Token'ı Firebase Realtime Database'e kaydet
  /// Path: /users/{uid}/fcmToken
  Future<void> saveFcmTokenToDatabase(String userId) async {
    if (_fcmToken == null) {
      debugPrint('⚠️ FCM Token henüz alınmadı, kaydedilemedi');
      return;
    }

    try {
      final db = FirebaseDatabase.instance.ref();
      await db.child('users/$userId/fcmToken').set(_fcmToken);
      
      debugPrint('✅ FCM Token veritabanına kaydedildi');
      debugPrint('   Path: /users/$userId/fcmToken');
      debugPrint('   Token: $_fcmToken');
    } catch (e) {
      debugPrint('❌ FCM Token kaydetme hatası: $e');
    }
  }

  /// ✅ AUTO SAVE: Kullanıcı giriş yaptığında otomatik kaydet
  /// Bu fonksiyon AuthProvider'dan çağrılabilir
  Future<void> autoSaveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      debugPrint('⚠️ Kullanıcı giriş yapmamış, token kaydedilmedi');
      return;
    }

    await saveFcmTokenToDatabase(user.uid);
  }

  /// Local notification'ları başlat
  Future<void> _initializeLocalNotifications() async {
    try {
      // Android ayarları
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS ayarları
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

      // Android notification channel oluştur
      await _createNotificationChannel();

      debugPrint('✅ Local notifications başlatıldı');
    } catch (e) {
      debugPrint('❌ Local notification başlatma hatası: $e');
    }
  }

  /// Android notification channel oluştur
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

  /// Message handler'ları kur
  void _setupMessageHandlers() {
    // Background message handler (top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ✅ FOREGROUND: Uygulama açıkken gelen bildirimler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground bildirim alındı: ${message.notification?.title}');
      
      // Local notification olarak göster
      _showLocalNotification(message);
    });

    // Bildirime tıklanınca (uygulama background'dayken)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📩 Bildirime tıklandı (background): ${message.data}');
      _handleNotificationTap(message);
    });
  }

  /// Token yenilenme listener'ı
  void _setupTokenRefreshListener() {
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM Token yenilendi: $newToken');
      _fcmToken = newToken;
      
      // Token yenilendiğinde otomatik kaydet
      autoSaveToken();
    });
  }

  /// Uygulama kapalıyken gelen bildirime tıklanmış mı kontrol et
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _fcm.getInitialMessage();
    
    if (initialMessage != null) {
      debugPrint('📩 Uygulama kapalıyken gelen bildirime tıklandı');
      _handleNotificationTap(initialMessage);
    }
  }

  /// ✅ FOREGROUND NOTIFICATION: Local notification göster
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
      
      debugPrint('✅ Local notification gösterildi');
    } catch (e) {
      debugPrint('❌ Local notification gösterme hatası: $e');
    }
  }

  /// Bildirime tıklanınca
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📩 Bildirim tıklandı:');
    debugPrint('   Data: ${message.data}');
    
    // TODO: Burada bildirim tipine göre sayfa yönlendirmesi yapılabilir
    // Örnek: if (message.data['type'] == 'credit_low') { navigate to subscription }
  }

  /// Notification tapped callback
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📩 Local notification tıklandı: ${response.payload}');
  }

  /// ✅ TEST NOTIFICATION: Test bildirimi gönder
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
      
      debugPrint('✅ Test bildirimi gönderildi');
    } catch (e) {
      debugPrint('❌ Test bildirimi hatası: $e');
    }
  }
}
