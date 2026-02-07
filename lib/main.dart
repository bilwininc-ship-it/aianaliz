import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'services/remote_config_service.dart';
import 'services/app_startup_service.dart';
import 'services/interstitial_ad_service.dart';
import 'services/rewarded_ad_service.dart';
import 'core/routes/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/bulletin_provider.dart';
import 'providers/language_provider.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Firebase initialize - SADECE BİR KEZ
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase başarıyla başlatıldı');
    } else {
      debugPrint('⚠️ Firebase zaten başlatılmış');
    }
  } catch (e) {
    debugPrint('❌ Firebase başlatma hatası: $e');
  }
  
  // ✅ Google Mobile Ads initialize
  try {
    await MobileAds.instance.initialize();
    debugPrint('✅ Google Mobile Ads başarıyla başlatıldı');
  } catch (e) {
    debugPrint('❌ Google Mobile Ads başlatma hatası: $e');
  }
  
  // ✅ ÖDÜLLÜ REKLAMI ÖNCEDEN YÜKLE (Kredi Kazan için)
  try {
    final rewardedAdService = RewardedAdService();
    await rewardedAdService.preloadAd();
    debugPrint('✅ Ödüllü reklam önceden yüklendi');
  } catch (e) {
    debugPrint('❌ Ödüllü reklam yükleme hatası: $e');
  }
  
  // ✅ GEÇIŞ REKLAMLARINI ÖNCEDEN YÜKLE (History ve Analiz için)
  try {
    final interstitialAdService = InterstitialAdService();
    
    // History ekranı reklamı
    await interstitialAdService.loadAd();
    debugPrint('✅ History reklamı önceden yüklendi');
    
    // Analiz ekranı reklamı (ayrı instance)
    await interstitialAdService.loadAnalysisAd();
    debugPrint('✅ Analiz reklamı önceden yüklendi');
  } catch (e) {
    debugPrint('❌ Geçiş reklamı yükleme hatası: $e');
  }
  
  // Remote Config initialize
  try {
    final remoteConfig = RemoteConfigService();
    await remoteConfig.initialize();
    
    // Debug modda config değerlerini göster
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      remoteConfig.printAllConfigs();
    }
  } catch (e) {
    debugPrint('❌ Remote Config hatası: $e');
  }
  
  // App Startup Service
  try {
    final appStartup = AppStartupService();
    await appStartup.initialize();
  } catch (e) {
    debugPrint('❌ App Startup hatası: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()..loadLanguage()),
        ChangeNotifierProvider(
          create: (context) {
            final authProvider = AuthProvider();
            final languageProvider = context.read<LanguageProvider>();
            
            // ✅ KÖPRÜ: AuthProvider ve LanguageProvider arasında bağlantı kur
            authProvider.onLanguageSync = (languageCode) {
              debugPrint('🔄 AuthProvider\'dan dil senkronizasyonu: $languageCode');
              languageProvider.syncLanguageFromFirebase(languageCode);
            };
            
            return authProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => BulletinProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp.router(
            title: 'AI Spor Pro',
            debugShowCheckedModeBanner: false,
            
            // Localization yapılandırması
            locale: languageProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}