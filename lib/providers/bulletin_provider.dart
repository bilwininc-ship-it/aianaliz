import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/bulletin_model.dart';

class BulletinProvider extends ChangeNotifier {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  List<BulletinModel> _bulletins = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<BulletinModel> get bulletins => _bulletins;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Kullanıcının bültenlerini getir
  Future<void> fetchUserBulletins(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final ref = _database.ref('bulletins');
      final query = ref.orderByChild('userId').equalTo(userId);
      final snapshot = await query.get();
      
      _bulletins = [];
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data.forEach((key, value) {
          final bulletinData = Map<String, dynamic>.from(value as Map);
          _bulletins.add(BulletinModel.fromJson(key, bulletinData));
        });
        
        // Tarihe göre sırala (yeniden eskiye)
        _bulletins.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      _isLoading = false;
      notifyListeners();
      print('✅ ${_bulletins.length} bülten yüklendi');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Bültenler yüklenirken hata oluştu: $e';
      notifyListeners();
      print('❌ Bülten yükleme hatası: $e');
    }
  }
  
  // Yeni bülten oluştur (görsel kaydedilmiyor)
  Future<String?> createBulletin({
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final ref = _database.ref('bulletins').push();
      await ref.set({
        'userId': userId,
        'status': 'pending', // pending, analyzing, completed, failed
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'analyzedAt': null,
        'analysis': null,
      });
      
      _isLoading = false;
      notifyListeners();
      
      print('✅ Yeni bülten oluşturuldu: ${ref.key}');
      return ref.key;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Bülten oluşturulurken hata oluştu: $e';
      notifyListeners();
      print('❌ Bülten oluşturma hatası: $e');
      return null;
    }
  }
  
  // Bülten durumunu güncelle
  Future<void> updateBulletinStatus(String bulletinId, String status) async {
    try {
      final ref = _database.ref('bulletins/$bulletinId');
      await ref.update({
        'status': status,
        'analyzedAt': status == 'completed' ? DateTime.now().millisecondsSinceEpoch : null,
      });
      
      // Listeyi güncelle
      final index = _bulletins.indexWhere((b) => b.id == bulletinId);
      if (index != -1) {
        _bulletins[index] = _bulletins[index].copyWith(
          status: status,
          analyzedAt: status == 'completed' ? DateTime.now() : null,
        );
        notifyListeners();
      }
      
      print('✅ Bülten durumu güncellendi: $status');
    } catch (e) {
      print('❌ Durum güncelleme hatası: $e');
    }
  }
  
  // Bülten analizini güncelle
  Future<void> updateBulletinAnalysis(
    String bulletinId,
    Map<String, dynamic> analysis,
  ) async {
    try {
      final ref = _database.ref('bulletins/$bulletinId');
      await ref.update({
        'status': 'completed',
        'analysis': analysis,
        'analyzedAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Listeyi güncelle
      final index = _bulletins.indexWhere((b) => b.id == bulletinId);
      if (index != -1) {
        _bulletins[index] = _bulletins[index].copyWith(
          status: 'completed',
          analysis: analysis,
          analyzedAt: DateTime.now(),
        );
        notifyListeners();
      }
      
      print('✅ Bülten analizi güncellendi');
    } catch (e) {
      print('❌ Analiz güncelleme hatası: $e');
      await updateBulletinStatus(bulletinId, 'failed');
    }
  }
  
  // Bülten detayını getir
  Future<BulletinModel?> getBulletin(String bulletinId) async {
    try {
      final ref = _database.ref('bulletins/$bulletinId');
      final snapshot = await ref.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return BulletinModel.fromJson(bulletinId, data);
      }
      return null;
    } catch (e) {
      _errorMessage = 'Bülten detayı alınırken hata oluştu: $e';
      notifyListeners();
      print('❌ Bülten detay hatası: $e');
      return null;
    }
  }
  
  // Bülteni sil
  Future<bool> deleteBulletin(String bulletinId) async {
    try {
      final ref = _database.ref('bulletins/$bulletinId');
      await ref.remove();
      
      _bulletins.removeWhere((b) => b.id == bulletinId);
      notifyListeners();
      
      print('✅ Bülten silindi: $bulletinId');
      return true;
    } catch (e) {
      _errorMessage = 'Bülten silinirken hata oluştu: $e';
      notifyListeners();
      print('❌ Bülten silme hatası: $e');
      return false;
    }
  }
  
  // Bülten stream'i dinle (realtime)
  Stream<BulletinModel?> getBulletinStream(String bulletinId) {
    return _database.ref('bulletins/$bulletinId').onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return BulletinModel.fromJson(bulletinId, data);
      }
      return null;
    });
  }
  
  // Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}