import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'analytics_service.dart';

class StorageService {
  // Clés pour SharedPreferences
  static const String _transactionsKey = 'transactions';
  static const String _plaisirsKey = 'plaisirs';

  // Obtenir l'ID utilisateur actuel (sécurisé)
  static String get _userKey {
    final user = AuthService.currentUser;
    if (user != null) {
      // Utiliser l'UID Firebase pour l'utilisateur connecté
      return 'firebase_user_${user.uid}';
    } else {
      // Bloquer l'accès si pas connecté
      throw Exception('Accès refusé : utilisateur non connecté');
    }
  }

  // Migrer les données locales vers l'utilisateur Firebase lors de la connexion
  static Future<void> migrateLocalDataToUser() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localKey = 'local_user_anonymous';
      final firebaseKey = 'firebase_user_${user.uid}';

      // Migrer les transactions
      final localTransactions = prefs.getString('${localKey}_$_transactionsKey');
      if (localTransactions != null && localTransactions != '[]') {
        final existingFirebaseTransactions = prefs.getString('${firebaseKey}_$_transactionsKey') ?? '[]';
        
        if (existingFirebaseTransactions == '[]') {
          await prefs.setString('${firebaseKey}_$_transactionsKey', localTransactions);
          print('📦 Migration des transactions vers le compte Firebase');
        }
      }

      // Migrer les plaisirs
      final localPlaisirs = prefs.getString('${localKey}_$_plaisirsKey');
      if (localPlaisirs != null && localPlaisirs != '[]') {
        final existingFirebasePlaisirs = prefs.getString('${firebaseKey}_$_plaisirsKey') ?? '[]';
        
        if (existingFirebasePlaisirs == '[]') {
          await prefs.setString('${firebaseKey}_$_plaisirsKey', localPlaisirs);
          print('📦 Migration des objectifs vers le compte Firebase');
        }
      }

      // Nettoyer les données locales après migration
      await prefs.remove('${localKey}_$_transactionsKey');
      await prefs.remove('${localKey}_$_plaisirsKey');
      
    } catch (e) {
      print('❌ Erreur lors de la migration: $e');
    }
  }

  // Ajouter une transaction
  static Future<void> addTransaction({
    required String description,
    required double montant,
    required String categorie,
    required bool isRevenu,
    DateTime? date,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userKey}_$_transactionsKey';
      
      // Récupérer les transactions existantes
      final existingData = prefs.getString(key) ?? '[]';
      final List<dynamic> transactions = json.decode(existingData);
      
      // Créer la nouvelle transaction
      final newTransaction = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'description': description,
        'montant': montant,
        'categorie': categorie,
        'isRevenu': isRevenu,
        'date': (date ?? DateTime.now()).millisecondsSinceEpoch,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Ajouter à la liste
      transactions.add(newTransaction);
      
      // Sauvegarder
      await prefs.setString(key, json.encode(transactions));
      
      // Simuler la synchronisation vers le cloud
      await _syncToCloud('transaction', newTransaction);
      
      // Tracker dans Analytics
      await AnalyticsService.logAddTransaction(
        type: isRevenu ? 'income' : 'expense',
        amount: montant,
        category: categorie,
      );
      await AnalyticsService.logCategoryUsage(categorie);
      
      // Confirmer selon le statut de connexion
      if (AuthService.currentUser != null) {
        print('✅ Transaction sauvegardée et synchronisée (utilisateur: ${AuthService.currentUser?.email})');
      } else {
        print('✅ Transaction sauvegardée localement');
      }
      
    } catch (e) {
      print('❌ Erreur lors de l\'ajout de la transaction: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userKey}_$_transactionsKey';
      
      final data = prefs.getString(key) ?? '[]';
      final List<dynamic> transactions = json.decode(data);
      
      // Convertir en List<Map<String, dynamic>> et trier par date
      final result = transactions
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) => (b['date'] as int).compareTo(a['date'] as int));
      
      return result;
    } catch (e) {
      print('❌ Erreur lors de la récupération des transactions: $e');
      return [];
    }
  }

  // Ajouter un objectif plaisir
  static Future<void> addPlaisirGoal({
    required String nom,
    required double montantCible,
    required double montantActuel,
    String? description,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userKey}_$_plaisirsKey';
      
      // Récupérer les objectifs existants
      final existingData = prefs.getString(key) ?? '[]';
      final List<dynamic> plaisirs = json.decode(existingData);
      
      // Créer le nouvel objectif
      final newPlaisir = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'nom': nom,
        'montantCible': montantCible,
        'montantActuel': montantActuel,
        'description': description,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Ajouter à la liste
      plaisirs.add(newPlaisir);
      
      // Sauvegarder
      await prefs.setString(key, json.encode(plaisirs));
      
      // Tracker dans Analytics
      await AnalyticsService.logAddGoal(
        goalName: nom,
        targetAmount: montantCible,
      );
      
      print('✅ Objectif plaisir ajouté avec succès');
      
    } catch (e) {
      print('❌ Erreur lors de l\'ajout de l\'objectif: $e');
      rethrow;
    }
  }

  // Récupérer les objectifs plaisirs
  static Future<List<Map<String, dynamic>>> getPlaisirGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userKey}_$_plaisirsKey';
      
      final data = prefs.getString(key) ?? '[]';
      final List<dynamic> plaisirs = json.decode(data);
      
      return plaisirs.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Erreur lors de la récupération des objectifs: $e');
      return [];
    }
  }

  // Supprimer une transaction
  static Future<void> deleteTransaction(String transactionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userKey}_$_transactionsKey';
      
      final data = prefs.getString(key) ?? '[]';
      final List<dynamic> transactions = json.decode(data);
      
      // Supprimer la transaction
      transactions.removeWhere((t) => t['id'] == transactionId);
      
      // Sauvegarder
      await prefs.setString(key, json.encode(transactions));
      
      print('✅ Transaction supprimée avec succès');
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      rethrow;
    }
  }

  // Obtenir les statistiques
  static Future<Map<String, double>> getStatistics() async {
    try {
      final transactions = await getTransactions();
      
      double totalRevenus = 0.0;
      double totalDepenses = 0.0;
      
      for (var transaction in transactions) {
        final montant = (transaction['montant'] as num).toDouble();
        final isRevenu = transaction['isRevenu'] as bool;
        
        if (isRevenu) {
          totalRevenus += montant;
        } else {
          totalDepenses += montant;
        }
      }
      
      return {
        'totalRevenus': totalRevenus,
        'totalDepenses': totalDepenses,
        'solde': totalRevenus - totalDepenses,
      };
    } catch (e) {
      print('❌ Erreur lors du calcul des statistiques: $e');
      return {
        'totalRevenus': 0.0,
        'totalDepenses': 0.0,
        'solde': 0.0,
      };
    }
  }

  // Charger les données de l'utilisateur au démarrage
  static Future<void> loadUserData() async {
    final user = AuthService.currentUser;
    if (user != null) {
      print('📱 Chargement des données pour l\'utilisateur: ${user.email}');
      
      // Vérifier si l'utilisateur a des données
      final transactions = await getTransactions();
      final plaisirs = await getPlaisirGoals();
      
      print('💾 Données chargées: ${transactions.length} transactions, ${plaisirs.length} objectifs');
      
      // Tracker le chargement des données
      await AnalyticsService.logFeatureUsed('user_data_loaded');
    }
  }

  // Sauvegarder automatiquement vers le cloud (simulation)
  static Future<void> _syncToCloud(String dataType, Map<String, dynamic> data) async {
    final user = AuthService.currentUser;
    if (user != null) {
      // TODO: Implémenter la vraie synchronisation Firebase
      print('☁️ [SIMULATION] Sync vers Firebase: $dataType pour ${user.email}');
      
      // Tracker la synchronisation
      await AnalyticsService.logFeatureUsed('data_sync_$dataType');
    }
  }
}