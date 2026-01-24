import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'user_service.dart';
import '../models/credit_transaction_model.dart';

class RatingService {
  final InAppReview _inAppReview = InAppReview.instance;
  final UserService _userService = UserService();
  
  // Kullanıcının daha önce değerlendirme yaptığını kontrol et
  Future<bool> hasRatedBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('has_rated_app') ?? false;
    } catch (e) {
      print('❌ Rating kontrolü hatası: $e');
      return false;
    }
  }
  
  // Değerlendirme yapıldığını kaydet
  Future<void> _markAsRated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_rated_app', true);
      print('✅ Kullanıcı değerlendirme yaptı olarak işaretlendi');
    } catch (e) {
      print('❌ Rating kaydetme hatası: $e');
    }
  }
  
  // Değerlendirme popup'ını göster ve bonus kredi ekle
  Future<bool> requestRating(String userId) async {
    try {
      // Daha önce değerlendirme yapılmış mı kontrol et
      final hasRated = await hasRatedBefore();
      
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
        await _markAsRated();
        return true;
      }
      
      // Rating dialog'unu göster
      await _inAppReview.requestReview();
      print('✅ Rating dialog gösterildi');
      
      // Bonus kredi ekle
      await _giveRatingBonus(userId);
      
      // Değerlendirme yapıldı olarak işaretle
      await _markAsRated();
      
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
