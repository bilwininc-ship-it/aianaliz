import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:firebase_database/firebase_database.dart';
import 'user_service.dart';
import '../models/credit_transaction_model.dart';

class RatingService {
  final InAppReview _inAppReview = InAppReview.instance;
  final UserService _userService = UserService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // Kullanıcının daha önce değerlendirme yaptığını kontrol et (Firebase'den)
  Future<bool> hasRatedBefore(String userId) async {
    try {
      // Önce Firebase'den kontrol et
      final userRef = _database.ref('users/$userId');
      final snapshot = await userRef.child('hasRatedApp').get();
      
      if (snapshot.exists && snapshot.value == true) {
        print('✅ Kullanıcı daha önce puanlama yapmış (Firebase)');
        return true;
      }
      
      // Firebase'de yoksa SharedPreferences'tan kontrol et (backward compatibility)
      final prefs = await SharedPreferences.getInstance();
      final hasRatedLocal = prefs.getBool('has_rated_app') ?? false;
      
      if (hasRatedLocal) {
        // Local'de varsa Firebase'e senkronize et
        await _markAsRated(userId);
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Rating kontrolü hatası: $e');
      return false;
    }
  }
  
  // Değerlendirme yapıldığını kaydet (Firebase + SharedPreferences)
  Future<void> _markAsRated(String userId) async {
    try {
      // Firebase'e kaydet
      final userRef = _database.ref('users/$userId');
      await userRef.update({'hasRatedApp': true});
      
      // SharedPreferences'a da kaydet (offline çalışma için)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_rated_app', true);
      
      print('✅ Kullanıcı değerlendirme yaptı olarak işaretlendi (Firebase + Local)');
    } catch (e) {
      print('❌ Rating kaydetme hatası: $e');
    }
  }
  
  // Değerlendirme popup'ını göster ve bonus kredi ekle
  Future<bool> requestRating(String userId) async {
    try {
      // Daha önce değerlendirme yapılmış mı kontrol et
      final hasRated = await hasRatedBefore(userId);
      
      if (hasRated) {
        print('ℹ️ Kullanıcı daha önce değerlendirme yapmış');
        return false;
      }
      
      // In-app review mevcut mu kontrol et
      final isAvailable = await _inAppReview.isAvailable();
      
      if (!isAvailable) {
        print('⚠️ In-app review bu cihazda mevcut değil');
        // Yine de bonus ver (test ortamında veya desteklenmiyorsa)
        await _giveRatingBonus(userId);
        await _markAsRated(userId);
        return true;
      }
      
      // Rating dialog'unu göster
      await _inAppReview.requestReview();
      print('✅ Rating dialog gösterildi');
      
      // Bonus kredi ekle
      await _giveRatingBonus(userId);
      
      // Değerlendirme yapıldı olarak işaretle (Firebase + Local)
      await _markAsRated(userId);
      
      return true;
      
    } catch (e) {
      print('❌ Rating request hatası: $e');
      return false;
    }
  }
  
  // Bonus kredi ekle
  Future<void> _giveRatingBonus(String userId) async {
    try {
      final success = await _userService.addCredits(
        userId: userId,
        amount: 2, // 2 bonus kredi
        type: TransactionType.bonus,
        description: 'Uygulama değerlendirme bonusu 🌟',
      );
      
      if (success) {
        print('✅ Rating bonusu eklendi: +2 kredi');
      } else {
        print('❌ Rating bonusu eklenemedi');
      }
    } catch (e) {
      print('❌ Bonus kredi ekleme hatası: $e');
    }
  }
  
  // Manuel olarak store'a yönlendir (alternatif)
  Future<void> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing(
        appStoreId: 'YOUR_APP_STORE_ID', // iOS için gerekli
      );
    } catch (e) {
      print('❌ Store listing açma hatası: $e');
    }
  }
}
