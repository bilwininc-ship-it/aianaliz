import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import './google_ads_service.dart'; // ✅ Google Ads entegrasyonu

class InAppPurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final GoogleAdsService _googleAds = GoogleAdsService(); // ✅ Google Ads servisi
  
  // Product ID'leri - Google Play Console'da tanımlanacak
  static const String credit5 = 'credits_5';
  static const String credit10 = 'credits_10';
  static const String credit25 = 'credits_25';
  static const String credit50 = 'credits_50';
  static const String premiumMonthly = 'premium_monthly';
  static const String premium3Months = 'premium_3months';
  static const String premiumYearly = 'premium_yearly';
  
  // Tüm ürün ID'leri
  static const Set<String> _productIds = {
    credit5,
    credit10,
    credit25,
    credit50,
    premiumMonthly,
    premium3Months,
    premiumYearly,
  };
  
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  
  // Getters
  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  
  // Satın alma callback'i
  Function(PurchaseDetails)? onPurchaseSuccess;
  Function(String)? onPurchaseError;
  
  // Initialize
  Future<void> initialize() async {
    try {
      // Android için ekstra ayarlar
      // NOT: enablePendingPurchases() artık gerekli değil, otomatik aktif
      if (Platform.isAndroid) {
        final InAppPurchaseAndroidPlatformAddition androidAddition =
            _inAppPurchase
                .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        
        // Android platform eklentisi hazır
        debugPrint('Android IAP platform eklentisi yüklendi');
      }
      
      // Store bağlantısını kontrol et
      _isAvailable = await _inAppPurchase.isAvailable();
      
      if (!_isAvailable) {
        debugPrint('❌ In-App Purchase kullanılamıyor');
        return;
      }
      
      // Ürünleri yükle
      await loadProducts();
      
      // Purchase stream'i dinle
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription.cancel(),
        onError: (error) {
          debugPrint('❌ Purchase stream error: $error');
          onPurchaseError?.call(error.toString());
        },
      );
      
      debugPrint('✅ In-App Purchase başlatıldı');
    } catch (e) {
      debugPrint('❌ In-App Purchase başlatma hatası: $e');
    }
  }
  
  // Ürünleri yükle
  Future<void> loadProducts() async {
    try {
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(_productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Bulunamayan ürünler: ${response.notFoundIDs}');
      }
      
      if (response.error != null) {
        debugPrint('❌ Ürün yükleme hatası: ${response.error}');
        return;
      }
      
      _products = response.productDetails;
      debugPrint('✅ ${_products.length} ürün yüklendi');
      
      // Ürünleri log'la
      for (var product in _products) {
        debugPrint('  - ${product.id}: ${product.title} - ${product.price}');
      }
    } catch (e) {
      debugPrint('❌ Ürün yükleme exception: $e');
    }
  }
  
  // Satın alma başlat
  Future<bool> purchaseProduct(String productId) async {
    if (!_isAvailable) {
      onPurchaseError?.call('In-App Purchase kullanılamıyor');
      return false;
    }
    
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Ürün bulunamadı: $productId'),
    );
    
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    _purchasePending = true;
    
    try {
      // Premium abonelikler için
      if (productId == premiumMonthly || productId == premium3Months || productId == premiumYearly) {
        return await _inAppPurchase.buyNonConsumable(
          purchaseParam: purchaseParam,
        );
      }
      // Kredi paketleri için
      else {
        return await _inAppPurchase.buyConsumable(
          purchaseParam: purchaseParam,
        );
      }
    } catch (e) {
      debugPrint('❌ Satın alma hatası: $e');
      _purchasePending = false;
      onPurchaseError?.call(e.toString());
      return false;
    }
  }
  
  // Purchase güncellemelerini işle
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _purchasePending = false;
          onPurchaseError?.call(purchaseDetails.error?.message ?? 'Bilinmeyen hata');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Satın alma başarılı
          _purchasePending = false;
          onPurchaseSuccess?.call(purchaseDetails);
          
          // ✅ Google Ads conversion tracking
          _trackPurchaseToGoogleAds(purchaseDetails);
        }
        
        // Satın almayı tamamla
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }
  
  // Satın almaları geri yükle
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('✅ Satın almalar geri yüklendi');
    } catch (e) {
      debugPrint('❌ Geri yükleme hatası: $e');
      onPurchaseError?.call(e.toString());
    }
  }
  
  // Kredi miktarını product ID'den al
  int getCreditAmountFromProduct(String productId) {
    switch (productId) {
      case credit5:
        return 5;
      case credit10:
        return 10;
      case credit25:
        return 25;
      case credit50:
        return 50;
      default:
        return 0;
    }
  }
  
  // Premium süresini product ID'den al (gün)
  int getPremiumDaysFromProduct(String productId) {
    switch (productId) {
      case premiumMonthly:
        return 30;
      case premium3Months:
        return 90;
      case premiumYearly:
        return 365;
      default:
        return 0;
    }
  }
  
  // Premium ürün mü?
  bool isPremiumProduct(String productId) {
    return productId == premiumMonthly || productId == premium3Months || productId == premiumYearly;
  }
  
  // ✅ Google Ads'e satın alma bilgisi gönder
  Future<void> _trackPurchaseToGoogleAds(PurchaseDetails purchase) async {
    try {
      final productId = purchase.productID;
      
      // Ürün fiyatını hesapla (örnek değerler - gerçek fiyatlar için product details kullanılabilir)
      double value = 0.0;
      String currency = 'TRY'; // Türk Lirası varsayılan
      
      // Kredi paketleri fiyatları
      if (productId == credit5) {
        value = 4.99;
      } else if (productId == credit10) {
        value = 9.99;
      } else if (productId == credit25) {
        value = 19.99;
      } else if (productId == credit50) {
        value = 39.99;
      }
      // Premium paketler fiyatları
      else if (productId == premiumMonthly) {
        value = 29.99;
      } else if (productId == premium3Months) {
        value = 79.99;
      } else if (productId == premiumYearly) {
        value = 199.99;
      }
      
      // Google Ads'e conversion bildir
      await _googleAds.trackPurchase(
        productId: productId,
        value: value,
        currency: currency,
      );
      
      debugPrint('✅ Google Ads conversion tracked: $productId ($value $currency)');
    } catch (e) {
      debugPrint('❌ Google Ads tracking hatası: $e');
      // Hata olsa bile satın alma işlemine devam et
    }
  }
  
  // Temizle
  void dispose() {
    _subscription.cancel();
  }
}