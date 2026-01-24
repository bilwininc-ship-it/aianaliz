import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Sözleşmesi'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              title: '1. Hizmet Tanımı',
              content:
                  'AI Spor Pro, kullanıcıların spor bahis kuponlarını analiz etmelerine yardımcı olan bir mobil uygulamadır. Uygulama, yapay zeka destekli analizler sunarak kullanıcılara karar verme süreçlerinde destek sağlar.',
            ),
            _buildSection(
              context,
              title: '2. Kullanım Koşulları',
              content:
                  'Uygulamayı kullanarak aşağıdaki koşulları kabul etmiş olursunuz:\n\n'
                  '• 18 yaşından büyük olmalısınız\n'
                  '• Doğru ve güncel bilgiler sağlamalısınız\n'
                  '• Uygulamayı yasalara uygun şekilde kullanmalısınız\n'
                  '• Hesap güvenliğinizden siz sorumlusunuz',
            ),
            _buildSection(
              context,
              title: '3. Hizmet Kapsamı',
              content:
                  'AI Spor Pro şunları sağlar:\n\n'
                  '• Kupon analizi ve değerlendirme\n'
                  '• İstatistiksel veriler\n'
                  '• Risk analizi\n'
                  '• Alternatif tahmin önerileri\n\n'
                  'Not: Uygulamada sunulan analizler bilgilendirme amaçlıdır ve kesin kazanç garantisi vermez.',
            ),
            _buildSection(
              context,
              title: '4. Ödeme ve İadeler',
              content:
                  'Kredi ve premium üyelik ödemeleri:\n\n'
                  '• Ödemeler güvenli ödeme sistemleri üzerinden alınır\n'
                  '• Kullanılmamış krediler iade edilebilir\n'
                  '• Premium üyelik iptalleri için destek ekibiyle iletişime geçin\n'
                  '• İade talepleri 14 gün içinde değerlendirilir',
            ),
            _buildSection(
              context,
              title: '5. Sorumluluk Reddi',
              content:
                  'AI Spor Pro:\n\n'
                  '• Analiz sonuçlarının doğruluğunu garanti etmez\n'
                  '• Kullanıcı kararlarından sorumlu değildir\n'
                  '• Bahis kayıplarından sorumlu tutulamaz\n'
                  '• Hizmet kesintilerinden sorumlu değildir',
            ),
            _buildSection(
              context,
              title: '6. Sözleşme Değişiklikleri',
              content:
                  'Bu sözleşme zaman zaman güncellenebilir. Önemli değişiklikler uygulama içi bildirimlerle duyurulacaktır.',
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
            const SizedBox(height: 8),
            Text(
              '© 2025 Bilwin.inc - Tüm hakları saklıdır.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
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