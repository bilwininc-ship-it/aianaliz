import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gizlilik Politikası'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              title: '1. Toplanan Bilgiler',
              content:
                  'AI Spor Pro aşağıdaki bilgileri toplar:\n\n'
                  '• Hesap bilgileri (ad, e-posta, şifre)\n'
                  '• Profil bilgileri ve fotoğraf\n'
                  '• Analiz geçmişi ve kupon verileri\n'
                  '• Ödeme bilgileri (şifreli)\n'
                  '• Uygulama kullanım verileri',
            ),
            _buildSection(
              context,
              title: '2. Bilgi Kullanımı',
              content:
                  'Toplanan bilgiler şu amaçlarla kullanılır:\n\n'
                  '• Hizmet sunumu ve iyileştirme\n'
                  '• Kullanıcı deneyimini kişiselleştirme\n'
                  '• Güvenlik ve dolandırıcılık önleme\n'
                  '• Müşteri desteği sağlama\n'
                  '• Yasal yükümlülükleri yerine getirme',
            ),
            _buildSection(
              context,
              title: '3. Bilgi Paylaşımı',
              content:
                  'Verileriniz şu durumlarda paylaşılabilir:\n\n'
                  '• Yasal zorunluluklar\n'
                  '• Hizmet sağlayıcılarla (ödeme, analitik)\n'
                  '• İş ortaklarıyla (anonim veriler)\n'
                  '• Kullanıcı onayı ile\n\n'
                  'Not: Kişisel verileriniz hiçbir zaman üçüncü taraflara satılmaz.',
            ),
            _buildSection(
              context,
              title: '4. Veri Güvenliği',
              content:
                  'Verilerinizin güvenliği için:\n\n'
                  '• Endüstri standardı şifreleme kullanılır\n'
                  '• Güvenli sunucularda saklanır\n'
                  '• Düzenli güvenlik denetimleri yapılır\n'
                  '• Erişim kontrolleri uygulanır',
            ),
            _buildSection(
              context,
              title: '5. Kullanıcı Hakları',
              content:
                  'KVKK kapsamında haklarınız:\n\n'
                  '• Verilerinize erişim hakkı\n'
                  '• Düzeltme talep etme hakkı\n'
                  '• Silme talep etme hakkı (unutulma hakkı)\n'
                  '• İtiraz etme hakkı\n'
                  '• Veri taşınabilirliği hakkı',
            ),
            _buildSection(
              context,
              title: '6. Çerezler',
              content:
                  'Uygulama, kullanıcı deneyimini iyileştirmek için çerezler ve benzeri teknolojiler kullanır. Çerez ayarlarınızı cihazınızdan yönetebilirsiniz.',
            ),
            _buildSection(
              context,
              title: '7. İletişim',
              content:
                  'Gizlilik ile ilgili sorularınız için:\n\n'
                  'E-posta: privacy@bilwin.inc\n'
                  'Web: https://bilwin.inc/privacy',
            ),
            const SizedBox(height: 24),
            Text(
              'Son Güncelleme: 1 Ocak 2025',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}