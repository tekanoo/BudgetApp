import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

class BudgetDataService {
  static final BudgetDataService _instance = BudgetDataService._internal();
  factory BudgetDataService() => _instance;
  BudgetDataService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  /// MODÈLES DE DONNÉES

  Map<String, dynamic> _createTransaction({
    required double amount,
    required String description,
    String? tag,
    DateTime? date,
  }) {
    return {
      'amount': amount,
      'description': description,
      'tag': tag ?? 'Sans catégorie',
      'date': (date ?? DateTime.now()).toIso8601String(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };
  }

  Map<String, dynamic> _createPlaisir({
    required double amount,
    String? tag,
    DateTime? date,
  }) {
    return {
      'amount': amount,
      'tag': tag ?? 'Sans catégorie',
      'date': (date ?? DateTime.now()).toIso8601String(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };
  }

  /// GESTION DES ENTRÉES (REVENUS)

  Future<List<Map<String, dynamic>>> getEntrees() async {
    try {
      return await _firebaseService.loadEntrees();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement entrées: $e');
      }
      return [];
    }
  }

  Future<void> addEntree({
    required double amount,
    required String description,
  }) async {
    try {
      final entrees = await getEntrees();
      final newEntree = _createTransaction(
        amount: amount,
        description: description,
      );
      
      entrees.add(newEntree);
      await _firebaseService.saveEntrees(entrees);
      
      if (kDebugMode) {
        print('✅ Entrée ajoutée: $amount € - $description');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout entrée: $e');
      }
      rethrow;
    }
  }

  Future<void> updateEntree({
    required int index,
    required double amount,
    required String description,
  }) async {
    try {
      final entrees = await getEntrees();
      if (index >= 0 && index < entrees.length) {
        entrees[index] = _createTransaction(
          amount: amount,
          description: description,
        );
        await _firebaseService.saveEntrees(entrees);
        
        if (kDebugMode) {
          print('✅ Entrée modifiée: $amount € - $description');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur modification entrée: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteEntree(int index) async {
    try {
      final entrees = await getEntrees();
      if (index >= 0 && index < entrees.length) {
        entrees.removeAt(index);
        await _firebaseService.saveEntrees(entrees);
        
        if (kDebugMode) {
          print('✅ Entrée supprimée');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression entrée: $e');
      }
      rethrow;
    }
  }

  /// GESTION DES SORTIES (CHARGES)

  Future<List<Map<String, dynamic>>> getSorties() async {
    try {
      return await _firebaseService.loadSorties();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement sorties: $e');
      }
      return [];
    }
  }

  Future<void> addSortie({
    required double amount,
    required String description,
  }) async {
    try {
      final sorties = await getSorties();
      final newSortie = _createTransaction(
        amount: amount,
        description: description,
      );
      
      sorties.add(newSortie);
      await _firebaseService.saveSorties(sorties);
      
      if (kDebugMode) {
        print('✅ Sortie ajoutée: $amount € - $description');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout sortie: $e');
      }
      rethrow;
    }
  }

  Future<void> updateSortie({
    required int index,
    required double amount,
    required String description,
  }) async {
    try {
      final sorties = await getSorties();
      if (index >= 0 && index < sorties.length) {
        sorties[index] = _createTransaction(
          amount: amount,
          description: description,
        );
        await _firebaseService.saveSorties(sorties);
        
        if (kDebugMode) {
          print('✅ Sortie modifiée: $amount € - $description');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur modification sortie: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteSortie(int index) async {
    try {
      final sorties = await getSorties();
      if (index >= 0 && index < sorties.length) {
        sorties.removeAt(index);
        await _firebaseService.saveSorties(sorties);
        
        if (kDebugMode) {
          print('✅ Sortie supprimée');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression sortie: $e');
      }
      rethrow;
    }
  }

  /// GESTION DES PLAISIRS

  Future<List<Map<String, dynamic>>> getPlaisirs() async {
    try {
      return await _firebaseService.loadPlaisirs();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement plaisirs: $e');
      }
      return [];
    }
  }

  Future<void> addPlaisir({
    required double amount,
    String? tag,
    DateTime? date,
  }) async {
    try {
      final plaisirs = await getPlaisirs();
      final newPlaisir = _createPlaisir(
        amount: amount,
        tag: tag,
        date: date,
      );
      
      plaisirs.add(newPlaisir);
      await _firebaseService.savePlaisirs(plaisirs);
      
      // Sauvegarder le tag s'il est nouveau
      if (tag != null && tag.isNotEmpty) {
        await _addTagIfNew(tag);
      }
      
      if (kDebugMode) {
        print('✅ Plaisir ajouté: $amount € - ${tag ?? "Sans catégorie"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout plaisir: $e');
      }
      rethrow;
    }
  }

  Future<void> updatePlaisir({
    required int index,
    required double amount,
    String? tag,
    DateTime? date,
  }) async {
    try {
      final plaisirs = await getPlaisirs();
      if (index >= 0 && index < plaisirs.length) {
        plaisirs[index] = _createPlaisir(
          amount: amount,
          tag: tag,
          date: date,
        );
        await _firebaseService.savePlaisirs(plaisirs);
        
        // Sauvegarder le tag s'il est nouveau
        if (tag != null && tag.isNotEmpty) {
          await _addTagIfNew(tag);
        }
        
        if (kDebugMode) {
          print('✅ Plaisir modifié: $amount € - ${tag ?? "Sans catégorie"}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur modification plaisir: $e');
      }
      rethrow;
    }
  }

  Future<void> deletePlaisir(int index) async {
    try {
      final plaisirs = await getPlaisirs();
      if (index >= 0 && index < plaisirs.length) {
        plaisirs.removeAt(index);
        await _firebaseService.savePlaisirs(plaisirs);
        
        if (kDebugMode) {
          print('✅ Plaisir supprimé');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression plaisir: $e');
      }
      rethrow;
    }
  }

  /// GESTION DES TAGS

  Future<List<String>> getTags() async {
    try {
      return await _firebaseService.loadTags();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement tags: $e');
      }
      return [];
    }
  }

  Future<void> _addTagIfNew(String tag) async {
    try {
      final tags = await getTags();
      if (!tags.contains(tag)) {
        tags.add(tag);
        await _firebaseService.saveTags(tags);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout tag: $e');
      }
    }
  }

  /// GESTION DU SOLDE BANCAIRE

  Future<double> getBankBalance() async {
    try {
      return await _firebaseService.loadBankBalance();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement solde: $e');
      }
      return 0.0;
    }
  }

  Future<void> setBankBalance(double balance) async {
    try {
      await _firebaseService.saveBankBalance(balance);
      
      if (kDebugMode) {
        print('✅ Solde bancaire mis à jour: $balance €');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur sauvegarde solde: $e');
      }
      rethrow;
    }
  }

  /// CALCULS ET STATISTIQUES

  Future<Map<String, double>> getTotals() async {
    try {
      final entrees = await getEntrees();
      final sorties = await getSorties();
      final plaisirs = await getPlaisirs();

      double totalEntrees = 0;
      for (var entree in entrees) {
        totalEntrees += (entree['amount'] as num).toDouble();
      }

      double totalSorties = 0;
      for (var sortie in sorties) {
        totalSorties += (sortie['amount'] as num).toDouble();
      }

      double totalPlaisirs = 0;
      for (var plaisir in plaisirs) {
        totalPlaisirs += (plaisir['amount'] as num).toDouble();
      }

      return {
        'entrees': totalEntrees,
        'sorties': totalSorties,
        'plaisirs': totalPlaisirs,
        'solde': totalEntrees - totalSorties - totalPlaisirs,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur calcul totaux: $e');
      }
      return {
        'entrees': 0.0,
        'sorties': 0.0,
        'plaisirs': 0.0,
        'solde': 0.0,
      };
    }
  }

  Future<Map<String, double>> getPlaisirsByTag() async {
    try {
      final plaisirs = await getPlaisirs();
      final Map<String, double> totals = {};

      for (var plaisir in plaisirs) {
        final tag = plaisir['tag'] as String? ?? 'Sans catégorie';
        final amount = (plaisir['amount'] as num).toDouble();
        totals[tag] = (totals[tag] ?? 0) + amount;
      }

      return totals;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur calcul plaisirs par tag: $e');
      }
      return {};
    }
  }
}