import 'package:flutter/foundation.dart';
import 'encrypted_budget_service.dart';

class PointingService {
  final EncryptedBudgetDataService _budgetService;

  PointingService(this._budgetService);

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

  /// Pointer plusieurs dépenses en lot - VERSION CORRIGÉE
  Future<Map<String, int>> batchTogglePlaisirs(List<int> indices) async {
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

    return {
      'pointed': pointed,
      'unpointed': unpointed,
      'errors': errors.length,
    };
  }

  /// Pointer plusieurs charges en lot - VERSION CORRIGÉE
  Future<Map<String, int>> batchToggleSorties(List<int> indices) async {
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

    return {
      'pointed': pointed,
      'unpointed': unpointed,
      'errors': errors.length,
    };
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