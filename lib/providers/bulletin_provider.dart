import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
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
      
      // ⚡ ANR önleme: 10 saniye timeout
      final snapshot = await query.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Bülten yükleme zaman aşımı');
          throw TimeoutException('Bülten yükleme 10 saniyeyi aştı');
        },
      );
      
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
      debugPrint('✅ ${_bulletins.length} bülten yüklendi');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Bültenler yüklenirken hata oluştu: $e';
      notifyListeners();
      debugPrint('❌ Bülten yükleme hatası: $e');
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
      
      // ⚡ ANR önleme: 8 saniye timeout
      await ref.set({
        'userId': userId,
        'status': 'pending', // pending, analyzing, completed, failed
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'analyzedAt': null,
        'analysis': null,
      }).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⚠️ Bülten oluşturma zaman aşımı');
          throw TimeoutException('Bülten oluşturma 8 saniyeyi aştı');
        },
      );
      
      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ Yeni bülten oluşturuldu: ${ref.key}');
      return ref.key;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Bülten oluşturulurken hata oluştu: $e';
      notifyListeners();
      debugPrint('❌ Bülten oluşturma hatası: $e');
      return null;
    }
  }
  
  // Bülten durumunu güncelle
  Future<void> updateBulletinStatus(String bulletinId, String status) async {
    try {
      final ref = _database.ref('bulletins/$bulletinId');
      
      // ⚡ ANR önleme: 5 saniye timeout
      await ref.update({
        'status': status,
        'analyzedAt': status == 'completed' ? DateTime.now().millisecondsSinceEpoch : null,
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Bülten durumu güncelleme zaman aşımı');
          throw TimeoutException('Bülten durumu güncelleme 5 saniyeyi aştı');
        },
      );
      
      // Listeyi güncelle
      final index = _bulletins.indexWhere((b) => b.id == bulletinId);
      if (index != -1) {
        _bulletins[index] = _bulletins[index].copyWith(
          status: status,
          analyzedAt: status == 'completed' ? DateTime.now() : null,
        );
        notifyListeners();
      }
      
      debugPrint('✅ Bülten durumu güncellendi: $status');
    } catch (e) {
      debugPrint('❌ Durum güncelleme hatası: $e');
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
      
      debugPrint('✅ Bülten analizi güncellendi');
    } catch (e) {
      debugPrint('❌ Analiz güncelleme hatası: $e');
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
      debugPrint('❌ Bülten detay hatası: $e');
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
      
      debugPrint('✅ Bülten silindi: $bulletinId');
      return true;
    } catch (e) {
      _errorMessage = 'Bülten silinirken hata oluştu: $e';
      notifyListeners();
      debugPrint('❌ Bülten silme hatası: $e');
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