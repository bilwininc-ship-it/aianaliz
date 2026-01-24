import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/rewarded_ad_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RewardedAdService _rewardedAdService = RewardedAdService();
  bool _adLoading = false;
  bool _canWatchAd = false;
  Duration _remainingCooldown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkAdAvailability();
    _setupAdCallbacks();
  }

  Future<void> _checkAdAvailability() async {
    final canWatch = await _rewardedAdService.canWatchAd();
    final remaining = await _rewardedAdService.getRemainingCooldown();
    
    setState(() {
      _canWatchAd = canWatch;
      _remainingCooldown = remaining;
    });
    
    // Eğer izlenebilirse reklamı yükle
    if (canWatch && !_rewardedAdService.isAdLoaded) {
      _rewardedAdService.loadAd();
    }
  }

  void _setupAdCallbacks() {
    _rewardedAdService.onAdLoaded = () {
      if (mounted) {
        setState(() {
          _adLoading = false;
        });
      }
    };

    _rewardedAdService.onAdFailedToLoad = () {
      if (mounted) {
        setState(() {
          _adLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reklam yüklenemedi')),
        );
      }
    };

    _rewardedAdService.onRewardEarned = () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Tebrikler! 1 kredi kazandınız'),
            backgroundColor: Colors.green,
          ),
        );
        _checkAdAvailability();
        // Refresh user data
        context.read<AuthProvider>().refreshUser();
      }
    };

    _rewardedAdService.onError = (message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    };
  }

  Future<void> _watchRewardedAd() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı girişi yapılmamış')),
      );
      return;
    }

    if (!_rewardedAdService.isAdLoaded) {
      setState(() {
        _adLoading = true;
      });
      await _rewardedAdService.loadAd();
    } else {
      await _rewardedAdService.showAd(userId);
    }
  }

  @override
  void dispose() {
    _rewardedAdService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userModel = authProvider.userModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Spor Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        authProvider.isPremium 
                            ? Icons.workspace_premium 
                            : Icons.waving_hand,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          authProvider.isPremium 
                              ? 'Premium Üye'
                              : 'Hoş Geldiniz',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userModel?.displayName ?? userModel?.email ?? 'Kullanıcı',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  if (!authProvider.isPremium) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Kalan ${authProvider.credits} analiz hakkınız var',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ✅ YENİ: Ödüllü Reklam Kartı (Sadece premium olmayan kullanıcılara göster)
            if (!authProvider.isPremium)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF64DD17)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ücretsiz Kredi Kazan!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kısa bir reklam izleyerek 1 kredi kazan\n24 saatte bir izleyebilirsin',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _canWatchAd && !_adLoading ? _watchRewardedAd : null,
                        icon: _adLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          _canWatchAd
                              ? (_adLoading ? 'Yükleniyor...' : 'Reklam İzle')
                              : '${_remainingCooldown.inHours}s ${_remainingCooldown.inMinutes.remainder(60)}dk sonra',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hızlı İşlemler',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.analytics,
                          title: 'Yeni Analiz',
                          subtitle: '${authProvider.canAnalyze ? "Başlat" : "Kredi Gerekli"}',
                          color: Colors.blue,
                          onTap: () {
                            if (authProvider.canAnalyze) {
                              context.push('/upload');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Analiz için kredi satın alın'),
                                  action: SnackBarAction(
                                    label: 'Satın Al',
                                    onPressed: () => context.push('/subscription'),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.history,
                          title: 'Geçmiş',
                          subtitle: 'Analizlerim',
                          color: Colors.purple,
                          onTap: () => context.push('/history'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.stars,
                          title: 'Kredi Al',
                          subtitle: 'Paketler',
                          color: Colors.orange,
                          onTap: () => context.push('/subscription'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.settings,
                          title: 'Ayarlar',
                          subtitle: 'Profil',
                          color: Colors.grey,
                          onTap: () => context.push('/profile'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İstatistikler',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildStatRow(
                          context,
                          icon: Icons.analytics_outlined,
                          label: 'Toplam Analiz',
                          value: '${userModel?.totalAnalysisCount ?? 0}',
                          color: Colors.blue,
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          context,
                          icon: Icons.stars_outlined,
                          label: 'Kalan Kredi',
                          value: authProvider.isPremium 
                              ? '∞ (Premium)' 
                              : '${authProvider.credits}',
                          color: Colors.orange,
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          context,
                          icon: Icons.workspace_premium_outlined,
                          label: 'Üyelik Durumu',
                          value: authProvider.isPremium 
                              ? 'Premium' 
                              : 'Standart',
                          color: authProvider.isPremium 
                              ? Colors.amber 
                              : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (!authProvider.isPremium)
              Container(
                margin: const EdgeInsets.all(16),
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
                        const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Premium\'a Geç',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '✨ Sınırsız analiz\n'
                      '✨ Reklamsız deneyim\n'
                      '✨ Öncelikli destek',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.push('/subscription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Premium Paketleri Gör',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'AI Spor Pro ile maç tahminlerinizi\nprofesyonel analiz edin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Powered by Bilwin.inc',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 15,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
