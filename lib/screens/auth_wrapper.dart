import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'month_selector_screen.dart'; // Ajouter cet import

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseService().authStateChanges,
      builder: (context, snapshot) {
        // En cours de chargement
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Chargement...',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          );
        }

        // Erreur de connexion
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Erreur de connexion',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Erreur: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Relancer l'authentification
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const AuthWrapper(),
                        ),
                      );
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        // Utilisateur connecté ou non
        final user = snapshot.data;
        return user != null
            ? const MonthSelectorScreen() // Changement ici
            : const LoginScreen();
      },
    );
  }
}