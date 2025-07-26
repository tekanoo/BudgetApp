import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'encrypted_budget_service.dart';

class PointingService {
  final EncryptedBudgetDataService _budgetService;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  PointingService(this._budgetService);

  /// NOUVELLES MÉTHODES ANALYTICS - POINTAGE EN LOT

  /// Tracker les opérations de pointage en lot
  Future<void> _trackBatchPointing(String itemType, int itemsCount, Map<String, int> results) async {
    try {
      await _analytics.logEvent(
        name: 'budget_batch_pointing',
        parameters: {
          'item_type': itemType, // 'expenses' ou 'charges'
          'items_selected': itemsCount,
          'items_pointed': results['pointed'] ?? 0,
          'items_unpointed': results['unpointed'] ?? 0,
          'errors_count': results['errors'] ?? 0,
          'success_rate': itemsCount > 0 ? ((results['pointed'] ?? 0) + (results['unpointed'] ?? 0)) / itemsCount * 100 : 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      
      if (kDebugMode) {
        print('📊 Analytics: Pointage lot $itemType tracké');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur tracking pointage lot: $e');
      }
    }
  }

  /// Basculer le pointage d'une dépense - VERSION CORRIGÉE
  Future<bool> togglePlaisirPointing(int index) async {
    try {
      // Utiliser directement la méthode du service principal qui gère correctement le pointage
      await _budgetService.togglePlaisirPointing(index);
      
      // Récupérer l'état après modification pour le retourner
      final plaisirs = await _budgetService.getPlaisirs();
      if (index < 0 || index >= plaisirs.length) return false;
      
      final newState = plaisirs[index]['isPointed'] == true;
      
      if (kDebugMode) {
        debugPrint('✅ Dépense ${newState ? 'pointée' : 'dépointée'}');
      }

      return newState;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur pointage dépense: $e');
      }
      rethrow;
    }
  }

  /// Basculer le pointage d'une charge - VERSION CORRIGÉE
  Future<bool> toggleSortiePointing(int index) async {
    try {
      // Utiliser directement la méthode du service principal qui gère correctement le pointage
      await _budgetService.toggleSortiePointing(index);
      
      // Récupérer l'état après modification pour le retourner
      final sorties = await _budgetService.getSorties();
      if (index < 0 || index >= sorties.length) return false;
      
      final newState = sorties[index]['isPointed'] == true;

      if (kDebugMode) {
        debugPrint('✅ Charge ${newState ? 'pointée' : 'dépointée'}');
      }

      return newState;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur pointage charge: $e');
      }
      rethrow;
    }
  }

  /// Pointer plusieurs dépenses en lot - VERSION CORRIGÉE avec Analytics
  Future<Map<String, int>> batchTogglePlaisirs(List<int> indices) async {
    // AJOUT: Tracker le début de l'opération
    await _analytics.logEvent(
      name: 'budget_batch_operation_started',
      parameters: {
        'operation_type': 'pointing',
        'item_type': 'expenses',
        'items_count': indices.length,
      },
    );

    int pointed = 0;
    int unpointed = 0;
    List<String> errors = [];

    // Trier les indices par ordre décroissant pour éviter les problèmes d'index
    final sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));

    for (int index in sortedIndices) {
      try {
        final newState = await togglePlaisirPointing(index);
        if (newState) {
          pointed++;
        } else {
          unpointed++;
        }
      } catch (e) {
        errors.add('Index $index: $e');
      }
    }

    if (kDebugMode && errors.isNotEmpty) {
      debugPrint('❌ Erreurs traitement lot: ${errors.join(', ')}');
    }

    final results = {
      'pointed': pointed,
      'unpointed': unpointed,
      'errors': errors.length,
    };

    // AJOUT: Tracker les résultats
    await _trackBatchPointing('expenses', indices.length, results);

    return results;
  }

  /// Pointer plusieurs charges en lot - VERSION CORRIGÉE avec Analytics
  Future<Map<String, int>> batchToggleSorties(List<int> indices) async {
    // AJOUT: Tracker le début de l'opération
    await _analytics.logEvent(
      name: 'budget_batch_operation_started',
      parameters: {
        'operation_type': 'pointing',
        'item_type': 'charges',
        'items_count': indices.length,
      },
    );

    int pointed = 0;
    int unpointed = 0;
    List<String> errors = [];

    // Trier les indices par ordre décroissant pour éviter les problèmes d'index
    final sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));

    for (int index in sortedIndices) {
      try {
        final newState = await toggleSortiePointing(index);
        if (newState) {
          pointed++;
        } else {
          unpointed++;
        }
      } catch (e) {
        errors.add('Index $index: $e');
      }
    }

    if (kDebugMode && errors.isNotEmpty) {
      debugPrint('❌ Erreurs traitement lot: ${errors.join(', ')}');
    }

    final results = {
      'pointed': pointed,
      'unpointed': unpointed,
      'errors': errors.length,
    };

    // AJOUT: Tracker les résultats
    await _trackBatchPointing('charges', indices.length, results);

    return results;
  }

  /// Calculer les statistiques de pointage
  Future<Map<String, dynamic>> getPointingStats() async {
    try {
      final plaisirs = await _budgetService.getPlaisirs();
      final sorties = await _budgetService.getSorties();

      int totalPlaisirs = plaisirs.length;
      int plaisirsPoinetes = plaisirs.where((p) => p['isPointed'] == true).length;
      double montantPlaisirsPoinetes = plaisirs
          .where((p) => p['isPointed'] == true)
          .fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));

      int totalSorties = sorties.length;
      int sortiesPointees = sorties.where((s) => s['isPointed'] == true).length;
      double montantSortiesPointees = sorties
          .where((s) => s['isPointed'] == true)
          .fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));

      return {
        'plaisirs': {
          'total': totalPlaisirs,
          'pointed': plaisirsPoinetes,
          'percentage': totalPlaisirs > 0 ? (plaisirsPoinetes / totalPlaisirs * 100).round() : 0,
          'amount': montantPlaisirsPoinetes,
        },
        'sorties': {
          'total': totalSorties,
          'pointed': sortiesPointees,
          'percentage': totalSorties > 0 ? (sortiesPointees / totalSorties * 100).round() : 0,
          'amount': montantSortiesPointees,
        },
        'totalPointedAmount': montantPlaisirsPoinetes + montantSortiesPointees,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur statistiques pointage: $e');
      }
      return {
        'plaisirs': {'total': 0, 'pointed': 0, 'percentage': 0, 'amount': 0.0},
        'sorties': {'total': 0, 'pointed': 0, 'percentage': 0, 'amount': 0.0},
        'totalPointedAmount': 0.0,
      };
    }
  }
}