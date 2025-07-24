import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Connexion en cours...'),
            ],
          ),
        ),
      );

      // Tenter la connexion Google
      final result = await AuthService.signInWithGoogle();
      
      // Vérifier si le widget est toujours monté avant d'utiliser context
      if (!context.mounted) return;
      
      // Fermer le dialogue de chargement
      Navigator.of(context).pop();
      
      if (result != null) {
        // Migrer les données locales vers le compte Firebase
        await StorageService.migrateLocalDataToUser();
        await StorageService.loadUserData();
        
        // Tracker la conversion
        await AnalyticsService.logConversion('user_signup');
        await AnalyticsService.logLogin();
        
        // Vérifier à nouveau si le widget est monté avant d'utiliser context
        if (!context.mounted) return;
        
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Bienvenue ${result.user?.displayName ?? result.user?.email} !'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Le StreamBuilder dans AuthWrapper va automatiquement rediriger
        // vers MainMenuScreen car AuthService.authStateChanges va émettre l'utilisateur
        
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Connexion échouée ou annulée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Vérifier si le widget est monté avant d'utiliser context
      if (!context.mounted) return;
      
      // Fermer le dialogue de chargement s'il est encore ouvert
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur de connexion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Text('À propos de l\'app'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestion Budget Pro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 12),
            Text('Fonctionnalités :'),
            Text('• Suivi des revenus et dépenses'),
            Text('• Objectifs de plaisirs'),
            Text('• Analyses détaillées'),
            Text('• Synchronisation cloud sécurisée'),
            SizedBox(height: 12),
            Text(
              'Vos données sont protégées et synchronisées avec votre compte Google.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
              Theme.of(context).primaryColor.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo de l'app
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 60,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Titre
                  Text(
                    'Gestion Budget Pro',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Sous-titre
                  Text(
                    'Gérez vos finances en toute simplicité',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    'Connectez-vous pour accéder à vos données',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  
                  // Bouton de connexion Google
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleGoogleSignIn(context),
                      icon: const Icon(Icons.login),
                      label: const Text('Se connecter avec Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Bouton d'information
                  TextButton.icon(
                    onPressed: () => _showAppInfo(context),
                    icon: Icon(
                      Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    label: Text(
                      'À propos de l\'application',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Informations de sécurité
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sécurité et confidentialité',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Vos données sont chiffrées et sécurisées\n'
                          '• Synchronisation automatique avec votre compte\n'
                          '• Accès uniquement avec votre autorisation\n'
                          '• Sauvegarde cloud sécurisée',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Version info
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
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