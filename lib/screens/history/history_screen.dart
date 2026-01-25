import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bulletin_provider.dart';
import '../../services/rewarded_ad_service.dart';
import '../../services/interstitial_ad_service.dart';
import '../../widgets/common/countdown_timer_widget.dart';
import '../../models/bulletin_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final RewardedAdService _rewardedAdService = RewardedAdService();
  final InterstitialAdService _interstitialAdService = InterstitialAdService();
  
  bool _adLoading = false;
  bool _canWatchAd = false;
  Duration _remainingCooldown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadUserBulletins();
    _checkAdAvailability();
    _setupAdCallbacks();
    _loadInterstitialAd();
  }

  /// Kullanıcının bulletin'lerini yükle
  Future<void> _loadUserBulletins() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid;
    
    if (userId != null) {
      await context.read<BulletinProvider>().fetchUserBulletins(userId);
    }
  }

  /// Ödüllü reklam için kontrol
  Future<void> _checkAdAvailability() async {
    final canWatch = await _rewardedAdService.canWatchAd();
    final remaining = await _rewardedAdService.getRemainingCooldown();
    
    if (mounted) {
      setState(() {
        _canWatchAd = canWatch;
        _remainingCooldown = remaining;
      });
    }
    
    // Eğer izlenebilirse reklamı yükle
    if (canWatch && !_rewardedAdService.isAdLoaded) {
      _rewardedAdService.loadAd();
    }
  }

  /// Interstitial reklamı önceden yükle
  Future<void> _loadInterstitialAd() async {
    final authProvider = context.read<AuthProvider>();
    
    // ✅ PREMIUM KORUMASI: Premium üyeyse reklam yükleme
    if (authProvider.isPremium) {
      debugPrint('🎖️ Premium üye - Interstitial ad yüklenmiyor');
      return;
    }

    // Threshold kontrolü yap
    final canShow = await _interstitialAdService.canShowHistoryAd();
    if (canShow && !_interstitialAdService.isAdLoaded) {
      await _interstitialAdService.loadAd();
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

    // Interstitial ad callbacks
    _interstitialAdService.onAdClosed = () {
      // Reklam kapandıktan sonra yeni bir tane yükle
      _loadInterstitialAd();
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

  /// 🎯 KRITIK: Bulletin detayına git (Interstitial Ad ile)
  Future<void> _navigateToBulletinDetail(BulletinModel bulletin) async {
    final authProvider = context.read<AuthProvider>();
    
    // ✅ PREMIUM KORUMASI: Premium üyeyse reklam gösterme
    if (authProvider.isPremium) {
      debugPrint('🎖️ Premium üye - Reklam atlandı');
      context.push('/analysis/${bulletin.id}');
      return;
    }

    // ⚡ FAIL-SAFE: Reklam yüklenmemişse veya gösteremezse, kullanıcıyı bekletme
    try {
      debugPrint('🎬 Interstitial ad gösteriliyor...');
      
      // Reklamı göstermeyi dene
      final adShown = await _interstitialAdService.showAd();
      
      if (adShown) {
        debugPrint('✅ Interstitial ad gösterildi');
      } else {
        debugPrint('⚠️ Interstitial ad gösterilemedi (threshold veya yükleme sorunu)');
      }
    } catch (e) {
      debugPrint('❌ Interstitial ad hatası: $e');
    } finally {
      // ✅ HER HALÜKARDA DETAYA GİT (Kullanıcı dostu!)
      if (mounted) {
        debugPrint('📄 Bulletin detayına yönlendiriliyor: ${bulletin.id}');
        context.push('/analysis/${bulletin.id}');
      }
    }
  }

  @override
  void dispose() {
    _rewardedAdService.dispose();
    _interstitialAdService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final bulletinProvider = context.watch<BulletinProvider>();
    final userModel = authProvider.userModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş Analizler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserBulletins,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kullanıcı Bilgi Kartı
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
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
                              : Icons.history,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            authProvider.isPremium 
                                ? 'Premium Üye'
                                : 'Analizlerim',
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.analytics, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Toplam ${userModel?.totalAnalysisCount ?? 0} analiz',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        if (!authProvider.isPremium)
                          Text(
                            '${authProvider.credits} kredi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ✅ Ödüllü Reklam Kartı (Sadece premium olmayan kullanıcılara göster)
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
                        color: Colors.green.withValues(alpha: 0.3),
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
                        'Kısa bir reklam izleyerek 1 kredi kazan',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _canWatchAd && !_adLoading ? _watchRewardedAd : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _adLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.green,
                                  ),
                                )
                              : _canWatchAd
                                  ? const Text(
                                      'Reklam İzle',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  : CountdownTimerWidget(
                                      initialDuration: _remainingCooldown,
                                      textStyle: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      icon: Icons.timer,
                                      iconColor: Colors.orange,
                                      onComplete: () {
                                        if (mounted) {
                                          _checkAdAvailability();
                                        }
                                      },
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),

              // Bulletin Listesi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geçmiş Analizler',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Loading
                    if (bulletinProvider.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    
                    // Error
                    if (bulletinProvider.errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                bulletinProvider.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Empty
                    if (!bulletinProvider.isLoading && 
                        bulletinProvider.errorMessage == null &&
                        bulletinProvider.bulletins.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              const Icon(Icons.inbox, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'Henüz analiz yapmadınız',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/upload'),
                                icon: const Icon(Icons.add),
                                label: const Text('İlk Analizinizi Yapın'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Bulletin Cards
                    if (!bulletinProvider.isLoading && bulletinProvider.bulletins.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bulletinProvider.bulletins.length,
                        itemBuilder: (context, index) {
                          final bulletin = bulletinProvider.bulletins[index];
                          return _buildBulletinCard(bulletin);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Premium Banner
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
      ),
    );
  }

  Widget _buildBulletinCard(BulletinModel bulletin) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (bulletin.status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Tamamlandı';
        break;
      case 'analyzing':
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
        statusText = 'Analiz Ediliyor';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Başarısız';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Bekliyor';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: bulletin.status == 'completed' 
            ? () => _navigateToBulletinDetail(bulletin)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (bulletin.status == 'completed')
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(bulletin.createdAt),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              if (bulletin.analyzedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Analiz: ${_formatDate(bulletin.analyzedAt!)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
