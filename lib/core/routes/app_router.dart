import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/credit_history_screen.dart';
import '../../screens/profile/account_settings_screen.dart';
import '../../screens/profile/notification_settings_screen.dart';
import '../../screens/analysis/analysis_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/upload/upload_screen.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../../screens/static/terms_of_service_screen.dart';
import '../../screens/static/privacy_policy_screen.dart';
import '../../screens/static/about_screen.dart';
import '../../screens/static/help_support_screen.dart';

final router = GoRouter(
  initialLocation: '/onboarding',
  
  // ✅ Firebase Auth ile oturum kontrolü
  refreshListenable: GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),
  
  // ✅ Yönlendirme mantığı
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;
    final currentLocation = state.matchedLocation;
    
    // Check onboarding status
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    // Public pages that don't require auth or onboarding
    final isPublicPage = currentLocation == '/terms' ||
        currentLocation == '/privacy' ||
        currentLocation == '/about' ||
        currentLocation == '/help';
    
    // If onboarding not completed and not on onboarding/public page
    if (!onboardingCompleted && currentLocation != '/onboarding' && !isPublicPage) {
      return '/onboarding';
    }
    
    // If onboarding completed but not logged in
    if (onboardingCompleted && !isLoggedIn && 
        currentLocation != '/login' && 
        currentLocation != '/register' && 
        !isPublicPage) {
      return '/login';
    }
    
    // If logged in and trying to access auth pages
    if (isLoggedIn && (currentLocation == '/login' || 
        currentLocation == '/register' || 
        currentLocation == '/onboarding')) {
      return '/home';
    }

    // Everything is fine
    return null;
  },
  
  routes: [
    // Onboarding Route
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    
    // Auth Routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    
    // Main Routes
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/credit-history',
      builder: (context, state) => const CreditHistoryScreen(),
    ),
    GoRoute(
      path: '/account-settings',
      builder: (context, state) => const AccountSettingsScreen(),
    ),
    GoRoute(
      path: '/notification-settings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) => const UploadScreen(),
    ),
    GoRoute(
      path: '/analysis/:bulletinId',
      builder: (context, state) {
        final bulletinId = state.pathParameters['bulletinId']!;
        final base64Image = state.extra as String?;
        return AnalysisScreen(
          bulletinId: bulletinId,
          base64Image: base64Image,
        );
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    
    // Static Pages (Giriş yapmadan erişilebilir)
    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsOfServiceScreen(),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => const HelpSupportScreen(),
    ),
  ],
);

// ✅ Firebase Auth Stream'i GoRouter ile entegre etmek için helper class
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}