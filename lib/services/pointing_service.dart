import 'package:flutter/foundation.dart';
import 'encrypted_budget_service.dart';

class PointingService {
  final EncryptedBudgetDataService _budgetService;

  PointingService(this._budgetService);

  /// Basculer le pointage d'une dépense
  Future<bool> togglePlaisirPointing(int index) async {
    try {
      final plaisirs = await _budgetService.getPlaisirs();
      if (index < 0 || index >= plaisirs.length) return false;

      final plaisir = Map<String, dynamic>.from(plaisirs[index]);
      final wasPointed = plaisir['isPointed'] == true;
      
      // Basculer l'état
      plaisir['isPointed'] = !wasPointed;
      plaisir['pointedAt'] = !wasPointed 
          ? DateTime.now().toIso8601String() 
          : null;

      // Sauvegarder via le service principal (sans isPointed et pointedAt pour l'instant)
      await _budgetService.updatePlaisir(
        index: index,
        amountStr: plaisir['amount'].toString(),
        tag: plaisir['tag'] ?? 'Sans catégorie',
        date: DateTime.tryParse(plaisir['date'] ?? ''),
      );

      if (kDebugMode) {
        debugPrint('✅ Dépense ${!wasPointed ? 'pointée' : 'dépointée'}');
      }

      return !wasPointed; // Retourne le nouvel état
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur pointage dépense: $e');
      }
      rethrow;
    }
  }

  /// Basculer le pointage d'une charge
  Future<bool> toggleSortiePointing(int index) async {
    try {
      final sorties = await _budgetService.getSorties();
      if (index < 0 || index >= sorties.length) return false;

      final sortie = Map<String, dynamic>.from(sorties[index]);
      final wasPointed = sortie['isPointed'] == true;
      
      // Basculer l'état
      sortie['isPointed'] = !wasPointed;
      sortie['pointedAt'] = !wasPointed 
          ? DateTime.now().toIso8601String() 
          : null;

      // Sauvegarder via le service principal (sans isPointed et pointedAt pour l'instant)
      await _budgetService.updateSortie(
        index: index,
        amountStr: sortie['amount'].toString(),
        description: sortie['description'] ?? '',
        type: sortie['type'] ?? 'variable',
      );

      if (kDebugMode) {
        debugPrint('✅ Charge ${!wasPointed ? 'pointée' : 'dépointée'}');
      }

      return !wasPointed; // Retourne le nouvel état
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur pointage charge: $e');
      }
      rethrow;
    }
  }

  /// Pointer plusieurs dépenses en lot
  Future<Map<String, int>> batchTogglePlaisirs(List<int> indices) async {
    int pointed = 0;
    int unpointed = 0;
    List<String> errors = [];

    for (int index in indices) {
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

  /// Pointer plusieurs charges en lot
  Future<Map<String, int>> batchToggleSorties(List<int> indices) async {
    int pointed = 0;
    int unpointed = 0;
    List<String> errors = [];

    for (int index in indices) {
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