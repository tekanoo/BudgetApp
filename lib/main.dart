import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/main_menu_screen.dart';
import 'services/migration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    await AnalyticsService.initialize();
    
    final user = AuthService.currentUser;
    if (user != null) {
      await MigrationService.checkAndMigrate();
    }
    
  } on FirebaseException catch (e) {
    debugPrint('❌ Firebase Error: ${e.message}');
    debugPrint('Error code: ${e.code}');
  } on StateError catch (e) {
    debugPrint('❌ State Error: $e');
  } catch (e, stackTrace) {
    debugPrint('❌ General Error: $e');
    debugPrint('Stack trace: $stackTrace');
  }
  
  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Budget Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Nouveau widget pour gérer l'état d'authentification
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Si l'utilisateur est connecté, aller au menu principal
        if (snapshot.hasData && snapshot.data != null) {
          return const MainMenuScreen();
        }
        
        // Sinon, afficher l'écran d'accueil/connexion
        return const HomeScreen();
      },
    );
  }
}