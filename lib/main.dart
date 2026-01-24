import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'services/remote_config_service.dart';
import 'services/app_startup_service.dart';
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BulletinProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..loadLanguage()),
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