import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bulletin_provider.dart';
import '../../services/rewarded_ad_service.dart';
import '../../widgets/common/countdown_timer_widget.dart';
import '../../models/bulletin_model.dart';
import '../../l10n/app_localizations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final RewardedAdService _rewardedAdService = RewardedAdService();
  
  bool _adLoading = false;
  bool _canWatchAd = false;
  Duration _remainingCooldown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadUserBulletins();
    _checkAdAvailability();
    _setupAdCallbacks();
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

