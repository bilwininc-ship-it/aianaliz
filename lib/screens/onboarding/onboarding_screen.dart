import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final loc = AppLocalizations.of(context)!;
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Kullanıcı sözleşmesi ve gizlilik politikası kontrolü
    if (!_acceptedTerms || !_acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('register_error')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('register_success')),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.t('register_error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sayfa açılamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final languageProvider = context.watch<LanguageProvider>();
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        actions: [
          // Dil Seçici
          PopupMenuButton<String>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  languageProvider.isTurkish ? '🇹🇷' : '🇬🇧',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
            onSelected: (String languageCode) {
              if (languageCode == 'tr') {
                languageProvider.changeLanguage('tr', 'TR');
              } else {
                languageProvider.changeLanguage('en', 'US');
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'tr',
                child: Row(
                  children: [
                    const Text('🇹🇷', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(loc.t('turkish')),
                    if (languageProvider.isTurkish)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.check, size: 18, color: Colors.green),
                      ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'en',
                child: Row(
                  children: [
                    const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(loc.t('english')),
                    if (languageProvider.isEnglish)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.check, size: 18, color: Colors.green),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  
                  // Başlık
                  Text(
                    loc.t('register'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Spor Pro',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Ad Soyad (Türkçe'de göster)
                  TextFormField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    decoration: InputDecoration(
                      labelText: languageProvider.isTurkish ? 'Ad Soyad' : 'Full Name',
                      hintText: languageProvider.isTurkish ? 'Ahmet Yılmaz' : 'John Doe',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return languageProvider.isTurkish ? 'Ad soyad gerekli' : 'Full name is required';
                      }
                      if (value.length < 3) {
                        return languageProvider.isTurkish ? 'Ad soyad en az 3 karakter olmalı' : 'Name must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // E-posta
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: loc.t('email'),
                      hintText: 'ornek@email.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc.t('email_required');
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return loc.t('email_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Şifre
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: loc.t('password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc.t('password_required');
                      }
                      if (value.length < 6) {
                        return loc.t('password_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Şifre Tekrar
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: loc.t('password_again'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc.t('password_required');
                      }
                      if (value != _passwordController.text) {
                        return loc.t('passwords_dont_match');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Kullanıcı Sözleşmesi Checkbox
                  CheckboxListTile(
                    value: _acceptedTerms,
                    onChanged: (value) {
                      setState(() => _acceptedTerms = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: languageProvider.isTurkish ? 'Kullanıcı Sözleşmesi' : 'Terms of Service',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                _launchURL('https://aikupon.com/terms');
                              },
                          ),
                          TextSpan(
                            text: languageProvider.isTurkish 
                              ? "'ni okudum ve kabul ediyorum" 
                              : " - I have read and accept",
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Gizlilik Politikası Checkbox
                  CheckboxListTile(
                    value: _acceptedPrivacy,
                    onChanged: (value) {
                      setState(() => _acceptedPrivacy = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: languageProvider.isTurkish ? 'Gizlilik Politikası' : 'Privacy Policy',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                _launchURL('https://aikupon.com/privacy');
                              },
                          ),
                          TextSpan(
                            text: languageProvider.isTurkish 
                              ? "'nı okudum ve kabul ediyorum" 
                              : " - I have read and accept",
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Kayıt Ol Butonu
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            loc.t('register'),
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Giriş Yap Linki
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${loc.t('already_have_account')} ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(loc.t('login_now')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  
                  // Footer - Bilwin.inc
                  Text(
                    'Powered by Bilwin.inc',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
