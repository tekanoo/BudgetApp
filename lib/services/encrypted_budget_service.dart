import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'encryption_service.dart';

// Parser pour les montants avec support des virgules
class AmountParser {
  static double parseAmount(String amountStr) {
    // Remplace les virgules par des points
    String normalized = amountStr.replaceAll(',', '.');
    
    // Gère le cas où il y a plusieurs points (erreur de saisie)
    List<String> parts = normalized.split('.');
    if (parts.length > 2) {
      // Garde seulement les deux derniers chiffres après le dernier point
      normalized = '${parts.sublist(0, parts.length - 1).join('')}.${parts.last}';
    }
    
    return double.tryParse(normalized) ?? 0.0;
  }
}

class EncryptedBudgetDataService {
  final FirebaseService _firebaseService = FirebaseService();
  late final EncryptionService _encryption;
  bool _isInitialized = false;

  /// Initialise le service avec l'utilisateur connecté
  void _ensureInitialized() {
    if (!_isInitialized) {
      final user = _firebaseService.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      _encryption = EncryptionService(user.uid);
      _isInitialized = true;
    }
  }

  /// GESTION DU POINTAGE DES PLAISIRS (DÉPENSES)

  Future<void> togglePlaisirPointing(int index) async {
    _ensureInitialized();
    try {
      final plaisirs = await _firebaseService.loadPlaisirs();
      if (index >= 0 && index < plaisirs.length) {
        // Déchiffrer la transaction
        final decryptedPlaisir = _encryption.decryptTransaction(plaisirs[index]);
        
        final bool currentlyPointed = decryptedPlaisir['isPointed'] == true;
        
        // Bascule le statut
        decryptedPlaisir['isPointed'] = !currentlyPointed;
        
        if (!currentlyPointed) {
          // Si on pointe, on ajoute la date
          decryptedPlaisir['pointedAt'] = DateTime.now().toIso8601String();
        } else {
          // Si on dépointe, on supprime la date
          decryptedPlaisir.remove('pointedAt');
        }
        
        // Rechiffrer la transaction modifiée
        plaisirs[index] = _encryption.encryptTransaction(decryptedPlaisir);
        
        // Sauvegarder
        await _firebaseService.savePlaisirs(plaisirs);
        
        if (kDebugMode) {
          print('✅ Dépense ${currentlyPointed ? 'dépointée' : 'pointée'}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur basculement pointage: $e');
      }
      rethrow;
    }
  }

  /// Calcule le solde disponible basé sur les éléments pointés
  Future<double> getSoldeDisponible() async {
    _ensureInitialized();
    try {
      final entrees = await getEntrees();
      final sorties = await getSorties();
      final plaisirs = await getPlaisirs();
      
      // Calcul du total des revenus
      double totalRevenus = 0.0;
      for (var entree in entrees) {
        totalRevenus += (entree['amount'] as num?)?.toDouble() ?? 0.0;
      }
      
      // Calcul du total des charges pointées
      double totalChargesPointees = 0.0;
      for (var sortie in sorties) {
        if (sortie['isPointed'] == true) {
          totalChargesPointees += (sortie['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
      
      // Calcul du total des dépenses pointées
      double totalDepensesPointees = 0.0;
      for (var plaisir in plaisirs) {
        if (plaisir['isPointed'] == true) {
          final amount = (plaisir['amount'] as num?)?.toDouble() ?? 0.0;
          if (plaisir['isCredit'] == true) {
            totalDepensesPointees -= amount; // Les crédits s'ajoutent (donc on soustrait la soustraction)
          } else {
            totalDepensesPointees += amount; // Les dépenses se soustraient
          }
        }
      }
      
      // Formule : Revenus - Charges pointées - Dépenses pointées
      final solde = totalRevenus - totalChargesPointees - totalDepensesPointees;
      
      if (kDebugMode) {
        print('💰 Solde disponible calculé: $solde€');
        print('   - Revenus: $totalRevenus€');
        print('   - Charges pointées: $totalChargesPointees€');
        print('   - Dépenses pointées: $totalDepensesPointees€');
      }
      
      return solde;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur calcul solde disponible: $e');
      }
      return 0.0;
    }
  }

  /// GESTION DES ENTRÉES (REVENUS) CHIFFRÉES

  Future<List<Map<String, dynamic>>> getEntrees() async {
    _ensureInitialized();
    try {
      final encryptedData = await _firebaseService.loadEntrees();
      
      // Déchiffre chaque entrée
      final List<Map<String, dynamic>> decryptedEntrees = [];
      for (var entry in encryptedData) {
        decryptedEntrees.add(_encryption.decryptTransaction(entry));
      }
      
      return decryptedEntrees;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement entrées chiffrées: $e');
      }
      return [];
    }
  }

  Future<void> addEntree({
    required String amountStr,
    required String description,
  }) async {
    _ensureInitialized();
    try {
      final entrees = await _firebaseService.loadEntrees();
      final double amount = AmountParser.parseAmount(amountStr);
      
      final newEntree = {
        'amount': amount,
        'description': description,
        'date': DateTime.now().toIso8601String(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      // Chiffre avant d'ajouter
      final encryptedEntree = _encryption.encryptTransaction(newEntree);
      entrees.add(encryptedEntree);
      
      await _firebaseService.saveEntrees(entrees);
      
      if (kDebugMode) {
        print('✅ Entrée chiffrée ajoutée: [MONTANT_CHIFFRÉ] - $description');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout entrée chiffrée: $e');
      }
      rethrow;
    }
  }

  Future<void> updateEntree({
    required int index,
    required String amountStr,
    required String description,
  }) async {
    _ensureInitialized();
    try {
      final entrees = await _firebaseService.loadEntrees();
      if (index >= 0 && index < entrees.length) {
        final double amount = AmountParser.parseAmount(amountStr);
        
        final updatedEntree = {
          'amount': amount,
          'description': description,
          'date': DateTime.now().toIso8601String(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'id': entrees[index]['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        };
        
        // Chiffre avant de remplacer
        entrees[index] = _encryption.encryptTransaction(updatedEntree);
        await _firebaseService.saveEntrees(entrees);
        
        if (kDebugMode) {
          print('✅ Entrée chiffrée modifiée: [MONTANT_CHIFFRÉ] - $description');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur modification entrée chiffrée: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteEntree(int index) async {
    _ensureInitialized();
    try {
      final entrees = await _firebaseService.loadEntrees();
      if (index >= 0 && index < entrees.length) {
        entrees.removeAt(index);
        await _firebaseService.saveEntrees(entrees);
        
        if (kDebugMode) {
          print('✅ Entrée chiffrée supprimée');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression entrée chiffrée: $e');
      }
      rethrow;
    }
  }

  /// GESTION DES SORTIES (CHARGES) CHIFFRÉES

  Future<List<Map<String, dynamic>>> getSorties() async {
    _ensureInitialized();
    try {
      final encryptedData = await _firebaseService.loadSorties();
      
      // Déchiffre chaque sortie
      final List<Map<String, dynamic>> decryptedSorties = [];
      for (var entry in encryptedData) {
        decryptedSorties.add(_encryption.decryptTransaction(entry));
      }
      
      return decryptedSorties;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement sorties chiffrées: $e');
      }
      return [];
    }
  }

  Future<void> addSortie({
    required String amountStr,
    required String description,
  }) async {
    _ensureInitialized();
    try {
      final sorties = await _firebaseService.loadSorties();
      final double amount = AmountParser.parseAmount(amountStr);
      
      final newSortie = {
        'amount': amount,
        'description': description,
        'date': DateTime.now().toIso8601String(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'isPointed': false, // Ajout du statut de pointage
      };
      
      // Chiffre avant d'ajouter
      final encryptedSortie = _encryption.encryptTransaction(newSortie);
      sorties.add(encryptedSortie);
      
      await _firebaseService.saveSorties(sorties);
      
      if (kDebugMode) {
        print('✅ Sortie chiffrée ajoutée: [MONTANT_CHIFFRÉ] - $description');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout sortie chiffrée: $e');
      }
      rethrow;
    }
  }

  Future<void> updateSortie({
    required int index,
    required String amountStr,
    required String description,
    String? type,
  }) async {
    _ensureInitialized();
    try {
      final sorties = await _firebaseService.loadSorties();
      if (index >= 0 && index < sorties.length) {
        final double amount = AmountParser.parseAmount(amountStr);
        
        final updatedSortie = {
          'amount': amount,
          'description': description,
          'date': DateTime.now().toIso8601String(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'id': sorties[index]['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        };
        
        // Chiffre avant de remplacer
        sorties[index] = _encryption.encryptTransaction(updatedSortie);
        await _firebaseService.saveSorties(sorties);
        
        if (kDebugMode) {
          print('✅ Charge mise à jour');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur mise à jour sortie: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteSortie(int index) async {
    _ensureInitialized();
    try {
      final sorties = await _firebaseService.loadSorties();
      if (index >= 0 && index < sorties.length) {
        sorties.removeAt(index);
        await _firebaseService.saveSorties(sorties);
        
        if (kDebugMode) {
          print('✅ Sortie chiffrée supprimée');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression sortie chiffrée: $e');
      }
      rethrow;
    }
  }

  /// GESTION DES PLAISIRS (DÉPENSES) CHIFFRÉES AVEC POINTAGE

  Future<List<Map<String, dynamic>>> getPlaisirs() async {
    _ensureInitialized();
    try {
      final encryptedData = await _firebaseService.loadPlaisirs();
      
      // Déchiffre chaque plaisir
      final List<Map<String, dynamic>> decryptedPlaisirs = [];
      for (var entry in encryptedData) {
        decryptedPlaisirs.add(_encryption.decryptTransaction(entry));
      }
      
      return decryptedPlaisirs;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement plaisirs chiffrés: $e');
      }
      return [];
    }
  }

  Future<void> addPlaisir({
    required String amountStr,
    String? tag,
    DateTime? date,
    bool isCredit = false, // NOUVEAU paramètre
  }) async {
    _ensureInitialized();
    try {
      final plaisirs = await _firebaseService.loadPlaisirs();
      final double amount = AmountParser.parseAmount(amountStr);
      
      final newPlaisir = {
        'amount': amount,
        'tag': tag ?? 'Sans catégorie',
        'date': (date ?? DateTime.now()).toIso8601String(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'isPointed': false, // Par défaut, non pointé
        'isCredit': isCredit, // NOUVEAU champ
      };
      
      // Chiffre avant d'ajouter
      final encryptedPlaisir = _encryption.encryptTransaction(newPlaisir);
      plaisirs.add(encryptedPlaisir);
      
      await _firebaseService.savePlaisirs(plaisirs);
      
      // Sauvegarder le tag s'il est nouveau (en clair pour l'autocomplétion)
      if (tag != null && tag.isNotEmpty) {
        await _addTagIfNew(tag);
      }
      
      if (kDebugMode) {
        print('✅ Plaisir chiffré ajouté: [MONTANT_CHIFFRÉ] - ${tag ?? "Sans catégorie"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ajout plaisir chiffré: $e');
      }
      rethrow;
    }
  }

  /// Mettre à jour un plaisir avec support du pointage
  Future<void> updatePlaisir({
    required int index,
    required String amountStr,
    required String tag,
    DateTime? date,
    bool? isPointed,
    String? pointedAt,
  }) async {
    _ensureInitialized();
    try {
      final plaisirs = await _firebaseService.loadPlaisirs();
      if (index >= 0 && index < plaisirs.length) {
        // Récupérer l'ancien plaisir pour préserver certaines données
        final oldPlaisir = _encryption.decryptTransaction(plaisirs[index]);
        
        final amount = AmountParser.parseAmount(amountStr);
        
        final updatedPlaisir = {
          'amount': amount,
          'tag': tag,
          'date': (date ?? DateTime.now()).toIso8601String(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'id': oldPlaisir['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'isPointed': isPointed ?? oldPlaisir['isPointed'] ?? false,
        };

        // Ajouter pointedAt si fourni
        if (pointedAt != null) {
          updatedPlaisir['pointedAt'] = pointedAt;
        } else if (oldPlaisir['pointedAt'] != null) {
          updatedPlaisir['pointedAt'] = oldPlaisir['pointedAt'];
        }
        
        // Chiffrer et sauvegarder
        plaisirs[index] = _encryption.encryptTransaction(updatedPlaisir);
        await _firebaseService.savePlaisirs(plaisirs);
        
        // Sauvegarder le tag s'il est nouveau
        if (tag.isNotEmpty) {
          await _addTagIfNew(tag);
        }
        
        if (kDebugMode) {
          print('✅ Plaisir chiffré mis à jour: [MONTANT_CHIFFRÉ] - $tag');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur mise à jour plaisir: $e');
      }
      rethrow;
    }
  }

  Future<void> deletePlaisir(int index) async {
    _ensureInitialized();
    try {
      final plaisirs = await _firebaseService.loadPlaisirs();
      if (index >= 0 && index < plaisirs.length) {
        plaisirs.removeAt(index);
        await _firebaseService.savePlaisirs(plaisirs);
        
        if (kDebugMode) {
          print('✅ Plaisir chiffré supprimé');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression plaisir chiffré: $e');
      }
      rethrow;
    }
  }

  /// GESTION DU SOLDE BANCAIRE CHIFFRÉ

  Future<double> getBankBalance() async {
    _ensureInitialized();
    try {
      // Charge les données chiffrées
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_firebaseService.currentUser!.uid)
          .collection('budget')
          .doc('settings')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Vérifie d'abord s'il y a une version chiffrée
        if (data.containsKey('encryptedBankBalance')) {
          final encryptedBalance = data['encryptedBankBalance'] as String;
          return _encryption.decryptAmount(encryptedBalance);
        }
        
        // Sinon utilise la version non chiffrée (pour compatibilité)
        return (data['bankBalance'] as num?)?.toDouble() ?? 0.0;
      }
      
      return 0.0;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement solde bancaire chiffré: $e');
      }
      return 0.0;
    }
  }

  Future<void> saveBankBalance(double balance) async {
    _ensureInitialized();
    try {
      final encryptedBalance = _encryption.encryptAmount(balance);
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_firebaseService.currentUser!.uid)
          .collection('budget')
          .doc('settings')
          .set({
        'encryptedBankBalance': encryptedBalance,
        'updatedAt': FieldValue.serverTimestamp(),
        // Supprime l'ancien champ non chiffré
        'bankBalance': FieldValue.delete(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        print('✅ Solde bancaire chiffré sauvegardé: [MONTANT_CHIFFRÉ]');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur sauvegarde solde chiffré: $e');
      }
      rethrow;
    }
  }

  /// UTILITAIRES

  Future<void> _addTagIfNew(String tag) async {
    try {
      final tags = await _firebaseService.loadTags();
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

  Future<void> saveTags(List<String> tags) async {
    try {
      await _firebaseService.saveTags(tags);
      if (kDebugMode) {
        print('✅ Tags sauvegardés (${tags.length} tags)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur sauvegarde tags: $e');
      }
      rethrow;
    }
  }

  /// CALCULS ET STATISTIQUES (sur données déchiffrées côté client)

  Future<Map<String, double>> getTotals() async {
    _ensureInitialized();
    try {
      final entrees = await getEntrees();
      final sorties = await getSorties();
      final plaisirs = await getPlaisirs();

      double totalEntrees = 0;
      for (var entree in entrees) {
        totalEntrees += (entree['amount'] as num?)?.toDouble() ?? 0.0;
      }

      double totalSorties = 0;
      for (var sortie in sorties) {
        totalSorties += (sortie['amount'] as num?)?.toDouble() ?? 0.0;
      }

      double totalPlaisirs = 0;
      double totalPlaisirsTotaux = 0; // Nouveau: total avec crédits
      for (var plaisir in plaisirs) {
        final amount = (plaisir['amount'] as num?)?.toDouble() ?? 0.0;
        if (plaisir['isCredit'] == true) {
          totalPlaisirs -= amount; // Les crédits s'ajoutent (donc réduisent les dépenses)
          totalPlaisirsTotaux += amount; // Mais on les compte dans le total absolu
        } else {
          totalPlaisirs += amount; // Les dépenses normales
          totalPlaisirsTotaux += amount;
        }
      }

      final solde = totalEntrees - totalSorties - totalPlaisirs;

      return {
        'entrees': totalEntrees,
        'sorties': totalSorties,
        'plaisirs': totalPlaisirs, // Total net (avec crédits)
        'plaisirsTotaux': totalPlaisirsTotaux, // Total absolu
        'solde': solde,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur calcul totaux chiffrés: $e');
      }
      return {
        'entrees': 0.0,
        'sorties': 0.0,
        'plaisirs': 0.0,
        'plaisirsTotaux': 0.0,
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

  /// Migration des données existantes vers le format chiffré
  Future<void> migrateToEncrypted() async {
    _ensureInitialized();
    try {
      if (kDebugMode) {
        print('🔄 Migration vers données chiffrées...');
      }

      // Migrer les entrées
      final entrees = await _firebaseService.loadEntrees();
      bool needsMigration = false;
      
      for (int i = 0; i < entrees.length; i++) {
        if (entrees[i]['_encrypted'] != true) {
          entrees[i] = _encryption.encryptTransaction(entrees[i]);
          needsMigration = true;
        }
      }
      
      if (needsMigration) {
        await _firebaseService.saveEntrees(entrees);
        if (kDebugMode) {
          print('✅ Entrées migrées vers format chiffré');
        }
      }

      // Migrer les sorties
      final sorties = await _firebaseService.loadSorties();
      needsMigration = false;
      
      for (int i = 0; i < sorties.length; i++) {
        if (sorties[i]['_encrypted'] != true) {
          sorties[i] = _encryption.encryptTransaction(sorties[i]);
          needsMigration = true;
        }
      }
      
      if (needsMigration) {
        await _firebaseService.saveSorties(sorties);
        if (kDebugMode) {
          print('✅ Sorties migrées vers format chiffré');
        }
      }

      // Migrer les plaisirs avec ajout du système de pointage
      final plaisirs = await _firebaseService.loadPlaisirs();
      needsMigration = false;
      
      for (int i = 0; i < plaisirs.length; i++) {
        if (plaisirs[i]['_encrypted'] != true) {
          // Ajoute le système de pointage si absent
          if (!plaisirs[i].containsKey('isPointed')) {
            plaisirs[i]['isPointed'] = false;
          }
          plaisirs[i] = _encryption.encryptTransaction(plaisirs[i]);
          needsMigration = true;
        } else if (!plaisirs[i].containsKey('isPointed')) {
          // Ajoute le pointage aux données déjà chiffrées
          final decrypted = _encryption.decryptTransaction(plaisirs[i]);
          decrypted['isPointed'] = false;
          plaisirs[i] = _encryption.encryptTransaction(decrypted);
          needsMigration = true;
        }
      }
      
      if (needsMigration) {
        await _firebaseService.savePlaisirs(plaisirs);
        if (kDebugMode) {
          print('✅ Plaisirs migrés vers format chiffré avec pointage');
        }
      }

      if (kDebugMode) {
        print('✅ Migration terminée');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur migration: $e');
      }
    }
  }

  // Ajouter cette méthode après les autres méthodes de gestion des sorties
  Future<void> toggleSortiePointing(int index) async {
    _ensureInitialized();
    try {
      final sorties = await _firebaseService.loadSorties();
      if (index >= 0 && index < sorties.length) {
        // Déchiffrer la sortie
        final decryptedSortie = _encryption.decryptTransaction(sorties[index]);
        
        final bool currentlyPointed = decryptedSortie['isPointed'] == true;
        
        // Bascule le statut
        decryptedSortie['isPointed'] = !currentlyPointed;
        
        if (!currentlyPointed) {
          // Si on pointe, on ajoute la date
          decryptedSortie['pointedAt'] = DateTime.now().toIso8601String();
        } else {
          // Si on dépointe, on supprime la date
          decryptedSortie.remove('pointedAt');
        }
        
        // Rechiffrer et sauvegarder
        sorties[index] = _encryption.encryptTransaction(decryptedSortie);
        await _firebaseService.saveSorties(sorties);
        
        if (kDebugMode) {
          print('✅ Charge ${currentlyPointed ? 'dépointée' : 'pointée'}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur basculement pointage sortie: $e');
      }
      rethrow;
    }
  }

  /// SUPPRESSION COMPLÈTE DES DONNÉES
  Future<void> deleteAllUserData() async {
    _ensureInitialized();
    try {
      await _firebaseService.deleteAllUserData();
      
      if (kDebugMode) {
        print('✅ Suppression complète des données terminée');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression complète: $e');
      }
      rethrow;
    }
  }
}