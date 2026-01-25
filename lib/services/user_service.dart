import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../models/credit_transaction_model.dart';

class UserService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // IP ban kontrolü
  Future<bool> checkIpBan(String? ipAddress, String? deviceId) async {
    try {
      if (ipAddress == null && deviceId == null) {
        return false; // IP/Device ID yoksa ban kontrolü yapma
      }

      // Tüm kullanıcıları kontrol et
      final usersRef = _database.ref('users');
      final snapshot = await usersRef.get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return false;
      }

      final usersData = Map<String, dynamic>.from(snapshot.value as Map);
      int accountCount = 0;
      
      // Aynı IP veya Device ID'ye sahip hesap sayısını say
      usersData.forEach((uid, value) {
        final userData = Map<String, dynamic>.from(value as Map);
        final userIp = userData['ipAddress'];
        final userDeviceId = userData['deviceId'];
        
        if ((ipAddress != null && userIp == ipAddress) ||
            (deviceId != null && userDeviceId == deviceId)) {
          accountCount++;
        }
      });
      
      // 1'den fazla hesap varsa ban
      if (accountCount >= 1) {
        print('⚠️ IP/Device ban kontrolü: $accountCount hesap bulundu');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ IP ban kontrolü hatası: $e');
      return false;
    }
  }
  
  // Kullanıcıyı yasakla
  Future<void> banUser(String uid) async {
    try {
      final userRef = _database.ref('users/$uid');
      await userRef.update({'isBanned': true});
      print('✅ Kullanıcı yasaklandı: $uid');
    } catch (e) {
      print('❌ Kullanıcı yasaklama hatası: $e');
    }
  }
  
  // Kullanıcı oluştur veya güncelle (KREDİ KORUMA İLE)
  Future<void> createOrUpdateUser(UserModel user) async {
    try {
      final ref = _database.ref('users/${user.uid}');
      final snapshot = await ref.get();
      
      if (snapshot.exists && snapshot.value != null) {
        // MEVCUT KULLANICI - Sadece lastLoginAt güncelle, KREDİLERİ KORU
        final existingData = Map<String, dynamic>.from(snapshot.value as Map);
        final existingUser = UserModel.fromJson(user.uid, existingData);
        
        await ref.update({
          'lastLoginAt': user.lastLoginAt.millisecondsSinceEpoch,
          'displayName': user.displayName ?? existingUser.displayName,
          'photoUrl': user.photoUrl ?? existingUser.photoUrl,
          'email': user.email,
        });
        
        print('✅ Mevcut kullanıcı güncellendi (krediler korundu): ${user.uid}');
      } else {
        // YENİ KULLANICI - Tam veriyle kaydet
        await ref.set(user.toMap());
        print('✅ Yeni kullanıcı oluşturuldu (3 kredi ile): ${user.uid}');
      }
    } catch (e) {
      print('❌ Kullanıcı oluşturma/güncelleme hatası: $e');
      rethrow;
    }
  }
  
  // Kullanıcı bilgilerini getir
  Future<UserModel?> getUser(String uid) async {
    try {
      final ref = _database.ref('users/$uid');
      final snapshot = await ref.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return UserModel.fromJson(uid, data);
      }
      return null;
    } catch (e) {
      print('❌ Kullanıcı getirme hatası: $e');
      return null;
    }
  }
  
  // Kullanıcı stream (real-time)
  Stream<UserModel?> getUserStream(String uid) {
    return _database.ref('users/$uid').onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return UserModel.fromJson(uid, data);
      }
      return null;
    });
  }
  
  // Kredi ekle (satın alma, bonus vb.)
  Future<bool> addCredits({
    required String userId,
    required int amount,
    required TransactionType type,
    String? description,
    String? productId,
    String? purchaseId,
  }) async {
    try {
      final userRef = _database.ref('users/$userId');
      final snapshot = await userRef.get();
      
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Kullanıcı bulunamadı');
      }
      
      final userData = Map<String, dynamic>.from(snapshot.value as Map);
      final user = UserModel.fromJson(userId, userData);
      final newCredits = user.credits + amount;
      
      // Kullanıcı kredisini güncelle
      await userRef.update({'credits': newCredits});
      
      // İşlem kaydı oluştur
      final transactionRef = _database.ref('credit_transactions').push();
      await transactionRef.set(CreditTransaction(
        id: transactionRef.key ?? '',
        userId: userId,
        type: type,
        amount: amount,
        balanceAfter: newCredits,
        createdAt: DateTime.now(),
        description: description,
        productId: productId,
        purchaseId: purchaseId,
      ).toMap());
      
      print('✅ $amount kredi eklendi. Yeni bakiye: $newCredits');
      return true;
    } catch (e) {
      print('❌ Kredi ekleme hatası: $e');
      return false;
    }
  }
  
  // Kredi kullan (analiz)
  Future<bool> useCredit(String userId, {String? analysisId}) async {
    try {
      final userRef = _database.ref('users/$userId');
      final snapshot = await userRef.get();
      
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Kullanıcı bulunamadı');
      }
      
      final userData = Map<String, dynamic>.from(snapshot.value as Map);
      final user = UserModel.fromJson(userId, userData);
      
      // Premium kullanıcı kontrolü
      if (user.isActivePremium) {
        // Premium kullanıcı, kredi düşmesin ama işlem sayısı artsın
        await userRef.update({
          'totalAnalysisCount': user.totalAnalysisCount + 1,
        });
        
        // Premium kullanım kaydı
        final transactionRef = _database.ref('credit_transactions').push();
        await transactionRef.set(CreditTransaction(
          id: transactionRef.key ?? '',
          userId: userId,
          type: TransactionType.usage,
          amount: 0, // Premium için 0
          balanceAfter: user.credits,
          createdAt: DateTime.now(),
          description: 'Premium analiz - kredi düşmedi',
        ).toMap());
        
        print('✅ Premium kullanıcı - kredi düşmedi');
        return true;
      }
      
      // Kredi kontrolü
      if (user.credits <= 0) {
        print('❌ Yetersiz kredi');
        throw Exception('Yetersiz kredi');
      }
      
      final newCredits = user.credits - 1;
      
      // Kullanıcı kredisini düş
      await userRef.update({
        'credits': newCredits,
        'totalAnalysisCount': user.totalAnalysisCount + 1,
      });
      
      // Kullanım kaydı
      final transactionRef = _database.ref('credit_transactions').push();
      await transactionRef.set(CreditTransaction(
        id: transactionRef.key ?? '',
        userId: userId,
        type: TransactionType.usage,
        amount: -1,
        balanceAfter: newCredits,
        createdAt: DateTime.now(),
        description: analysisId != null 
            ? 'Analiz ID: $analysisId' 
            : 'Kredi kullanımı',
      ).toMap());
      
      print('✅ 1 kredi kullanıldı. Kalan: $newCredits');
      return true;
    } catch (e) {
      print('❌ Kredi kullanma hatası: $e');
      return false;
    }
  }
  
  // Premium abonelik ekle
  Future<bool> setPremium({
    required String userId,
    required int durationDays,
    String? productId,
    String? purchaseId,
  }) async {
    try {
      final expiresAt = DateTime.now().add(Duration(days: durationDays));
      final userRef = _database.ref('users/$userId');
      
      await userRef.update({
        'isPremium': true,
        'premiumExpiresAt': expiresAt.millisecondsSinceEpoch,
      });
      
      // Premium satın alma kaydı
      final transactionRef = _database.ref('credit_transactions').push();
      await transactionRef.set(CreditTransaction(
        id: transactionRef.key ?? '',
        userId: userId,
        type: TransactionType.purchase,
        amount: 0,
        balanceAfter: 0,
        createdAt: DateTime.now(),
        description: 'Premium abonelik - $durationDays gün',
        productId: productId,
        purchaseId: purchaseId,
      ).toMap());
      
      print('✅ Premium abonelik eklendi: $durationDays gün');
      return true;
    } catch (e) {
      print('❌ Premium ekleme hatası: $e');
      return false;
    }
  }
  
  // Kullanıcının işlem geçmişini getir
  Future<List<CreditTransaction>> getTransactionHistory(String userId) async {
    try {
      final ref = _database.ref('credit_transactions');
      final query = ref.orderByChild('userId').equalTo(userId);
      final snapshot = await query.get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final transactions = <CreditTransaction>[];
      
      data.forEach((key, value) {
        final transactionData = Map<String, dynamic>.from(value as Map);
        transactions.add(CreditTransaction.fromJson(key, transactionData));
      });
      
      // Tarihe göre sırala (yeniden eskiye)
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return transactions.take(50).toList();
    } catch (e) {
      print('❌ İşlem geçmişi hatası: $e');
      return [];
    }
  }
  
  // Kullanıcının dil tercihini güncelle
  Future<bool> updateUserLanguage(String userId, String languageCode) async {
    try {
      final userRef = _database.ref('users/$userId');
      await userRef.update({'preferredLanguage': languageCode});
      print('✅ Kullanıcı dil tercihi güncellendi: $languageCode');
      return true;
    } catch (e) {
      print('❌ Dil güncelleme hatası: $e');
      return false;
    }
  }
}