import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_functions/cloud_functions.dart';
import '../../providers/auth_provider.dart';
import '../../services/iap_service.dart';
import '../../l10n/app_localizations.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InAppPurchaseService _iapService = InAppPurchaseService();
  bool _isIapReady = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeIAP();
  }
  
  Future<void> _initializeIAP() async {
    // ✅ 1. Kullanıcı kontrolü ÖNCE
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        _showErrorDialog(loc.t('purchase_login_required'));
      }
      return;
    }

    debugPrint('✅ Kullanıcı doğrulandı: ${currentUser.uid}');
    
    await _iapService.initialize();
    
    // Satın alma başarı callback'i
    _iapService.onPurchaseSuccess = (PurchaseDetails purchaseDetails) {
      _handlePurchaseSuccess(purchaseDetails);
    };
    
    // Hata callback'i
    _iapService.onPurchaseError = (String error) {
      final loc = AppLocalizations.of(context)!;
      _showErrorDialog('${loc.t('purchase_error')} $error');
    };
    
    if (mounted) {
      setState(() {
        _isIapReady = _iapService.isAvailable;
      });
    }
    
    if (!_isIapReady && mounted) {
      final loc = AppLocalizations.of(context)!;
      _showErrorDialog(
        loc.t('purchase_service_unavailable')
      );
    }
  }
  
  Future<void> _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
    if (!mounted) return;
    
    final loc = AppLocalizations.of(context)!;
    final authProvider = context.read<AuthProvider>();
    
    // ✅ KRITIK: Kullanıcı ve token kontrolü
    final token = await authProvider.getValidToken();
    if (token == null) {
      debugPrint('❌ Token doğrulama başarısız');
      if (mounted) {
        _showErrorDialog(loc.t('session_expired'));
        // Kullanıcıyı login sayfasına yönlendir
        await authProvider.signOut();
      }
      return;
    }
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ Kullanıcı oturumu bulunamadı');
      if (mounted) {
        _showErrorDialog(loc.t('user_session_not_found'));
      }
      return;
    }
    
    debugPrint('✅ Token doğrulandı, satın alma işleniyor...');

    if (!mounted) return;
    
    final productId = purchaseDetails.productID;
    
    try {
      // Purchase token al (Google Play'den gelen doğrulama verisi)
      final purchaseToken = purchaseDetails.verificationData.serverVerificationData;
      
      if (purchaseToken.isEmpty) {
        throw Exception(loc.t('purchase_verification_missing'));
      }
      
      debugPrint('🔍 Purchase Token: ${purchaseToken.substring(0, 20)}...');
      debugPrint('🔍 Product ID: $productId');
      debugPrint('🔍 Purchase ID: ${purchaseDetails.purchaseID}');
      
      // Premium ürün mü kontrol et
      if (_iapService.isPremiumProduct(productId)) {
        debugPrint('🔍 Premium doğrulanıyor: $productId');
        
        // ⭐ FIX: Token'ı force refresh et
        await currentUser.getIdToken(true);
        debugPrint('✅ Token force refresh yapıldı');
        
        // ✅ Cloud Function: Premium doğrula ve ekle (region belirtildi)
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final callable = functions.httpsCallable(
          'verifyPurchaseAndSetPremium',
        );
        
        final result = await callable.call({
          'purchaseToken': purchaseToken,
          'productId': productId,
          'purchaseId': purchaseDetails.purchaseID ?? '',
          'platform': 'android',
        });
        
        debugPrint('✅ Premium doğrulama sonucu: ${result.data}');
        
        if (result.data['success'] == true && mounted) {
          // Kullanıcı verilerini yenile
          await authProvider.refreshUserModel();
          
          final premiumDays = result.data['premiumDays'];
          if (mounted) {
            _showSuccessDialog(
              loc.t('premium_activated_success').replaceAll('{days}', premiumDays.toString())
            );
          }
        } else {
          throw Exception(result.data['error'] ?? 'Premium activation failed');
        }
      } else {
        debugPrint('🔍 Kredi satın alma doğrulanıyor: $productId');
        
        // ⭐ FIX: Token'ı force refresh et
        await currentUser.getIdToken(true);
        debugPrint('✅ Token force refresh yapıldı');
        
        // ✅ Cloud Function: Kredi doğrula ve ekle (region belirtildi)
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final callable = functions.httpsCallable(
          'verifyPurchaseAndAddCredits',
        );
        
        final result = await callable.call({
          'purchaseToken': purchaseToken,
          'productId': productId,
          'purchaseId': purchaseDetails.purchaseID ?? '',
          'platform': 'android',
        });
        
        debugPrint('✅ Kredi doğrulama sonucu: ${result.data}');
        
        if (result.data['success'] == true && mounted) {
          // Kullanıcı verilerini yenile
          await authProvider.refreshUserModel();
          
          final creditsAdded = result.data['creditsAdded'];
          final newBalance = result.data['newBalance'];
          if (mounted) {
            _showSuccessDialog(
              loc.t('credits_added_success')
                .replaceAll('{credits}', creditsAdded.toString())
                .replaceAll('{balance}', newBalance.toString())
            );
          }
        } else {
          throw Exception(result.data['error'] ?? 'Credits adding failed');
        }
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Firebase Functions hatası: ${e.code} - ${e.message}');
      
      if (!mounted) return;
      
      String errorMessage = loc.t('purchase_verification_failed');
      
      if (e.code == 'unauthenticated') {
        errorMessage = loc.t('session_expired');
        // Kullanıcıyı çıkış yap
        await authProvider.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else if (e.code == 'already-exists') {
        errorMessage += loc.t('purchase_already_used');
      } else if (e.code == 'invalid-argument') {
        errorMessage += loc.t('purchase_invalid');
      } else if (e.code == 'permission-denied') {
        errorMessage = loc.t('permission_denied');
      } else {
        errorMessage += loc.t('contact_support').replaceAll('{code}', e.code);
      }
      
      _showErrorDialog(errorMessage);
    } catch (e) {
      debugPrint('❌ Satın alma doğrulama hatası: $e');
      
      if (mounted) {
        _showErrorDialog(loc.t('unexpected_error').replaceAll('{error}', e.toString()));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _iapService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('packages_title')),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: loc.t('credit_packages_tab')),
            Tab(text: loc.t('premium_subscription_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreditPackages(context),
          _buildPremiumPackages(context),
        ],
      ),
    );
  }

  Widget _buildCreditPackages(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();

    // Ürünler yüklenene kadar loading göster
    if (!_isIapReady) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              loc.t('loading_products'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Ürünler yüklenemedi ise hata göster
    if (_iapService.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              loc.t('products_load_failed'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await _iapService.loadProducts();
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: Text(loc.t('retry')),
            ),
          ],
        ),
      );
    }

    final packages = [
      {
        'productId': InAppPurchaseService.credit5,
        'credits': 5,
        'popular': false,
        'color': Colors.blue,
      },
      {
        'productId': InAppPurchaseService.credit10,
        'credits': 10,
        'popular': true,
        'color': Colors.purple,
      },
      {
        'productId': InAppPurchaseService.credit25,
        'credits': 25,
        'popular': false,
        'color': Colors.orange,
      },
      {
        'productId': InAppPurchaseService.credit50,
        'credits': 50,
        'popular': false,
        'color': Colors.green,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mevcut Kredi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.stars, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(
                  '${authProvider.credits}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  loc.t('current_credit'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            loc.t('credit_packages_title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.t('credit_packages_subtitle'),
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),

          // Kredi Paketleri
          ...packages.map((package) => _buildCreditPackageCard(
                context,
                productId: package['productId'] as String,
                credits: package['credits'] as int,
                isPopular: package['popular'] as bool,
                color: package['color'] as Color,
              )),
        ],
      ),
    );
  }

  Widget _buildCreditPackageCard(
    BuildContext context, {
    required String productId,
    required int credits,
    required bool isPopular,
    required Color color,
  }) {
    final loc = AppLocalizations.of(context)!;
    final totalCredits = credits;

    // Google Play'den ürün bilgisini al
    final product = _iapService.products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );

    // Dinamik fiyat ve para birimi (Google Play'den gelir)
    final price = product.price; // Örnek: "$4.99" veya "₺149,99"
    final rawPrice = product.rawPrice; // Örnek: 4.99
    final pricePerCredit = rawPrice / totalCredits;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? color : Colors.grey[300]!,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Popüler Badge
          if (isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  loc.t('most_popular'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // İkon ve Kredi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.stars, color: color, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        '$totalCredits',
                        style: TextStyle(
                          color: color,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        loc.t('credit'),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Detaylar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$credits ${loc.t('credit')} ${loc.t('credit_package').replaceAll('{count}', '')}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            price, // Dinamik fiyat (Google Play'den)
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${product.currencySymbol}${pricePerCredit.toStringAsFixed(2)}${loc.t('per_credit')})',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Satın Al Butonu
                ElevatedButton(
                  onPressed: _isIapReady
                      ? () => _handleCreditPurchase(productId)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(loc.t('buy_button')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPackages(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isPremium) {
      return _buildAlreadyPremium(context);
    }

    // Ürünler yüklenene kadar loading göster
    if (!_isIapReady) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              loc.t('loading_products'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Ürünler yüklenemedi ise hata göster
    if (_iapService.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              loc.t('products_load_failed'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await _iapService.loadProducts();
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: Text(loc.t('retry')),
            ),
          ],
        ),
      );
    }

    final packages = [
      {
        'productId': InAppPurchaseService.premiumMonthly,
        'duration': loc.t('monthly'),
        'days': 30,
        'color': Colors.blue,
        'icon': Icons.calendar_today,
      },
      {
        'productId': InAppPurchaseService.premium3Months,
        'duration': loc.t('3_months'),
        'days': 90,
        'color': Colors.purple,
        'icon': Icons.calendar_month,
        'popular': true,
        'discount': loc.t('discount_26'),
      },
      {
        'productId': InAppPurchaseService.premiumYearly,
        'duration': loc.t('yearly'),
        'days': 365,
        'color': Colors.amber,
        'icon': Icons.event_available,
        'discount': loc.t('discount_35'),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Özellikleri
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      loc.t('premium_membership_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFeature(loc.t('premium_feature_unlimited')),
                _buildFeature(loc.t('premium_feature_ad_free')),
                _buildFeature(loc.t('premium_feature_priority')),
                _buildFeature(loc.t('premium_feature_stats')),
                _buildFeature(loc.t('premium_feature_reports')),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            loc.t('premium_packages_title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.t('premium_packages_subtitle'),
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),

          // Premium Paketleri
          ...packages.map((package) => _buildPremiumPackageCard(
                context,
                productId: package['productId'] as String,
                duration: package['duration'] as String,
                days: package['days'] as int,
                color: package['color'] as Color,
                icon: package['icon'] as IconData,
                isPopular: package['popular'] as bool? ?? false,
                discount: package['discount'] as String?,
              )),
        ],
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPackageCard(
    BuildContext context, {
    required String productId,
    required String duration,
    required int days,
    required Color color,
    required IconData icon,
    required bool isPopular,
    String? discount,
  }) {
    final loc = AppLocalizations.of(context)!;

    // Google Play'den ürün bilgisini al
    final product = _iapService.products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );

    // Dinamik fiyat ve para birimi (Google Play'den gelir)
    final price = product.price; // Örnek: "$4.99" veya "₺899,00"
    final rawPrice = product.rawPrice; // Örnek: 4.99
    final monthlyPrice = rawPrice / (days / 30);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? color : Colors.grey[300]!,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  loc.t('most_popular'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            duration,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (discount != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green[300]!),
                              ),
                              child: Text(
                                discount,
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price, // Dinamik fiyat (Google Play'den)
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${product.currencySymbol}${monthlyPrice.toStringAsFixed(2)}${loc.t('per_month')}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isIapReady
                        ? () => _handlePremiumPurchase(productId)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      loc.t('premium_subscribe_button').replaceAll('{duration}', duration),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyPremium(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final userModel = authProvider.userModel;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.workspace_premium,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc.t('already_premium_title'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc.t('already_premium_message'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            if (userModel?.premiumExpiresAt != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey[700]),
                    const SizedBox(height: 8),
                    Text(
                      loc.t('expiry_date'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(userModel!.premiumExpiresAt!, loc),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreditPurchase(String productId) async {
    final loc = AppLocalizations.of(context)!;
    
    // ✅ Satın alma öncesi kullanıcı ve token kontrolü
    final authProvider = context.read<AuthProvider>();
    final token = await authProvider.getValidToken();
    
    if (token == null) {
      _showErrorDialog(loc.t('session_expired'));
      await authProvider.signOut();
      return;
    }

    if (!_isIapReady) {
      _showErrorDialog(loc.t('purchase_service_not_ready'));
      return;
    }
    
    // Loading göster
    _showLoadingDialog();
    
    try {
      final success = await _iapService.purchaseProduct(productId);
      
      // Loading kapat
      if (mounted) Navigator.of(context).pop();
      
      if (!success) {
        _showErrorDialog(loc.t('purchase_failed_retry'));
      }
    } catch (e) {
      // Loading kapat
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog(loc.t('error_occurred').replaceAll('{error}', e.toString()));
    }
  }

  Future<void> _handlePremiumPurchase(String productId) async {
    final loc = AppLocalizations.of(context)!;
    
    // ✅ Satın alma öncesi kullanıcı ve token kontrolü
    final authProvider = context.read<AuthProvider>();
    final token = await authProvider.getValidToken();
    
    if (token == null) {
      _showErrorDialog(loc.t('session_expired'));
      await authProvider.signOut();
      return;
    }

    if (!_isIapReady) {
      _showErrorDialog(loc.t('purchase_service_not_ready'));
      return;
    }
    
    // Loading göster
    _showLoadingDialog();
    
    try {
      final success = await _iapService.purchaseProduct(productId);
      
      // Loading kapat
      if (mounted) Navigator.of(context).pop();
      
      if (!success) {
        _showErrorDialog(loc.t('purchase_failed_retry'));
      }
    } catch (e) {
      // Loading kapat
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog(loc.t('error_occurred').replaceAll('{error}', e.toString()));
    }
  }
  
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  void _showErrorDialog(String message) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            Text(loc.t('error_title')),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('ok'), style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessDialog(String message) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green[700]),
            const SizedBox(width: 12),
            Text(loc.t('success_title')),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('ok'), style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations loc) {
    final months = [
      loc.t('month_january'), 
      loc.t('month_february'), 
      loc.t('month_march'), 
      loc.t('month_april'), 
      loc.t('month_may'), 
      loc.t('month_june'),
      loc.t('month_july'), 
      loc.t('month_august'), 
      loc.t('month_september'), 
      loc.t('month_october'), 
      loc.t('month_november'), 
      loc.t('month_december')
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
