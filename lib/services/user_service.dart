import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../models/credit_transaction_model.dart';

class UserService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // IP ban kontrolü
  Future<bool> checkIpBan(String? ipAddress, String? deviceId) async {
    try {
      if (ipAddress == null && deviceId == null) {
        return false;
      }

      final usersRef = _database.ref('users');
      final snapshot = await usersRef.get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return false;
      }

      final usersData = Map<String, dynamic>.from(snapshot.value as Map);
      int accountCount = 0;
      
      usersData.forEach((uid, value) {
        final userData = Map<String, dynamic>.from(value as Map);
        final userIp = userData['ipAddress'];
        final userDeviceId = userData['deviceId'];
        
        if ((ipAddress != null && userIp == ipAddress) ||
            (deviceId != null && userDeviceId == deviceId)) {
          accountCount++;
        }
      });
      
      if (accountCount >= 1) {
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Kullanıcıyı yasakla
  Future<void> banUser(String uid) async {
    try {
      final userRef = _database.ref('users/$uid');
      await userRef.update({'isBanned': true});
    } catch (e) {
      // Silent fail
    }
  }
  
  // Kullanıcı oluştur veya güncelle (KREDİ KORUMA İLE)
  Future<void> createOrUpdateUser(UserModel user) async {
    try {
      final ref = _database.ref('users/${user.uid}');
      final snapshot = await ref.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final existingData = Map<String, dynamic>.from(snapshot.value as Map);
        final existingUser = UserModel.fromJson(user.uid, existingData);
        
        await ref.update({
          'lastLoginAt': user.lastLoginAt.millisecondsSinceEpoch,
          'displayName': user.displayName ?? existingUser.displayName,
          'photoUrl': user.photoUrl ?? existingUser.photoUrl,
          'email': user.email,
        });
      } else {
        await ref.set(user.toMap());
      }
    } catch (e) {
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
      
      await userRef.update({'credits': newCredits});
      
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
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // ✅ YENİ: Puanlama Bonusu (+2 Kredi) - GÜVENLİK KİLİDİ
  Future<bool> addRatingBonus(String userId) async {
    try {
      final userRef = _database.ref('users/$userId');
      final snapshot = await userRef.get();
      
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Kullanıcı bulunamadı');
      }
      
      final userData = Map<String, dynamic>.from(snapshot.value as Map);
      final user = UserModel.fromJson(userId, userData);
      
      // ⚠️ GÜVENLIK: Daha önce puanlama bonusu almış mı kontrol et
      if (user.hasRatedApp) {
        return false; // Zaten bonus almış, tekrar veremeyiz
      }
      
      final newCredits = user.credits + 2;
      
      // Atomik güncelleme: hasRatedApp + credits birlikte
      await userRef.update({
        'credits': newCredits,
        'hasRatedApp': true,
      });
      
      // İşlem kaydı
      final transactionRef = _database.ref('credit_transactions').push();
      await transactionRef.set(CreditTransaction(
        id: transactionRef.key ?? '',
        userId: userId,
        type: TransactionType.bonus,
        amount: 2,
        balanceAfter: newCredits,
        createdAt: DateTime.now(),
        description: 'Uygulamayı puanlama bonusu',
      ).toMap());
      
      return true;
    } catch (e) {
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
      
      if (user.isActivePremium) {
        await userRef.update({
          'totalAnalysisCount': user.totalAnalysisCount + 1,
        });
        
        final transactionRef = _database.ref('credit_transactions').push();
        await transactionRef.set(CreditTransaction(
          id: transactionRef.key ?? '',
          userId: userId,
          type: TransactionType.usage,
          amount: 0,
          balanceAfter: user.credits,
          createdAt: DateTime.now(),
          description: 'Premium analiz - kredi düşmedi',
        ).toMap());
        
        return true;
      }
      
      if (user.credits <= 0) {
        throw Exception('Yetersiz kredi');
      }
      
      final newCredits = user.credits - 1;
      
      await userRef.update({
        'credits': newCredits,
        'totalAnalysisCount': user.totalAnalysisCount + 1,
      });
      
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
      
      return true;
    } catch (e) {
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
      
      return true;
    } catch (e) {
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
      
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return transactions.take(50).toList();
    } catch (e) {
      return [];
    }
  }
  
  // Kullanıcının dil tercihini güncelle
  Future<bool> updateUserLanguage(String userId, String languageCode) async {
    try {
      final userRef = _database.ref('users/$userId');
      await userRef.update({'preferredLanguage': languageCode});
      return true;
    } catch (e) {
      return false;
    }
  }
}
