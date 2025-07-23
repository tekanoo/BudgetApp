import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'main_menu_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleStart(BuildContext context) async {
    // Vérifier si l'utilisateur est connecté à Firebase
    final currentUser = AuthService.currentUser;

    if (!context.mounted) return;

    if (currentUser != null) {
      // Utilisateur connecté, aller au menu principal
      _goToMainMenu(context);
    } else {
      // Utilisateur non connecté, forcer la connexion
      _showLoginRequiredDialog(context);
    }
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // L'utilisateur ne peut pas fermer sans se connecter
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            const Text('Connexion requise'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Cette application nécessite une connexion Google pour fonctionner.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Vos données seront sécurisées et synchronisées.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () async {
              // Tenter la connexion Google
              final result = await AuthService.signInWithGoogle();
              
              if (!context.mounted) return;
              
              if (result != null) {
                Navigator.of(ctx).pop(); // Fermer la dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Bienvenue ${result.user?.displayName ?? result.user?.email} !'),
                    backgroundColor: Colors.green,
                  ),
                );
                _goToMainMenu(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connexion échouée. Veuillez réessayer.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.login),
            label: const Text('Se connecter avec Google'),
          ),
        ],
      ),
    );
  }

  void _goToMainMenu(BuildContext context) {
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
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
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor.withOpacity(0.6),
            ],
          ),
        ),
        child: Center(
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
                      color: Colors.black.withOpacity(0.2),
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
              ),
              const SizedBox(height: 16),
              
              // Sous-titre
              Text(
                'Gérez vos finances en toute simplicité',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              
              // Bouton de démarrage
              ElevatedButton.icon(
                onPressed: () => _handleStart(context),
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Commencer'),
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
              const SizedBox(height: 40),
              
              // Informations de sécurité
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.white.withOpacity(0.8),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vos données sont sécurisées et synchronisées avec votre compte Google',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}