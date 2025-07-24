import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static late GoogleSignIn _googleSignIn;

  // Initialiser Google Sign-In selon la plateforme
  static void _initGoogleSignIn() {
    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        forceCodeForRefreshToken: true,
      );
    } else {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        forceCodeForRefreshToken: true,
      );
    }
  }

  // Obtenir l'utilisateur actuel
  static User? get currentUser => _auth.currentUser;
  
  // Stream pour écouter les changements d'état d'authentification
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Connexion avec Google - Toujours demander le choix du compte
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Initialisation Google Sign-In...');
      }
      _initGoogleSignIn();
      
      // IMPORTANT: Se déconnecter d'abord pour forcer la sélection du compte
      await _googleSignIn.signOut();
      
      if (kDebugMode) {
        debugPrint('🔄 Tentative de connexion Google (sélection forcée)...');
      }
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        if (kDebugMode) {
          debugPrint('❌ L\'utilisateur a annulé la connexion');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('✅ Compte Google sélectionné: ${googleUser.email}');
      }

      // Obtenir les détails d'authentification
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (kDebugMode) {
        debugPrint('✅ Token d\'authentification récupéré');
      }

      // Créer une nouvelle credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      if (kDebugMode) {
        debugPrint('✅ Credential Firebase créée');
      }

      // Se connecter à Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (kDebugMode) {
        debugPrint('✅ Connexion Firebase réussie: ${userCredential.user?.email}');
        debugPrint('🆔 UID utilisateur: ${userCredential.user?.uid}');
      }
      
      // Sauvegarder l'état de connexion
      await _saveAuthState(true, userCredential.user);
      
      return userCredential;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la connexion Google: $e');
        debugPrint('❌ Type d\'erreur: ${e.runtimeType}');
      }
      return null;
    }
  }

  // Déconnexion complète avec nettoyage des données
  static Future<void> signOut() async {
    try {
      if (kDebugMode) {
        final user = currentUser;
        debugPrint('🔄 Début de la déconnexion pour: ${user?.email}');
      }
      
      // Déconnexion Firebase
      await _auth.signOut();
      if (kDebugMode) {
        debugPrint('✅ Déconnexion Firebase terminée');
      }
      
      // Déconnexion Google (importante pour permettre la sélection du compte)
      await _googleSignIn.signOut();
      if (kDebugMode) {
        debugPrint('✅ Déconnexion Google terminée');
      }
      
      // Supprimer l'état de connexion local
      await _saveAuthState(false, null);
      
      if (kDebugMode) {
        debugPrint('✅ Déconnexion complète réussie');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la déconnexion: $e');
      }
      // Même en cas d'erreur, nettoyer l'état local
      await _saveAuthState(false, null);
    }
  }

  // Déconnexion et suppression de la session (pour changer de compte)
  static Future<void> signOutAndClearSession() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Déconnexion et nettoyage de session...');
      }
      
      // Déconnexion complète
      await signOut();
      
      // Nettoyage des données locales
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userEmail');
      await prefs.remove('userName');
      await prefs.remove('userPhoto');
      await prefs.remove('isConnected');
      await prefs.remove('userId');
      
      if (kDebugMode) {
        debugPrint('✅ Session nettoyée complètement');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du nettoyage de session: $e');
      }
    }
  }

  // Sauvegarder l'état d'authentification
  static Future<void> _saveAuthState(bool isConnected, User? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isConnected', isConnected);
      
      if (user != null && isConnected) {
        await prefs.setString('userEmail', user.email ?? '');
        await prefs.setString('userName', user.displayName ?? '');
        await prefs.setString('userPhoto', user.photoURL ?? '');
        await prefs.setString('userId', user.uid);
        
        if (kDebugMode) {
          debugPrint('💾 État utilisateur sauvegardé: ${user.email}');
          debugPrint('🆔 UID sauvegardé: ${user.uid}');
        }
      } else {
        // Nettoyer les données utilisateur
        await prefs.remove('userEmail');
        await prefs.remove('userName');
        await prefs.remove('userPhoto');
        await prefs.remove('userId');
        
        if (kDebugMode) {
          debugPrint('🧹 Données utilisateur nettoyées');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur sauvegarde état auth: $e');
      }
    }
  }

  // Vérifier si l'utilisateur est connecté
  static Future<bool> isUserSignedIn() async {
    final user = currentUser;
    if (user != null) {
      await _saveAuthState(true, user);
      return true;
    }
    
    // Vérifier SharedPreferences comme fallback
    final prefs = await SharedPreferences.getInstance();
    final isConnected = prefs.getBool('isConnected') ?? false;
    
    if (isConnected && user == null) {
      // État incohérent, nettoyer
      await _saveAuthState(false, null);
      return false;
    }
    
    return isConnected;
  }

  // Obtenir les informations utilisateur stockées localement
  static Future<Map<String, String?>> getCachedUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'email': prefs.getString('userEmail'),
        'name': prefs.getString('userName'),
        'photo': prefs.getString('userPhoto'),
        'id': prefs.getString('userId'),
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lecture cache utilisateur: $e');
      }
      return {};
    }
  }

  // Forcer la reconnexion (utile en cas de problème de session)
  static Future<UserCredential?> forceReconnect() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Reconnexion forcée...');
      }
      
      // Déconnexion complète
      await signOutAndClearSession();
      
      // Attendre un peu pour s'assurer que la déconnexion est effective
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Nouvelle connexion
      return await signInWithGoogle();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur reconnexion forcée: $e');
      }
      return null;
    }
  }

  // Vérifier l'état de la connexion réseau (pour diagnostic)
  static Future<bool> checkConnectivity() async {
    try {
      // Tenter une requête Firebase simple
      await _auth.fetchSignInMethodsForEmail('test@example.com');
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Problème de connectivité détecté: $e');
      }
      return false;
    }
  }

  // Debug: Afficher les informations de l'utilisateur connecté
  static void debugUserInfo() {
    if (!kDebugMode) return;
    
    final user = currentUser;
    if (user != null) {
      debugPrint('👤 Utilisateur connecté:');
      debugPrint('   Email: ${user.email}');
      debugPrint('   Nom: ${user.displayName}');
      debugPrint('   UID: ${user.uid}');
      debugPrint('   Photo: ${user.photoURL}');
    } else {
      debugPrint('❌ Aucun utilisateur connecté');
    }
  }
}