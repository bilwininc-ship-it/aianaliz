import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../providers/auth_provider.dart';
import '../../services/rewarded_ad_service.dart';
import '../../l10n/app_localizations.dart';
import 'dart:async';

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
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _checkAdAvailability();
    _setupAdCallbacks();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _rewardedAdService.dispose();
    super.dispose();
  }

  /// Ad availability kontrolü
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

  /// Cooldown timer başlat (her saniye güncelle)
  void _startCooldownTimer() {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _checkAdAvailability();
      }
    });
  }

  /// Ad callback'lerini ayarla
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
          const SnackBar(
            content: Text('Reklam yüklenemedi. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    };

    _rewardedAdService.onRewardEarned = () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Tebrikler! Kredi hesabınıza eklendi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        _checkAdAvailability();
        // Kullanıcı verilerini yenile
        context.read<AuthProvider>().refreshUser();
      }
    };

    _rewardedAdService.onError = (message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    };
  }

  /// Ödüllü reklamı izle
  Future<void> _watchRewardedAd() async {
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı oturumu bulunamadı'),
          backgroundColor: Colors.red,
        ),
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

  /// Cooldown zamanını formatla
  String _formatCooldown(Duration duration) {
    if (duration.inSeconds <= 0) {
      return 'Hazır!';
    }
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours saat $minutes dakika';
    } else if (minutes > 0) {
      return '$minutes dakika $seconds saniye';
    } else {
      return '$seconds saniye';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userModel = authProvider.userModel;
    final loc = AppLocalizations.of(context)!;

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
                            : Icons.waving_hand,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          authProvider.isPremium 
                              ? loc.t('premium_member_welcome')
                              : loc.t('welcome_message'),
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
                    userModel?.displayName ?? userModel?.email ?? loc.t('user'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  if (!authProvider.isPremium) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${loc.t('remaining_text')} ${authProvider.credits} ${loc.t('you_have_analysis_rights')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ✅ ÖDÜLLÜ REKLAM KARTI (Sadece ücretsiz kullanıcılar için)
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
                      color: const Color(0xFF00C853).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ücretsiz Kredi Kazan! 🎁',
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
                      'Kısa bir reklam izle, kredi kazan!\nHer saatte bir yeni reklam izleyebilirsin.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Cooldown Sayacı
                    if (!_canWatchAd && _remainingCooldown.inSeconds > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sonraki reklam: ${_formatCooldown(_remainingCooldown)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    if (_canWatchAd || _remainingCooldown.inSeconds > 0)
                      const SizedBox(height: 16),
                    
                    // Reklam İzle Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _canWatchAd && !_adLoading 
                            ? _watchRewardedAd 
                            : null,
                        icon: _adLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              )
                            : Icon(
                                _canWatchAd 
                                    ? Icons.play_arrow 
                                    : Icons.lock_clock,
                                size: 24,
                              ),
                        label: Text(
                          _adLoading
                              ? 'Yükleniyor...'
                              : _canWatchAd
                                  ? 'Reklam İzle ve Kredi Kazan'
                                  : 'Bekleme Süresinde',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _canWatchAd 
                              ? const Color(0xFF00C853) 
                              : Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
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
                    loc.t('quick_actions_title'),
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
                          title: loc.t('new_analysis_action'),
                          subtitle: authProvider.canAnalyze ? loc.t('start_action') : loc.t('credit_required_action'),
                          color: Colors.blue,
                          onTap: () {
                            if (authProvider.canAnalyze) {
                              context.push('/upload');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(loc.t('purchase_credits_message')),
                                  action: SnackBarAction(
                                    label: loc.t('buy'),
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
                          title: loc.t('history_action'),
                          subtitle: loc.t('my_analyses'),
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
                          title: loc.t('get_credits_action'),
                          subtitle: loc.t('packages_action'),
                          color: Colors.orange,
                          onTap: () => context.push('/subscription'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.settings,
                          title: loc.t('settings_action'),
                          subtitle: loc.t('profile_action'),
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
                    loc.t('statistics_title'),
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
                          label: loc.t('total_analysis_count'),
                          value: '${userModel?.totalAnalysisCount ?? 0}',
                          color: Colors.blue,
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          context,
                          icon: Icons.stars_outlined,
                          label: loc.t('remaining_credits_count'),
                          value: authProvider.isPremium 
                              ? '∞ (${loc.t('premium_membership_status')})' 
                              : '${authProvider.credits}',
                          color: Colors.orange,
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          context,
                          icon: Icons.workspace_premium_outlined,
                          label: loc.t('membership_status_label'),
                          value: authProvider.isPremium 
                              ? loc.t('premium_membership_status')
                              : loc.t('standard_membership'),
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
                        Expanded(
                          child: Text(
                            loc.t('upgrade_to_premium_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${loc.t('premium_benefit_1')}\n'
                      '${loc.t('premium_benefit_2')}\n'
                      '${loc.t('premium_benefit_3')}',
                      style: const TextStyle(
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
                        child: Text(
                          loc.t('see_premium_packages'),
                          style: const TextStyle(
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
                    loc.t('footer_message'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.t('powered_by'),
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
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
                color: color.withValues(alpha: 0.7),
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
            color: color.withValues(alpha: 0.1),
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
