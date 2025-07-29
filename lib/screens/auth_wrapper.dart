import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'main_menu_screen.dart'; // IMPORTANT: Utiliser main_menu_screen, pas month_selector_screen

class AuthWrapper extends StatelessWidget {
  final FirebaseService _firebaseService = FirebaseService();

  AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _firebaseService.authStateChanges,
      builder: (context, snapshot) {
        // Si en cours de connexion
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Si utilisateur connecté
        if (snapshot.hasData) {
          return const MainMenuScreen(); // CORRECTION: Utiliser MainMenuScreen
        }
        
        // Si pas connecté
        return const LoginScreen();
      },
    );
  }
}