import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtenir l'ID utilisateur actuel
  static String? get _userId => _auth.currentUser?.uid;

  // Collection principale pour les données utilisateur
  static CollectionReference get _userCollection => 
      _firestore.collection('users');

  // Document de l'utilisateur actuel
  static DocumentReference? get _userDoc => 
      _userId != null ? _userCollection.doc(_userId) : null;

  /// Sauvegarder les données de transactions dans Firestore
  static Future<void> saveUserData({
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> plaisirs,
    required List<Map<String, dynamic>> entrees,
    required List<Map<String, dynamic>> sorties,
  }) async {
    if (_userDoc == null) {
      throw Exception('Utilisateur non connecté');
    }

    try {
      final userData = {
        'transactions': transactions,
        'plaisirs': plaisirs,
        'entrees': entrees,
        'sorties': sorties,
        'lastUpdated': FieldValue.serverTimestamp(),
        'deviceInfo': {
          'platform': kIsWeb ? 'web' : 'mobile',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      };

      await _userDoc!.set(userData, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ Données sauvegardées dans Firestore pour: ${_auth.currentUser?.email}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur sauvegarde Firestore: $e');
      }
      rethrow;
    }
  }

  /// Charger les données depuis Firestore
  static Future<Map<String, List<Map<String, dynamic>>>> loadUserData() async {
    if (_userDoc == null) {
      return {
        'transactions': [],
        'plaisirs': [],
        'entrees': [],
        'sorties': [],
      };
    }

    try {
      final docSnapshot = await _userDoc!.get();
      
      if (!docSnapshot.exists) {
        if (kDebugMode) {
          debugPrint('📄 Aucunes données Firestore trouvées pour: ${_auth.currentUser?.email}');
        }
        return {
          'transactions': [],
          'plaisirs': [],
          'entrees': [],
          'sorties': [],
        };
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      
      return {
        'transactions': List<Map<String, dynamic>>.from(data['transactions'] ?? []),
        'plaisirs': List<Map<String, dynamic>>.from(data['plaisirs'] ?? []),
        'entrees': List<Map<String, dynamic>>.from(data['entrees'] ?? []),
        'sorties': List<Map<String, dynamic>>.from(data['sorties'] ?? []),
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur chargement Firestore: $e');
      }
      return {
        'transactions': [],
        'plaisirs': [],
        'entrees': [],
        'sorties': [],
      };
    }
  }

  /// Ajouter une transaction (synchronisation automatique)
  static Future<void> addTransaction({
    required String type, // 'plaisirs', 'entrees', 'sorties'
    required Map<String, dynamic> transaction,
  }) async {
    if (_userDoc == null) {
      throw Exception('Utilisateur non connecté');
    }

    try {
      // Ajouter timestamp et ID unique
      transaction['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      transaction['createdAt'] = FieldValue.serverTimestamp();
      transaction['userId'] = _userId;

      await _userDoc!.update({
        type: FieldValue.arrayUnion([transaction]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ Transaction ajoutée à Firestore ($type)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur ajout transaction: $e');
      }
      rethrow;
    }
  }

  /// Écouter les changements en temps réel
  static Stream<Map<String, List<Map<String, dynamic>>>> getUserDataStream() {
    if (_userDoc == null) {
      return Stream.value({
        'transactions': [],
        'plaisirs': [],
        'entrees': [],
        'sorties': [],
      });
    }

    return _userDoc!.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return {
          'transactions': [],
          'plaisirs': [],
          'entrees': [],
          'sorties': [],
        };
      }

      final data = snapshot.data() as Map<String, dynamic>;
      
      return {
        'transactions': List<Map<String, dynamic>>.from(data['transactions'] ?? []),
        'plaisirs': List<Map<String, dynamic>>.from(data['plaisirs'] ?? []),
        'entrees': List<Map<String, dynamic>>.from(data['entrees'] ?? []),
        'sorties': List<Map<String, dynamic>>.from(data['sorties'] ?? []),
      };
    });
  }

  /// Migrer les données SharedPreferences vers Firestore
  static Future<void> migrateFromSharedPreferences({
    required List<String> plaisirsStrings,
    required List<String> entreesStrings,
    required List<String> sortiesStrings,
  }) async {
    if (_userDoc == null) return;

    try {
      // Convertir les strings en Map
      final plaisirs = plaisirsStrings.map((s) => _parseStringToMap(s)).toList();
      final entrees = entreesStrings.map((s) => _parseStringToMap(s)).toList();
      final sorties = sortiesStrings.map((s) => _parseStringToMap(s)).toList();

      await saveUserData(
        transactions: [],
        plaisirs: plaisirs,
        entrees: entrees,
        sorties: sorties,
      );

      if (kDebugMode) {
        debugPrint('🔄 Migration SharedPreferences → Firestore terminée');
        debugPrint('📊 Migré: ${plaisirs.length} plaisirs, ${entrees.length} entrées, ${sorties.length} sorties');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur migration: $e');
      }
    }
  }

  /// Utilitaire pour parser les strings SharedPreferences
  static Map<String, dynamic> _parseStringToMap(String s) {
    final clean = s.replaceAll(RegExp(r'[{}]'), '');
    final parts = clean.split(',');
    final map = <String, dynamic>{};
    
    for (var part in parts) {
      final kv = part.split(':');
      if (kv.length >= 2) {
        final key = kv[0].trim();
        final value = kv.sublist(1).join(':').trim();
        
        // Essayer de convertir en double si possible
        if (key == 'amount' || key == 'montant') {
          map[key] = double.tryParse(value) ?? value;
        } else {
          map[key] = value;
        }
      }
    }
    return map;
  }

  /// Supprimer toutes les données utilisateur
  static Future<void> deleteUserData() async {
    if (_userDoc == null) return;
    
    try {
      await _userDoc!.delete();
      if (kDebugMode) {
        debugPrint('🗑️ Données utilisateur supprimées de Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur suppression: $e');
      }
    }
  }

  /// Obtenir les statistiques utilisateur
  static Future<Map<String, double>> getStatistics() async {
    try {
      final data = await loadUserData();
      
      double totalRevenus = 0.0;
      double totalDepenses = 0.0;
      
      // Compter les entrées
      for (var entree in data['entrees']!) {
        final montant = (entree['montant'] is String) 
            ? double.tryParse(entree['montant']) ?? 0.0
            : entree['montant']?.toDouble() ?? 0.0;
        totalRevenus += montant;
      }
      
      // Compter les sorties
      for (var sortie in data['sorties']!) {
        final montant = (sortie['montant'] is String) 
            ? double.tryParse(sortie['montant']) ?? 0.0
            : sortie['montant']?.toDouble() ?? 0.0;
        totalDepenses += montant;
      }
      
      // Compter les plaisirs
      for (var plaisir in data['plaisirs']!) {
        final amount = (plaisir['amount'] is String) 
            ? double.tryParse(plaisir['amount']) ?? 0.0
            : plaisir['amount']?.toDouble() ?? 0.0;
        totalDepenses += amount;
      }
      
      return {
        'totalRevenus': totalRevenus,
        'totalDepenses': totalDepenses,
        'solde': totalRevenus - totalDepenses,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur calcul statistiques: $e');
      }
      return {
        'totalRevenus': 0.0,
        'totalDepenses': 0.0,
        'solde': 0.0,
      };
    }
  }
}