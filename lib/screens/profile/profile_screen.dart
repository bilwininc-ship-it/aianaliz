import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../core/constants/app_constants.dart';
import '../../services/user_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _showLogoutDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.translate('logout_title')),
          content: Text(l10n.translate('logout_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.translate('cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final authProvider = context.read<AuthProvider>();
                await authProvider.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              child: Text(
                l10n.translate('logout'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = context.read<LanguageProvider>();
    final authProvider = context.read<AuthProvider>();
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.translate('select_your_language')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text('🇹🇷', style: TextStyle(fontSize: 32)),
                title: Text(l10n.translate('language_turkish')),
                trailing: languageProvider.isTurkish
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () async {
                  await languageProvider.changeLanguage(
                    'tr',
                    'TR',
                    userId: authProvider.user?.uid,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.translate('language_changed')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 32)),
                title: Text(l10n.translate('language_english')),
                trailing: languageProvider.isEnglish
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () async {
                  await languageProvider.changeLanguage(
                    'en',
                    'US',
                    userId: authProvider.user?.uid,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.translate('language_changed')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPlayStore(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    
    try {
      final uri = Uri.parse(AppConstants.PLAY_STORE_URL);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('page_could_not_open')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('page_could_not_open')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final user = authProvider.user;
    final userModel = authProvider.userModel;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile_title')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profil Başlık Kartı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: authProvider.isPremium
                    ? const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: authProvider.isPremium
                                    ? Colors.orange
                                    : Theme.of(context).primaryColor,
                              )
                            : null,
                      ),
                      if (authProvider.isPremium)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.workspace_premium,
                              color: Color(0xFFFFD700),
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ad Soyad
                  Text(
                    userModel?.displayName ?? l10n.translate('user_name'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // E-posta
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Premium Badge
                  if (authProvider.isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.translate('premium_member_badge'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // İstatistikler
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      l10n,
                      icon: Icons.analytics,
                      label: l10n.translate('total_analysis_stat'),
                      value: '${userModel?.totalAnalysisCount ?? 0}',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      l10n,
                      icon: Icons.stars,
                      label: l10n.translate('remaining_credits_stat'),
                      value: authProvider.isPremium
                          ? '∞'
                          : '${authProvider.credits}',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Hesap Bölümü
            _buildSectionTitle(context, l10n, l10n.translate('account_section')),
            _buildListTile(
              context,
              l10n,
              icon: Icons.person_outline,
              title: l10n.translate('account_info'),
              subtitle: l10n.translate('account_info_subtitle'),
              onTap: () {
                context.push('/account-settings');
              },
            ),
            _buildListTile(
              context,
              l10n,
              icon: authProvider.isPremium
                  ? Icons.workspace_premium
                  : Icons.stars_outlined,
              title: authProvider.isPremium
                  ? l10n.translate('premium_membership')
                  : l10n.translate('upgrade_to_premium'),
              subtitle: authProvider.isPremium
                  ? l10n.translate('premium_membership_subtitle')
                  : l10n.translate('upgrade_to_premium_subtitle'),
              trailing: authProvider.isPremium ? null : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                if (authProvider.isPremium) {
                  _showPremiumDetails(context, l10n, userModel);
                } else {
                  context.push('/subscription');
                }
              },
            ),
            _buildListTile(
              context,
              l10n,
              icon: Icons.history,
              title: l10n.translate('credit_history'),
              subtitle: l10n.translate('credit_history_subtitle'),
              onTap: () {
                context.push('/credit-history');
              },
            ),

            const SizedBox(height: 24),

            // Ayarlar Bölümü
            _buildSectionTitle(context, l10n, l10n.translate('settings_section')),
            _buildListTile(
              context,
              l10n,
              icon: Icons.notifications_outlined,
              title: l10n.translate('notifications'),
              subtitle: l10n.translate('notifications_subtitle'),
              onTap: () {
                context.push('/notification-settings');
              },
            ),
            _buildListTile(
              context,
              l10n,
              icon: Icons.language,
              title: l10n.translate('language_setting'),
              subtitle: languageProvider.isTurkish
                  ? l10n.translate('language_turkish')
                  : l10n.translate('language_english'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    languageProvider.isTurkish ? '🇹🇷' : '🇺🇸',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              onTap: () => _showLanguageDialog(context),
            ),

            const SizedBox(height: 24),

            // Hakkında Bölümü
            _buildSectionTitle(context, l10n, l10n.translate('about_section')),
            _buildListTile(
              context,
              l10n,
              icon: Icons.star_outline,
              title: l10n.translate('rate_app'),
              subtitle: l10n.translate('rate_app_subtitle'),
              onTap: () => _openPlayStore(context),
            ),
            _buildListTile(
              context,
              l10n,
              icon: Icons.description_outlined,
              title: l10n.translate('terms_of_service_title'),
              onTap: () => context.push('/terms'),
            ),
            _buildListTile(
              context,
              l10n,
              icon: Icons.privacy_tip_outlined,
              title: l10n.translate('privacy_policy_title'),
              onTap: () => context.push('/privacy'),
            ),
            _buildListTile(
              context,
              l10n,
              icon: Icons.info_outline,
              title: l10n.translate('app_about'),
              subtitle: '${l10n.translate('app_version')} ${AppConstants.APP_VERSION}',
              onTap: () => context.push('/about'),
            ),
            _buildListTile(
              context,
              l10n,
              icon: Icons.help_outline,
              title: l10n.translate('help_support'),
              onTap: () => context.push('/help'),
            ),

            const SizedBox(height: 24),

            // Çıkış Yap Butonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: Text(
                    l10n.translate('logout'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Footer
            Text(
              'Powered by ${AppConstants.COMPANY_NAME}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    AppLocalizations l10n, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
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
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, AppLocalizations l10n, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    AppLocalizations l10n, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showPremiumDetails(BuildContext context, AppLocalizations l10n, userModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.workspace_premium,
              color: Colors.amber[700],
            ),
            const SizedBox(width: 8),
            Text(l10n.translate('premium_details_title')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('premium_feature_1')),
            const SizedBox(height: 8),
            Text(l10n.translate('premium_feature_2')),
            const SizedBox(height: 8),
            Text(l10n.translate('premium_feature_3')),
            const SizedBox(height: 16),
            if (userModel?.premiumExpiresAt != null) ...[
              Text(
                '${l10n.translate('premium_expires')}: ${_formatDate(userModel!.premiumExpiresAt!)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.translate('ok')),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
