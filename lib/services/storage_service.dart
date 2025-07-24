import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'analytics_service.dart';

class StorageService {
  // Clés pour SharedPreferences
  static const String _transactionsKey = 'transactions';
  static const String _plaisirsKey = 'plaisirs';
  static const String _entreesKey = 'entrees';
  static const String _sortiesKey = 'sorties';

  // Obtenir l'ID utilisateur actuel (sécurisé et lié au compte Google)
  static String get _userKey {
    final user = AuthService.currentUser;
    if (user != null) {
      // Utiliser l'UID Firebase pour l'utilisateur connecté
      return 'firebase_user_${user.uid}';
    } else {
      // Utiliser une clé anonyme pour les données locales temporaires
      return 'local_user_anonymous';
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

      if (kDebugMode) {
        debugPrint('🔄 Migration des données vers le compte: ${user.email}');
      }

      // Migrer toutes les catégories de données
      final dataTypes = [_transactionsKey, _plaisirsKey, _entreesKey, _sortiesKey];
      
      for (String dataType in dataTypes) {
        final localData = prefs.getString('${localKey}_$dataType');
        final firebaseData = prefs.getString('${firebaseKey}_$dataType');
        
        if (localData != null && localData != '[]' && (firebaseData == null || firebaseData == '[]')) {
          await prefs.setString('${firebaseKey}_$dataType', localData);
          if (kDebugMode) {
            debugPrint('📦 Migration $dataType vers compte Firebase');
          }
        }
      }

      // Nettoyer les données locales après migration
      for (String dataType in dataTypes) {
        await prefs.remove('${localKey}_$dataType');
      }
      
      if (kDebugMode) {
        debugPrint('✅ Migration terminée pour ${user.email}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la migration: $e');
      }
    }
  }

  // Charger les données de l'utilisateur connecté
  static Future<void> loadUserData() async {
    final user = AuthService.currentUser;
    if (user != null) {
      if (kDebugMode) {
        debugPrint('📱 Chargement des données pour: ${user.email}');
        debugPrint('🔑 Clé utilisateur: ${_userKey}');
      }
      
      // Vérifier si l'utilisateur a des données
      final transactions = await getTransactions();
      final plaisirs = await getPlaisirGoals();
      final entrees = await getEntrees();
      final sorties = await getSorties();
      
      if (kDebugMode) {
        debugPrint('💾 Données chargées: ${transactions.length} transactions, ${plaisirs.length} objectifs, ${entrees.length} entrées, ${sorties.length} sorties');
      }
      
      // Tracker le chargement des données
      await AnalyticsService.logFeatureUsed('user_data_loaded');
    } else {
      if (kDebugMode) {
        debugPrint('⚠️ Aucun utilisateur connecté pour charger les données');
      }
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
        'userId': AuthService.currentUser?.uid ?? 'anonymous',
      };
      
      // Ajouter à la liste
      transactions.add(newTransaction);
      
      // Sauvegarder avec la clé utilisateur
      await prefs.setString(key, json.encode(transactions));
      
      // Tracker dans Analytics
      await AnalyticsService.logAddTransaction(
        type: isRevenu ? 'income' : 'expense',
        amount: montant,
        category: categorie,
      );
      await AnalyticsService.logCategoryUsage(categorie);
      
      if (kDebugMode) {
        final user = AuthService.currentUser;
        debugPrint('✅ Transaction sauvegardée pour: ${user?.email ?? 'utilisateur anonyme'}');
        debugPrint('🔑 Clé: $key');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'ajout de la transaction: $e');
      }
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
      
      if (kDebugMode) {
        debugPrint('📖 Chargement ${result.length} transactions pour clé: $key');
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des transactions: $e');
      }
      return [];
    }
  }

  // Ajouter une entrée
  static Future<void> addEntree({
    required String description,
    required double montant,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userKey}_$_entreesKey';
      
      final existingData = prefs.getString(key) ?? '[]';
      final List<dynamic> entrees = json.decode(existingData);
      
      final newEntree = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'description': description,
        'montant': montant,
        'date': DateTime.now().millisecondsSinceEpoch,
        'userId': AuthService.currentUser?.uid ?? 'anonymous',
      };
      
      entrees.add(newEntree);
      await prefs.setString(key, json.encode(entrees));
      
      if (kDebugMode) {
        debugPrint('✅ Entrée ajoutée pour clé: $key');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'ajout de l\'entrée: $e');
      }
      rethrow;
    }
  }

  // Récupérer les entrées
  static Future<List<Map<String, dynamic>>> getEntrees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userKey}_$_entreesKey';
      
      final data = prefs.getString(key) ?? '[]';
      final List<dynamic> entrees = json.decode(data);
      
      final result = entrees.cast<Map<String, dynamic>>().toList();
      
      if (kDebugMode) {
        debugPrint('📖 Chargement ${result.length} entrées pour clé: $key');
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des entrées: $e');
      }
      return [];
    }
  }

  // Ajouter une sortie
  static Future<void> addSortie({
    required String description,
    required double montant,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userKey}_$_sortiesKey';
      
      final existingData = prefs.getString(key) ?? '[]';
      final List<dynamic> sorties = json.decode(existingData);
      
      final newSortie = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'description': description,
        'montant': montant,
        'date': DateTime.now().millisecondsSinceEpoch,
        'userId': AuthService.currentUser?.uid ?? 'anonymous',
      };
      
      sorties.add(newSortie);
      await prefs.setString(key, json.encode(sorties));
      
      if (kDebugMode) {
        debugPrint('✅ Sortie ajoutée pour clé: $key');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'ajout de la sortie: $e');
      }
      rethrow;
    }
  }

  // Récupérer les sorties
  static Future<List<Map<String, dynamic>>> getSorties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userKey}_$_sortiesKey';
      
      final data = prefs.getString(key) ?? '[]';
      final List<dynamic> sorties = json.decode(data);
      
      final result = sorties.cast<Map<String, dynamic>>().toList();
      
      if (kDebugMode) {
        debugPrint('📖 Chargement ${result.length} sorties pour clé: $key');
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des sorties: $e');
      }
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
      
      final existingData = prefs.getString(key) ?? '[]';
      final List<dynamic> plaisirs = json.decode(existingData);
      
      final newPlaisir = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'nom': nom,
        'montantCible': montantCible,
        'montantActuel': montantActuel,
        'description': description,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'userId': AuthService.currentUser?.uid ?? 'anonymous',
      };
      
      plaisirs.add(newPlaisir);
      await prefs.setString(key, json.encode(plaisirs));
      
      await AnalyticsService.logAddGoal(
        goalName: nom,
        targetAmount: montantCible,
      );
      
      if (kDebugMode) {
        debugPrint('✅ Objectif plaisir ajouté pour clé: $key');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'ajout de l\'objectif: $e');
      }
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
      
      final result = plaisirs.cast<Map<String, dynamic>>().toList();
      
      if (kDebugMode) {
        debugPrint('📖 Chargement ${result.length} objectifs pour clé: $key');
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la récupération des objectifs: $e');
      }
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
      
      transactions.removeWhere((t) => t['id'] == transactionId);
      
      await prefs.setString(key, json.encode(transactions));
      
      if (kDebugMode) {
        debugPrint('✅ Transaction supprimée de la clé: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la suppression: $e');
      }
      rethrow;
    }
  }

  // Obtenir les statistiques
  static Future<Map<String, double>> getStatistics() async {
    try {
      final transactions = await getTransactions();
      final entrees = await getEntrees();
      final sorties = await getSorties();
      
      double totalRevenus = 0.0;
      double totalDepenses = 0.0;
      
      // Compter les transactions
      for (var transaction in transactions) {
        final montant = (transaction['montant'] as num).toDouble();
        final isRevenu = transaction['isRevenu'] as bool;
        
        if (isRevenu) {
          totalRevenus += montant;
        } else {
          totalDepenses += montant;
        }
      }
      
      // Ajouter les entrées
      for (var entree in entrees) {
        final montant = (entree['montant'] as num).toDouble();
        totalRevenus += montant;
      }
      
      // Ajouter les sorties
      for (var sortie in sorties) {
        final montant = (sortie['montant'] as num).toDouble();
        totalDepenses += montant;
      }
      
      return {
        'totalRevenus': totalRevenus,
        'totalDepenses': totalDepenses,
        'solde': totalRevenus - totalDepenses,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du calcul des statistiques: $e');
      }
      return {
        'totalRevenus': 0.0,
        'totalDepenses': 0.0,
        'solde': 0.0,
      };
    }
  }

  // Nettoyer les données d'un utilisateur (lors de la déconnexion)
  static Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = _userKey;
      
      final dataTypes = [_transactionsKey, _plaisirsKey, _entreesKey, _sortiesKey];
      
      for (String dataType in dataTypes) {
        await prefs.remove('${userKey}_$dataType');
      }
      
      if (kDebugMode) {
        debugPrint('🧹 Données utilisateur nettoyées pour: $userKey');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du nettoyage: $e');
      }
    }
  }

  // Debug: Afficher toutes les clés stockées
  static Future<void> debugShowAllKeys() async {
    if (!kDebugMode) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      debugPrint('🔑 Toutes les clés SharedPreferences:');
      for (String key in keys) {
        debugPrint('   - $key');
      }
      
      debugPrint('🎯 Clé utilisateur actuelle: $_userKey');
      
    } catch (e) {
      debugPrint('❌ Erreur debug: $e');
    }
  }
}