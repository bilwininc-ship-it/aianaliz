import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class CreditsWidget extends StatelessWidget {
  final bool showLabel;
  
  const CreditsWidget({
    super.key,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    
    if (authProvider.user == null) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: () {
        // Kredi detay/satın alma sayfasına git
        _showPurchaseSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: authProvider.isPremium
              ? const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                )
              : LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withOpacity(0.8),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              authProvider.isPremium ? Icons.workspace_premium : Icons.stars,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            if (authProvider.isPremium)
              const Text(
                'PREMIUM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${authProvider.credits}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (showLabel)
                    const Text(
                      'Kredi',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPurchaseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PurchaseSheet(),
    );
  }
}

// Purchase Sheet
class PurchaseSheet extends StatelessWidget {
  const PurchaseSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Başlık
          Row(
            children: [
              Icon(Icons.stars, color: Theme.of(context).primaryColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kredi Paketi Seç',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Mevcut: ${authProvider.credits} kredi',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Paketler
          _buildPackageCard(
            context,
            productId: 'credits_10',
            credits: 10,
            price: '35',
            bonus: 0,
          ),
          const SizedBox(height: 12),
          
          _buildPackageCard(
            context,
            productId: 'credits_25',
            credits: 25,
            price: '79',
            bonus: 2,
            isPopular: true,
          ),
          const SizedBox(height: 12),
          
          _buildPackageCard(
            context,
            productId: 'credits_50',
            credits: 50,
            price: '139',
            bonus: 5,
          ),
          const SizedBox(height: 12),
          
          _buildPackageCard(
            context,
            productId: 'credits_100',
            credits: 100,
            price: '249',
            bonus: 15,
          ),
          const SizedBox(height: 24),
          
          // Premium Bölümü
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Premium Abonelik',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Sınırsız analiz\n• Reklamsız deneyim\n• Öncelikli destek',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildPremiumButton(
                        context,
                        'Aylık',
                        '149 TL/ay',
                        'premium_monthly',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPremiumButton(
                        context,
                        'Yıllık',
                        '1,079 TL (%40 İndirim)',
                        'premium_yearly',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildPackageCard(
    BuildContext context, {
    required String productId,
    required int credits,
    required String price,
    int bonus = 0,
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isPopular 
              ? Theme.of(context).primaryColor 
              : Colors.grey[300]!,
          width: isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.stars,
                  color: Theme.of(context).primaryColor,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$credits Kredi',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (bonus > 0)
                        Text(
                          '+$bonus bonus kredi',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$price TL',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // In-App Purchase başlat
                        _purchaseProduct(context, productId);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Satın Al'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: const Text(
                  'EN POPÜLER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPremiumButton(
    BuildContext context,
    String title,
    String price,
    String productId,
  ) {
    return OutlinedButton(
      onPressed: () {
        _purchaseProduct(context, productId);
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(price, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
  
  void _purchaseProduct(BuildContext context, String productId) {
    // IAP servisini kullanarak satın alma başlat
    // Bu fonksiyon ayrı bir provider'da implement edilecek
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Satın alma başlatılıyor: $productId'),
      ),
    );
  }
}