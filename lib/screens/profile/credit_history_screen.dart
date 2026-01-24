import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/credit_transaction_model.dart';

class CreditHistoryScreen extends StatelessWidget {
  const CreditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.user?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kredi Geçmişi')),
        body: const Center(child: Text('Giriş yapılmamış')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kredi Geçmişi'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Mevcut Kredi Kartı
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.stars,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mevcut Kredi',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authProvider.isPremium
                            ? 'Sınırsız (Premium)'
                            : '${authProvider.credits} Kredi',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // İşlem Geçmişi
          Expanded(
            child: StreamBuilder<List<CreditTransaction>>(
              stream: _buildTransactionsStream(userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildError(context, snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return _buildEmpty(context);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return _buildTransactionCard(context, transaction);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<CreditTransaction>> _buildTransactionsStream(String userId) {
    final ref = FirebaseDatabase.instance
        .ref('credit_transactions')
        .orderByChild('userId')
        .equalTo(userId);
    
    return ref.onValue.map((event) {
      final transactions = <CreditTransaction>[];
      
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        data.forEach((key, value) {
          try {
            final transactionData = Map<String, dynamic>.from(value as Map);
            transactions.add(CreditTransaction.fromJson(key, transactionData));
          } catch (e) {
            debugPrint('❌ Transaction parse hatası: $e');
          }
        });
      }
      
      // Tarihe göre sırala (en yeni üstte)
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // İlk 100 işlemi döndür
      return transactions.take(100).toList();
    });
  }

  Widget _buildTransactionCard(BuildContext context, CreditTransaction transaction) {
    final isPositive = transaction.amount > 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = _getTransactionIcon(transaction.type);
    final title = _getTransactionTitle(transaction.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (transaction.description != null)
              Text(
                transaction.description!,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            const SizedBox(height: 4),
            Text(
              _formatDate(transaction.createdAt),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (transaction.productId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ürün: ${transaction.productId}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPositive ? '+' : ''}${transaction.amount}',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Kredi',
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

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Henüz İşlem Yok',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kredi işlemleriniz burada görünecek',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Bir Hata Oluştu', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.purchase:
        return Icons.shopping_cart;
      case TransactionType.usage:
        return Icons.trending_down;
      case TransactionType.refund:
        return Icons.replay;
      case TransactionType.bonus:
        return Icons.card_giftcard;
      case TransactionType.welcome:
        return Icons.celebration;
      case TransactionType.premium:
        return Icons.workspace_premium;
      case TransactionType.rewardedAd:
        return Icons.play_circle_filled;
    }
  }

  String _getTransactionTitle(TransactionType type) {
    switch (type) {
      case TransactionType.purchase:
        return 'Kredi Satın Alma';
      case TransactionType.usage:
        return 'Analiz Kullanımı';
      case TransactionType.refund:
        return 'İade';
      case TransactionType.bonus:
        return 'Bonus Kredi';
      case TransactionType.welcome:
        return 'Hoşgeldin Bonusu';
      case TransactionType.premium:
        return 'Premium Üyelik';
      case TransactionType.rewardedAd:
        return 'Reklam İzleme Bonusu';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Bugün ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Dün ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
