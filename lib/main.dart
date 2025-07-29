import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart'; // Ajouter cet import
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialiser la localisation française
  await initializeDateFormatting('fr_FR', null);
  
  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Budget Pro',
      debugShowCheckedModeBanner: false,
      
      // Localisation
      locale: const Locale('fr', 'FR'),
      
      // Thème unique - mode clair seulement
      theme: ThemeService.lightTheme,
      
      // Interface adaptée
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
      
      home: const AuthWrapper(),
    );
  }
}