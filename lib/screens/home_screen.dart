import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'main_menu_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleStart(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool? isConnected = prefs.getBool('isConnected');

    if (!context.mounted) return;

    if (isConnected == true) {
      _goToMainMenu(context);
    } else {
      _showLoginDialog(context);
    }
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connexion requise'),
        content: const Text('Souhaitez-vous vous connecter ou continuer sans compte ?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              // Utiliser le nouveau service d'authentification
              final result = await AuthService.signInWithGoogle();
              
              if (!context.mounted) return;
              
              if (result != null) {
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
                    content: Text('La connexion a échoué'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Se connecter avec Google'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isConnected', false);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              if (context.mounted) {
                _goToMainMenu(context);
              }
            },
            child: const Text('Continuer en local'),
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
      appBar: AppBar(
        title: const Text('Bienvenue'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Gestion Budget Pro',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Gérez vos finances en toute simplicité',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _handleStart(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Démarrer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}