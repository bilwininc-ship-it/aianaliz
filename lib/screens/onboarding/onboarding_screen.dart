import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      context.go('/login');
    }
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final languageProvider = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Dil Seçici
          PopupMenuButton<String>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  languageProvider.isTurkish ? '🇹🇷' : '🇬🇧',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
            onSelected: (String languageCode) {
              if (languageCode == 'tr') {
                languageProvider.changeLanguage('tr', 'TR');
              } else {
                languageProvider.changeLanguage('en', 'US');
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'tr',
                child: Row(
                  children: [
                    const Text('🇹🇷', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(loc.t('turkish')),
                    if (languageProvider.isTurkish)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.check, size: 18, color: Colors.green),
                      ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'en',
                child: Row(
                  children: [
                    const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(loc.t('english')),
                    if (languageProvider.isEnglish)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.check, size: 18, color: Colors.green),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_currentPage < 3)
            TextButton(
              onPressed: _skipOnboarding,
              child: Text(
                languageProvider.isTurkish ? 'Atla' : 'Skip',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildPage(
                  context,
                  icon: Icons.sports_soccer,
                  title: languageProvider.isTurkish
                      ? 'AI Spor Pro\'ya Hoş Geldiniz'
                      : 'Welcome to AI Spor Pro',
                  description: languageProvider.isTurkish
                      ? 'Yapay zeka destekli spor analizi ile maç tahminlerinizi profesyonel düzeye taşıyın'
                      : 'Take your match predictions to a professional level with AI-powered sports analysis',
                  color: Theme.of(context).primaryColor,
                ),
                _buildPage(
                  context,
                  icon: Icons.photo_camera,
                  title: languageProvider.isTurkish
                      ? 'Kolay Analiz'
                      : 'Easy Analysis',
                  description: languageProvider.isTurkish
                      ? 'Bülteninizin fotoğrafını çekin veya yükleyin, AI anında analiz etsin'
                      : 'Take or upload a photo of your bulletin, AI analyzes it instantly',
                  color: Colors.blue,
                ),
                _buildPage(
                  context,
                  icon: Icons.insights,
                  title: languageProvider.isTurkish
                      ? 'Detaylı Raporlar'
                      : 'Detailed Reports',
                  description: languageProvider.isTurkish
                      ? 'Her maç için kapsamlı istatistikler ve yapay zeka önerileri alın'
                      : 'Get comprehensive statistics and AI recommendations for each match',
                  color: Colors.orange,
                ),
                _buildPage(
                  context,
                  icon: Icons.workspace_premium,
                  title: languageProvider.isTurkish
                      ? 'Premium Avantajlar'
                      : 'Premium Benefits',
                  description: languageProvider.isTurkish
                      ? 'Sınırsız analiz, reklamsız deneyim ve öncelikli destek'
                      : 'Unlimited analysis, ad-free experience and priority support',
                  color: Colors.amber,
                ),
              ],
            ),
          ),
          // Page Indicators
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          // Next/Get Started Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentPage < 3
                      ? (languageProvider.isTurkish ? 'İleri' : 'Next')
                      : (languageProvider.isTurkish ? 'Başlayalım' : 'Get Started'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: color,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
