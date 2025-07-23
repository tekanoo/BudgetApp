import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtenir l'utilisateur actuel
  static User? get currentUser => _auth.currentUser;
  
  // Stream pour écouter les changements d'état d'authentification
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Connexion avec Google (version simplifiée pour le Web)
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔄 Initialisation Google Sign-In...');
      
      if (kIsWeb) {
        // Pour le web, utiliser directement Firebase Auth avec popup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        
        // Ajouter les scopes nécessaires
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        print('🔄 Tentative de connexion avec popup...');
        
        // Connexion avec popup
        final UserCredential result = await _auth.signInWithPopup(googleProvider);
        
        print('✅ Connexion Firebase réussie: ${result.user?.email}');
        
        // Sauvegarder l'état de connexion
        await _saveAuthState(true, result.user);
        
        return result;
      } else {
        // Pour mobile (future implémentation)
        print('❌ Mobile non supporté dans cette version');
        return null;
      }
      
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur Firebase Auth: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('❌ Erreur générale lors de la connexion Google: $e');
      print('❌ Type d\'erreur: ${e.runtimeType}');
      return null;
    }
  }

  // Déconnexion
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      
      // Supprimer l'état de connexion
      await _saveAuthState(false, null);
      print('✅ Déconnexion réussie');
    } catch (e) {
      print('❌ Erreur lors de la déconnexion: $e');
    }
  }

  // Sauvegarder l'état d'authentification
  static Future<void> _saveAuthState(bool isConnected, User? user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isConnected', isConnected);
    
    if (user != null) {
      await prefs.setString('userEmail', user.email ?? '');
      await prefs.setString('userName', user.displayName ?? '');
      await prefs.setString('userPhoto', user.photoURL ?? '');
      print('✅ Informations utilisateur sauvegardées:');
      print('   Email: ${user.email}');
      print('   Nom: ${user.displayName}');
    } else {
      await prefs.remove('userEmail');
      await prefs.remove('userName');
      await prefs.remove('userPhoto');
    }
  }

  // Vérifier si l'utilisateur est connecté
  static Future<bool> isUserSignedIn() async {
    final user = currentUser;
    if (user != null) {
      await _saveAuthState(true, user);
      return true;
    }
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isConnected') ?? false;
  }
}