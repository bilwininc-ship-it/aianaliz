import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _analysisComplete = true;
  bool _creditLow = true;
  bool _premiumExpiring = true;
  bool _promotions = false;
  bool _newsUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _analysisComplete = prefs.getBool('notif_analysis') ?? true;
      _creditLow = prefs.getBool('notif_credit') ?? true;
      _premiumExpiring = prefs.getBool('notif_premium') ?? true;
      _promotions = prefs.getBool('notif_promotions') ?? false;
      _newsUpdates = prefs.getBool('notif_news') ?? false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Ayarları'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Uygulama Bildirimleri'),
          _buildSwitchTile(
            icon: Icons.check_circle_outline,
            title: 'Analiz Tamamlandı',
            subtitle: 'Analiz tamamlandığında bildirim al',
            value: _analysisComplete,
            onChanged: (value) {
              setState(() => _analysisComplete = value);
              _saveSetting('notif_analysis', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.stars_outlined,
            title: 'Düşük Kredi Uyarısı',
            subtitle: 'Krediniz azaldığında bildirim al',
            value: _creditLow,
            onChanged: (value) {
              setState(() => _creditLow = value);
              _saveSetting('notif_credit', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Premium Bitiş Uyarısı',
            subtitle: 'Premium üyelik bitmeden önce hatırlat',
            value: _premiumExpiring,
            onChanged: (value) {
              setState(() => _premiumExpiring = value);
              _saveSetting('notif_premium', value);
            },
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('Pazarlama Bildirimleri'),
          _buildSwitchTile(
            icon: Icons.local_offer_outlined,
            title: 'Kampanyalar ve İndirimler',
            subtitle: 'Özel fırsatlardan haberdar ol',
            value: _promotions,
            onChanged: (value) {
              setState(() => _promotions = value);
              _saveSetting('notif_promotions', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.article_outlined,
            title: 'Haberler ve Güncellemeler',
            subtitle: 'Yeni özellikler ve güncellemeler',
            value: _newsUpdates,
            onChanged: (value) {
              setState(() => _newsUpdates = value);
              _saveSetting('notif_news', value);
            },
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bildirim ayarlarınızı istediğiniz zaman değiştirebilirsiniz.',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
    );
  }
}