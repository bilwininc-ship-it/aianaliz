// Firebase Realtime Database için güncellendi - Firestore kaldırıldı

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final int credits; // Kullanıcı kredisi
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isPremium; // Premium abonelik durumu
  final DateTime? premiumExpiresAt;
  final int totalAnalysisCount; // Toplam yapılan analiz sayısı
  final String? ipAddress; // IP ban sistemi için
  final String? deviceId; // Cihaz ID (IP ban sistemi için)
  final bool isBanned; // Ban durumu
  final String preferredLanguage; // Tercih edilen dil (tr/en)
  
  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.credits = 3, // İlk kayıtta 3 kredi
    required this.createdAt,
    required this.lastLoginAt,
    this.isPremium = false,
    this.premiumExpiresAt,
    this.totalAnalysisCount = 0,
    this.ipAddress,
    this.deviceId,
    this.isBanned = false,
    this.preferredLanguage = 'tr', // Varsayılan dil Türkçe
  });
  
  // Realtime Database'den user oluştur
  factory UserModel.fromJson(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      credits: data['credits'] ?? 3,
      createdAt: data['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : DateTime.now(),
      lastLoginAt: data['lastLoginAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['lastLoginAt'] as int)
          : DateTime.now(),
      isPremium: data['isPremium'] ?? false,
      premiumExpiresAt: data['premiumExpiresAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['premiumExpiresAt'] as int)
          : null,
      totalAnalysisCount: data['totalAnalysisCount'] ?? 0,
      ipAddress: data['ipAddress'],
      deviceId: data['deviceId'],
      isBanned: data['isBanned'] ?? false,
      preferredLanguage: data['preferredLanguage'] ?? 'tr',
    );
  }
  
  // Realtime Database'e kaydet
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'credits': credits,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLoginAt': lastLoginAt.millisecondsSinceEpoch,
      'isPremium': isPremium,
      'premiumExpiresAt': premiumExpiresAt?.millisecondsSinceEpoch,
      'totalAnalysisCount': totalAnalysisCount,
      'ipAddress': ipAddress,
      'deviceId': deviceId,
      'isBanned': isBanned,
      'preferredLanguage': preferredLanguage,
    };
  }
  
  // Kredi ekle
  UserModel addCredits(int amount) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      credits: credits + amount,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      isPremium: isPremium,
      premiumExpiresAt: premiumExpiresAt,
      totalAnalysisCount: totalAnalysisCount,
      ipAddress: ipAddress,
      deviceId: deviceId,
      isBanned: isBanned,
      preferredLanguage: preferredLanguage,
    );
  }
  
  // Kredi düş
  UserModel useCredit() {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      credits: credits > 0 ? credits - 1 : 0,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      isPremium: isPremium,
      premiumExpiresAt: premiumExpiresAt,
      totalAnalysisCount: totalAnalysisCount + 1,
      ipAddress: ipAddress,
      deviceId: deviceId,
      isBanned: isBanned,
      preferredLanguage: preferredLanguage,
    );
  }
  
  // Premium yap
  UserModel setPremium(DateTime expiresAt) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      credits: credits,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      isPremium: true,
      premiumExpiresAt: expiresAt,
      totalAnalysisCount: totalAnalysisCount,
      ipAddress: ipAddress,
      deviceId: deviceId,
      isBanned: isBanned,
      preferredLanguage: preferredLanguage,
    );
  }
  
  // Premium kontrolü (süre dolmuş mu?)
  bool get isActivePremium {
    if (!isPremium || premiumExpiresAt == null) return false;
    return DateTime.now().isBefore(premiumExpiresAt!);
  }
  
  // Analiz yapabilir mi?
  bool get canAnalyze => isActivePremium || credits > 0;
}