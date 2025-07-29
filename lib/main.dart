import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart'; // IMPORTANT: Utiliser auth_wrapper
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Budget Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // CORRECTION: Route par défaut vers AuthWrapper
      home: const HomeScreen(),
      routes: {
        '/login': (context) => AuthWrapper(),
        '/main': (context) => AuthWrapper(), // CORRECTION: AuthWrapper au lieu de MainMenuScreen
      },
    );
  }
}