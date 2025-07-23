import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Initialiser Analytics
  static Future<void> initialize() async {
    await _analytics.setAnalyticsCollectionEnabled(true);
    if (kDebugMode) {
      debugPrint('📊 Firebase Analytics initialisé');
    }
  }

  // Définir l'utilisateur
  static Future<void> setUser() async {
    final user = AuthService.currentUser;
    if (user != null) {
      await _analytics.setUserId(id: user.uid);
      await _analytics.setUserProperty(
        name: 'user_type',
        value: 'authenticated',
      );
      if (kDebugMode) {
        debugPrint('👤 Utilisateur défini dans Analytics: ${user.email}');
      }
    } else {
      await _analytics.setUserProperty(
        name: 'user_type',
        value: 'anonymous',
      );
    }
  }

  // Événements d'authentification
  static Future<void> logLogin() async {
    await _analytics.logLogin(loginMethod: 'google');
    if (kDebugMode) {
      debugPrint('🔐 Événement: Connexion Google');
    }
  }

  static Future<void> logSignUp() async {
    await _analytics.logSignUp(signUpMethod: 'google');
    if (kDebugMode) {
      debugPrint('📝 Événement: Inscription Google');
    }
  }

  static Future<void> logLogout() async {
    await _analytics.logEvent(name: 'logout');
    if (kDebugMode) {
      debugPrint('🚪 Événement: Déconnexion');
    }
  }

  // Événements de navigation avec noms personnalisés
  static Future<void> logScreenView(String screenName) async {
    // Créer des noms d'événements personnalisés plus explicites
    final customEventName = 'visit_${screenName.toLowerCase()}';
    
    await _analytics.logEvent(
      name: customEventName,
      parameters: {
        'screen_name': screenName,
        'screen_class': 'BudgetApp',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    // Aussi envoyer l'événement screen_view standard
    await _analytics.logScreenView(screenName: screenName);
    
    if (kDebugMode) {
      debugPrint('📱 Écran visité: $screenName (événement: $customEventName)');
    }
  }

  // Événements financiers personnalisés
  static Future<void> logAddTransaction({
    required String type, // 'income' ou 'expense'
    required double amount,
    required String category,
  }) async {
    // Événement principal
    await _analytics.logEvent(
      name: 'budget_add_$type',
      parameters: {
        'transaction_type': type,
        'amount': amount,
        'category': category,
        'currency': 'EUR',
        'method': 'quick_add',
      },
    );
    
    // Événement de valeur pour mesurer l'impact financier
    await _analytics.logEvent(
      name: 'financial_activity',
      parameters: {
        'activity_type': 'add_transaction',
        'value': amount,
        'currency': 'EUR',
        'category': category,
      },
    );
    
    if (kDebugMode) {
      debugPrint('💰 Événement: Transaction ajoutée (budget_add_$type: €$amount)');
    }
  }

  static Future<void> logDeleteTransaction({
    required String type,
    required double amount,
  }) async {
    await _analytics.logEvent(
      name: 'delete_transaction',
      parameters: {
        'transaction_type': type,
        'amount': amount,
        'currency': 'EUR',
      },
    );
    if (kDebugMode) {
      debugPrint('🗑️ Événement: Transaction supprimée');
    }
  }

  // Événements d'objectifs
  static Future<void> logAddGoal({
    required String goalName,
    required double targetAmount,
  }) async {
    await _analytics.logEvent(
      name: 'add_goal',
      parameters: {
        'goal_name': goalName,
        'target_amount': targetAmount,
        'currency': 'EUR',
      },
    );
    if (kDebugMode) {
      debugPrint('🎯 Événement: Objectif ajouté ($goalName: €$targetAmount)');
    }
  }

  // Événements d'engagement
  static Future<void> logFeatureUsed(String featureName) async {
    await _analytics.logEvent(
      name: 'feature_used',
      parameters: {
        'feature_name': featureName,
      },
    );
    if (kDebugMode) {
      debugPrint('⚡ Événement: Fonctionnalité utilisée ($featureName)');
    }
  }

  // Événements de performance utilisateur
  static Future<void> logUserEngagement({
    required String action,
    required int timeSpent, // en secondes
  }) async {
    await _analytics.logEvent(
      name: 'user_engagement',
      parameters: {
        'action': action,
        'time_spent': timeSpent,
      },
    );
    if (kDebugMode) {
      debugPrint('⏱️ Événement: Engagement utilisateur ($action: ${timeSpent}s)');
    }
  }

  // Méthode générique pour envoyer des événements personnalisés
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(
      name: name,
      parameters: parameters,
    );
    if (kDebugMode) {
      debugPrint('📊 Événement personnalisé: $name');
    }
  }

  // Événements spécifiques pour chaque section de l'app
  static Future<void> logHomeVisit() async {
    await _analytics.logEvent(
      name: 'budget_home_visited',
      parameters: {
        'section': 'home',
        'feature': 'dashboard',
      },
    );
    if (kDebugMode) {
      debugPrint('🏠 Page d\'accueil visitée');
    }
  }

  static Future<void> logPlaisirsVisit() async {
    await _analytics.logEvent(
      name: 'budget_plaisirs_visited',
      parameters: {
        'section': 'plaisirs',
        'feature': 'goals_management',
      },
    );
    if (kDebugMode) {
      debugPrint('🎉 Section Plaisirs visitée');
    }
  }

  static Future<void> logEntreesVisit() async {
    await _analytics.logEvent(
      name: 'budget_entrees_visited',
      parameters: {
        'section': 'entrees',
        'feature': 'income_tracking',
      },
    );
    if (kDebugMode) {
      debugPrint('💰 Section Entrées visitée');
    }
  }

  static Future<void> logSortiesVisit() async {
    await _analytics.logEvent(
      name: 'budget_sorties_visited',
      parameters: {
        'section': 'sorties',
        'feature': 'expense_tracking',
      },
    );
    if (kDebugMode) {
      debugPrint('💸 Section Sorties visitée');
    }
  }

  static Future<void> logAnalyseVisit() async {
    await _analytics.logEvent(
      name: 'budget_analyse_visited',
      parameters: {
        'section': 'analyse',
        'feature': 'analytics_dashboard',
      },
    );
    if (kDebugMode) {
      debugPrint('📊 Section Analyse visitée');
    }
  }

  static Future<void> logCategoryUsage(String category) async {
    await _analytics.logEvent(
      name: 'category_used',
      parameters: {
        'category': category,
      },
    );
    if (kDebugMode) {
      debugPrint('🏷️ Événement: Catégorie utilisée ($category)');
    }
  }

  // Événements d'erreur (optionnel)
  static Future<void> logError({
    required String errorType,
    required String errorMessage,
  }) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage,
      },
    );
    if (kDebugMode) {
      debugPrint('❌ Événement: Erreur ($errorType)');
    }
  }

  // Métriques de conversion
  static Future<void> logConversion(String conversionType) async {
    await _analytics.logEvent(
      name: 'conversion',
      parameters: {
        'conversion_type': conversionType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (kDebugMode) {
      debugPrint('🎯 Événement: Conversion ($conversionType)');
    }
  }
}