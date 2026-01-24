import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Sayfa açılamadı: $url');
    }
  }

  Future<void> _sendEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@bilwin.inc',
      query: 'subject=AI Spor Pro - Destek Talebi',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yardım & Destek'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Size Nasıl Yardımcı Olabiliriz?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sorularınız için bizimle iletişime geçin',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildContactCard(
            context,
            icon: Icons.email_outlined,
            title: 'E-posta',
            subtitle: 'support@bilwin.inc',
            color: Colors.blue,
            onTap: _sendEmail,
          ),
          _buildContactCard(
            context,
            icon: Icons.language,
            title: 'Web Sitesi',
            subtitle: 'bilwin.inc',
            color: Colors.green,
            onTap: () => _launchURL('https://bilwin.inc'),
          ),
          _buildContactCard(
            context,
            icon: Icons.article_outlined,
            title: 'SSS',
            subtitle: 'Sık Sorulan Sorular',
            color: Colors.orange,
            onTap: () => _launchURL('https://bilwin.inc/faq'),
          ),
          const SizedBox(height: 24),
          Text(
            'Sık Sorulan Sorular',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildFAQItem(
            context,
            question: 'Kredi nasıl satın alınır?',
            answer: 'Paketler sayfasından istediğiniz kredi paketini seçip ödeme yapabilirsiniz.',
          ),
          _buildFAQItem(
            context,
            question: 'Premium üyelik nedir?',
            answer: 'Premium üyelikle sınırsız analiz yapabilir ve tüm özelliklere erişebilirsiniz.',
          ),
          _buildFAQItem(
            context,
            question: 'Analiz ne kadar sürer?',
            answer: 'Analizler genellikle 1-2 dakika içinde tamamlanır.',
          ),
          _buildFAQItem(
            context,
            question: 'İade alabilir miyim?',
            answer: 'Kullanılmamış krediler için 14 gün içinde iade talebinde bulunabilirsiniz.',
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, {required String question, required String answer}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}