import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../l10n/app_localizations.dart';
import '../models/credit_transaction_model.dart';

class RatingRewardDialog extends StatefulWidget {
  const RatingRewardDialog({super.key});

  @override
  State<RatingRewardDialog> createState() => _RatingRewardDialogState();
}

class _RatingRewardDialogState extends State<RatingRewardDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRating(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final InAppReview inAppReview = InAppReview.instance;
      final localizations = AppLocalizations.of(context)!;
      
      // Check if in-app review is available
      if (await inAppReview.isAvailable()) {
        // Request review
        await inAppReview.requestReview();
        
        // Mark as rated
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_rated_app', true);
        
        // Add 1 credit to user
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          final userService = UserService();
          await userService.addCredits(
            userId: userId,
            amount: 1,
            type: TransactionType.bonus,
            description: 'Uygulama puanlandı - 1 kredi ödülü',
          );
          
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.t('rating_thanks')),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      } else {
        // Fallback: Open Play Store directly
        await inAppReview.openStoreListing(
          appStoreId: 'com.aisporanaliz.app',
        );
        
        // Still mark as rated and give credit
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_rated_app', true);
        
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          final userService = UserService();
          await userService.addCredits(
            userId: userId,
            amount: 1,
            type: TransactionType.bonus,
            description: 'Uygulama puanlandı - 1 kredi ödülü',
          );
          
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.t('rating_thanks')),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Rating error: $e');
      if (context.mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.t('rating_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF5F5F5)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star icon with animation
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              localizations.t('rate_us_title'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Description with credit highlight
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Bize 5 yıldız ver, '),
                  TextSpan(
                    text: '1 KREDİ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFD700),
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const TextSpan(text: ' kazan!'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Rate button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _handleRating(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            localizations.t('rate_now'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Maybe later button
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(
                localizations.t('maybe_later'),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show dialog
Future<void> showRatingDialog(BuildContext context) async {
  // Check if user has already rated
  final prefs = await SharedPreferences.getInstance();
  final hasRated = prefs.getBool('has_rated_app') ?? false;
  
  if (hasRated) {
    return; // Don't show dialog if already rated
  }
  
  // Check if we should show (not too frequently)
  final lastShown = prefs.getInt('rating_dialog_last_shown') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  final daysSinceLastShown = (now - lastShown) / (1000 * 60 * 60 * 24);
  
  if (daysSinceLastShown < 3) {
    return; // Don't show if shown in last 3 days
  }
  
  // Update last shown time
  await prefs.setInt('rating_dialog_last_shown', now);
  
  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const RatingRewardDialog(),
    );
  }
}
