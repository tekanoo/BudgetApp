import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream pour écouter les changements d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Utilisateur actuel
  User? get currentUser => _auth.currentUser;
  
  // Vérifier si connecté
  bool get isSignedIn => currentUser != null;

  /// AUTHENTIFICATION
  
  // Connexion avec Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kDebugMode) {
        print('🔐 Début connexion Google...');
      }

      // Déclencher le flow d'authentification
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (kDebugMode) {
          print('❌ Connexion Google annulée');
        }
        return null;
      }

      // Obtenir les détails d'authentification
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Créer les credentials
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Se connecter à Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (kDebugMode) {
        print('✅ Connexion réussie: ${userCredential.user?.displayName}');
      }

      // Créer/mettre à jour le profil utilisateur
      await _createUserProfile(userCredential.user!);
      
      return userCredential;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur connexion Google: $e');
      }
      rethrow;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      if (kDebugMode) {
        print('✅ Déconnexion réussie');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur déconnexion: $e');
      }
      rethrow;
    }
  }

  // Créer le profil utilisateur dans Firestore
  Future<void> _createUserProfile(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();
      
      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          print('✅ Profil utilisateur créé');
        }
      } else {
        // Mettre à jour la dernière connexion
        await userDoc.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur création profil: $e');
      }
    }
  }

  /// DONNÉES BUDGET
  
  // Collection de référence pour l'utilisateur actuel
  CollectionReference? get _userBudgetCollection {
    if (!isSignedIn) return null;
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('budget');
  }

  // Sauvegarder les entrées
  Future<void> saveEntrees(List<Map<String, dynamic>> entrees) async {
    if (!isSignedIn) throw Exception('Utilisateur non connecté');
    
    try {
      await _userBudgetCollection!.doc('entrees').set({
        'data': entrees,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        print('✅ Entrées sauvegardées (${entrees.length} items)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur sauvegarde entrées: $e');
      }
      rethrow;
    }
  }

  // Charger les entrées
  Future<List<Map<String, dynamic>>> loadEntrees() async {
    if (!isSignedIn) return [];
    
    try {
      final doc = await _userBudgetCollection!.doc('entrees').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement entrées: $e');
      }
      return [];
    }
  }

  // Sauvegarder les sorties
  Future<void> saveSorties(List<Map<String, dynamic>> sorties) async {
    if (!isSignedIn) throw Exception('Utilisateur non connecté');
    
    try {
      await _userBudgetCollection!.doc('sorties').set({
        'data': sorties,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        print('✅ Sorties sauvegardées (${sorties.length} items)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur sauvegarde sorties: $e');
      }
      rethrow;
    }
  }

  // Charger les sorties
  Future<List<Map<String, dynamic>>> loadSorties() async {
    if (!isSignedIn) return [];
    
    try {
      final doc = await _userBudgetCollection!.doc('sorties').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement sorties: $e');
      }
      return [];
    }
  }

  // Sauvegarder les plaisirs
  Future<void> savePlaisirs(List<Map<String, dynamic>> plaisirs) async {
    if (!isSignedIn) throw Exception('Utilisateur non connecté');
    
    try {
      await _userBudgetCollection!.doc('plaisirs').set({
        'data': plaisirs,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        print('✅ Plaisirs sauvegardés (${plaisirs.length} items)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur sauvegarde plaisirs: $e');
      }
      rethrow;
    }
  }

  // Charger les plaisirs
  Future<List<Map<String, dynamic>>> loadPlaisirs() async {
    if (!isSignedIn) return [];
    
    try {
      final doc = await _userBudgetCollection!.doc('plaisirs').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement plaisirs: $e');
      }
      return [];
    }
  }

  // Sauvegarder le solde bancaire
  Future<void> saveBankBalance(double balance) async {
    if (!isSignedIn) throw Exception('Utilisateur non connecté');
    
    try {
      await _userBudgetCollection!.doc('settings').set({
        'bankBalance': balance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        print('✅ Solde bancaire sauvegardé: $balance €');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur sauvegarde solde: $e');
      }
      rethrow;
    }
  }

  // Charger le solde bancaire
  Future<double> loadBankBalance() async {
    if (!isSignedIn) return 0.0;
    
    try {
      final doc = await _userBudgetCollection!.doc('settings').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['bankBalance'] ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement solde: $e');
      }
      return 0.0;
    }
  }

  // Sauvegarder les tags
  Future<void> saveTags(List<String> tags) async {
    if (!isSignedIn) throw Exception('Utilisateur non connecté');
    
    try {
      await _userBudgetCollection!.doc('settings').set({
        'availableTags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

  // Charger les tags
  Future<List<String>> loadTags() async {
    if (!isSignedIn) return [];
    
    try {
      final doc = await _userBudgetCollection!.doc('settings').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['availableTags'] ?? []);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement tags: $e');
      }
      return [];
    }
  }

  // Stream pour écouter les changements de données en temps réel
  Stream<DocumentSnapshot> watchBudgetData(String docType) {
    if (!isSignedIn) {
      return const Stream.empty();
    }
    return _userBudgetCollection!.doc(docType).snapshots();
  }
}