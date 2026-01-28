import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import '../models/user_model.dart';
import '../models/credit_transaction_model.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart'; // ✅ Analytics eklendi
import '../services/rewarded_ad_service.dart'; // ✅ Rewarded Ad Service eklendi

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final NotificationService _notificationService = NotificationService();
  final AnalyticsService _analytics = AnalyticsService(); // ✅ Analytics eklendi
  final RewardedAdService _rewardedAdService = RewardedAdService(); // ✅ Rewarded Ad Service
  
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastTokenRefresh;
  
  // ✅ Dil senkronizasyon callback
  Function(String)? onLanguageSync;
  
  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  int get credits => _userModel?.credits ?? 0;
  bool get isPremium => _userModel?.isActivePremium ?? false;
  bool get canAnalyze => _userModel?.canAnalyze ?? false;
  
  AuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      
      if (user != null) {
        await _ensureValidToken();
        await _loadUserModel(user.uid);
        
        // ✅ Firebase Analytics: User ID set
        await _analytics.setUserId(user.uid);
        
        // ✅ Dil senkronizasyonu
        _triggerLanguageSync(user.uid);
        
        // ✅ FCM Token kaydet
        await _saveFcmToken(user.uid);
        
        // ✅ Ödüllü reklamı arka planda pre-load et (ücretsiz kullanıcılar için)
        if (!(_userModel?.isActivePremium ?? false)) {
          _preloadRewardedAd();
        }
      } else {
        _userModel = null;
        _lastTokenRefresh = null;
      }
      
      notifyListeners();
    });
    
    _startTokenRefreshTimer();
  }
  
  void _startTokenRefreshTimer() {
    Future.delayed(const Duration(minutes: 30), () async {
      if (_user != null) {
        await _ensureValidToken();
        _startTokenRefreshTimer();
      }
    });
  }
  
  Future<void> _ensureValidToken() async {
    try {
      if (_user == null) return;
      
      final now = DateTime.now();
      if (_lastTokenRefresh == null || 
          now.difference(_lastTokenRefresh!).inMinutes > 45) {
        await _user!.getIdToken(true);
        _lastTokenRefresh = now;
      }
    } catch (e) {
      // Silent fail
    }
  }
  
  Future<void> _loadUserModel(String uid) async {
    try {
      final userModel = await _userService.getUser(uid);
      _userModel = userModel;
      
      // ✅ Firebase Analytics: User properties
      if (userModel != null) {
        await _analytics.setUserProperty(
          name: 'is_premium',
          value: userModel.isActivePremium.toString(),
        );
        await _analytics.setUserProperty(
          name: 'credits',
          value: userModel.credits.toString(),
        );
      }
      
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }
  
  /// ✅ Dil senkronizasyonu tetikle
  void _triggerLanguageSync(String uid) async {
    try {
      final userModel = await _userService.getUser(uid);
      if (userModel != null && userModel.preferredLanguage.isNotEmpty) {
        if (onLanguageSync != null) {
          onLanguageSync!(userModel.preferredLanguage);
        }
      }
    } catch (e) {
      // Silent fail
    }
  }
  
  /// ✅ FCM Token'ı Firebase'e kaydet
  Future<void> _saveFcmToken(String uid) async {
    try {
      await _notificationService.initialize();
      await _notificationService.saveFcmTokenToDatabase(uid);
    } catch (e) {
      // Silent fail
    }
  }
  
  /// ✅ Ödüllü reklamı arka planda pre-load et
  Future<void> _preloadRewardedAd() async {
    try {
      debugPrint('🎬 Ödüllü reklam pre-loading başlatılıyor...');
      await _rewardedAdService.preloadAd();
    } catch (e) {
      debugPrint('⚠️ Ödüllü reklam pre-loading hatası: $e');
      // Silent fail - uygulama çalışmaya devam eder
    }
  }
  
  void listenToUserModel(String uid) {
    _userService.getUserStream(uid).listen((userModel) {
      _userModel = userModel;
      notifyListeners();
    });
  }
  
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    String? selectedLanguage,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final ipAddress = await _getIpAddress();
      final deviceId = await _getDeviceId();
      
      final isBanned = await _userService.checkIpBan(ipAddress, deviceId);
      if (isBanned) {
        _isLoading = false;
        _errorMessage = 'Bu cihazdan daha önce hesap oluşturulmuş.\n\nDestek ekibimizle iletişime geçin:\nbilwininc@gmail.com';
        notifyListeners();
        return false;
      }
      
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();
      _user = _auth.currentUser;
      
      if (_user != null) {
        final newUser = UserModel(
          uid: _user!.uid,
          email: _user!.email ?? email,
          displayName: name,
          photoUrl: _user!.photoURL,
          credits: 3,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          ipAddress: ipAddress,
          deviceId: deviceId,
          isBanned: false,
          preferredLanguage: selectedLanguage ?? 'tr',
        );
        
        await _userService.createOrUpdateUser(newUser);
        await _loadUserModel(_user!.uid);
        listenToUserModel(_user!.uid);
        
        // ✅ Kayıt sonrası senkronizasyon
        _triggerLanguageSync(_user!.uid);
        await _saveFcmToken(_user!.uid);
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Beklenmeyen bir hata oluştu: $e';
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _user = _auth.currentUser;
      
      if (_user != null) {
        final existingUser = await _userService.getUser(_user!.uid);
        if (existingUser != null && existingUser.isBanned) {
          await _auth.signOut();
          _user = null;
          _isLoading = false;
          _errorMessage = 'Hesabınız askıya alınmıştır.\n\nDestek ekibimizle iletişime geçin:\nbilwininc@gmail.com';
          notifyListeners();
          return false;
        }
        
        await _userService.createOrUpdateUser(UserModel(
          uid: _user!.uid,
          email: _user!.email ?? email,
          displayName: _user!.displayName,
          photoUrl: _user!.photoURL,
          createdAt: existingUser?.createdAt ?? DateTime.now(),
          lastLoginAt: DateTime.now(),
        ));
        
        await _loadUserModel(_user!.uid);
        listenToUserModel(_user!.uid);
        
        // ✅ Giriş sonrası senkronizasyon
        _triggerLanguageSync(_user!.uid);
        await _saveFcmToken(_user!.uid);
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Beklenmeyen bir hata oluştu: $e';
      notifyListeners();
      return false;
    }
  }
  
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      _userModel = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Çıkış yapılamadı: $e';
      notifyListeners();
    }
  }
  
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      await _auth.sendPasswordResetEmail(email: email);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> useCredit({String? analysisId}) async {
    if (_user == null) return false;
    
    final success = await _userService.useCredit(
      _user!.uid,
      analysisId: analysisId,
    );
    
    if (success) {
      await _loadUserModel(_user!.uid);
    }
    
    return success;
  }
  
  Future<bool> addCredits(int amount, String productId, String purchaseId) async {
    if (_user == null) return false;
    
    final success = await _userService.addCredits(
      userId: _user!.uid,
      amount: amount,
      type: TransactionType.purchase,
      description: 'Kredi satın alma',
      productId: productId,
      purchaseId: purchaseId,
    );
    
    if (success) {
      await _loadUserModel(_user!.uid);
    }
    
    return success;
  }
  
  Future<bool> activatePremium(int days, String productId, String purchaseId) async {
    if (_user == null) return false;
    
    final success = await _userService.setPremium(
      userId: _user!.uid,
      durationDays: days,
      productId: productId,
      purchaseId: purchaseId,
    );
    
    if (success) {
      await _loadUserModel(_user!.uid);
    }
    
    return success;
  }
  
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    return await signInWithEmail(email: email, password: password);
  }
  
  Future<bool> sendPasswordResetEmail(String email) async {
    return await resetPassword(email);
  }
  
  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Şifre çok zayıf.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Yanlış şifre.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
      default:
        return 'Bir hata oluştu: $code';
    }
  }
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  Future<void> refreshUserModel() async {
    if (_user != null) {
      await _ensureValidToken();
      await _loadUserModel(_user!.uid);
    }
  }
  
  Future<void> refreshUser() async {
    if (_user != null) {
      await _loadUserModel(_user!.uid);
    }
  }
  
  Future<String?> getValidToken() async {
    try {
      if (_user == null) return null;
      await _ensureValidToken();
      final token = await _user!.getIdToken();
      return token;
    } catch (e) {
      return null;
    }
  }
  
  Future<String?> _getIpAddress() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org?format=json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ip'];
      }
    } catch (e) {
      // Silent fail
    }
    return null;
  }
  
  Future<String?> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      // Silent fail
    }
    return null;
  }
}
