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
      // Pour le web, le clientId est lu depuis la meta tag dans index.html
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    } else {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
    }
  }

  // Obtenir l'utilisateur actuel
  static User? get currentUser => _auth.currentUser;
  
  // Stream pour écouter les changements d'état d'authentification
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Connexion avec Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔄 Initialisation Google Sign-In...');
      _initGoogleSignIn();
      
      print('🔄 Tentative de connexion Google...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ L\'utilisateur a annulé la connexion');
        return null;
      }

      print('✅ Compte Google récupéré: ${googleUser.email}');

      // Obtenir les détails d'authentification
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('✅ Token d\'authentification récupéré');

      // Créer une nouvelle credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('✅ Credential Firebase créée');

      // Se connecter à Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      print('✅ Connexion Firebase réussie: ${userCredential.user?.email}');
      
      // Sauvegarder l'état de connexion
      await _saveAuthState(true, userCredential.user);
      
      return userCredential;
    } catch (e) {
      print('❌ Erreur lors de la connexion Google: $e');
      print('❌ Type d\'erreur: ${e.runtimeType}');
      return null;
    }
  }

  // Déconnexion
  static Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      
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