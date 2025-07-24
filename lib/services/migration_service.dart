import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import '../services/auth_service.dart';

class MigrationService {
  static const String _migrationKey = 'data_migrated_to_firestore';
  
  /// Vérifier et effectuer la migration si nécessaire
  static Future<void> checkAndMigrate() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Aucun utilisateur connecté pour la migration');
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userMigrationKey = '${_migrationKey}_${user.uid}';
    
    // Vérifier si la migration a déjà été effectuée pour cet utilisateur
    final alreadyMigrated = prefs.getBool(userMigrationKey) ?? false;
    
    if (alreadyMigrated) {
      if (kDebugMode) {
        debugPrint('✅ Migration déjà effectuée pour: ${user.email}');
      }
      return;
    }

    await _performMigration(prefs, userMigrationKey);
  }

  /// Effectuer la migration des données
  static Future<void> _performMigration(SharedPreferences prefs, String migrationKey) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Début migration SharedPreferences → Firestore...');
      }

      // 1. Récupérer toutes les données de SharedPreferences
      final plaisirsStrings = prefs.getStringList('plaisirs') ?? [];
      final entreesStrings = prefs.getStringList('entrees') ?? [];
      final sortiesStrings = prefs.getStringList('sorties') ?? [];
      final operationsStrings = prefs.getStringList('operations') ?? [];

      if (kDebugMode) {
        debugPrint('📊 Données à migrer:');
        debugPrint('   • ${plaisirsStrings.length} plaisirs');
        debugPrint('   • ${entreesStrings.length} entrées');
        debugPrint('   • ${sortiesStrings.length} sorties');
        debugPrint('   • ${operationsStrings.length} opérations');
      }

      // 2. Si aucune donnée, marquer comme migré et terminer
      if (plaisirsStrings.isEmpty && entreesStrings.isEmpty && 
          sortiesStrings.isEmpty && operationsStrings.isEmpty) {
        await prefs.setBool(migrationKey, true);
        if (kDebugMode) {
          debugPrint('✅ Aucune donnée à migrer');
        }
        return;
      }

      // 3. Migrer vers Firestore
      await FirestoreService.migrateFromSharedPreferences(
        plaisirsStrings: plaisirsStrings,
        entreesStrings: entreesStrings,
        sortiesStrings: sortiesStrings,
      );

      // 4. Marquer la migration comme terminée
      await prefs.setBool(migrationKey, true);

      // 5. Optionnel: Nettoyer les anciennes données SharedPreferences
      await _cleanupOldData(prefs);

      if (kDebugMode) {
        debugPrint('✅ Migration terminée avec succès!');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de la migration: $e');
      }
    }
  }

  /// Nettoyer les anciennes données SharedPreferences après migration
  static Future<void> _cleanupOldData(SharedPreferences prefs) async {
    try {
      // Optionnel: Supprimer les anciennes données
      // await prefs.remove('plaisirs');
      // await prefs.remove('entrees');
      // await prefs.remove('sorties');
      // await prefs.remove('operations');
      
      if (kDebugMode) {
        debugPrint('🧹 Données anciennes conservées pour sécurité');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Erreur nettoyage: $e');
      }
    }
  }

  /// Force une nouvelle migration (pour tests)
  static Future<void> forceMigration() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userMigrationKey = '${_migrationKey}_${user.uid}';
    
    // Réinitialiser le flag de migration
    await prefs.setBool(userMigrationKey, false);
    
    // Effectuer la migration
    await checkAndMigrate();
  }

  /// Vérifier le statut de migration
  static Future<bool> isMigrated() async {
    final user = AuthService.currentUser;
    if (user == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final userMigrationKey = '${_migrationKey}_${user.uid}';
    
    return prefs.getBool(userMigrationKey) ?? false;
  }

  /// Obtenir des statistiques de migration
  static Future<Map<String, dynamic>> getMigrationStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    final plaisirsCount = (prefs.getStringList('plaisirs') ?? []).length;
    final entreesCount = (prefs.getStringList('entrees') ?? []).length;
    final sortiesCount = (prefs.getStringList('sorties') ?? []).length;
    
    final migrated = await isMigrated();
    
    return {
      'local_plaisirs': plaisirsCount,
      'local_entrees': entreesCount,
      'local_sorties': sortiesCount,
      'total_local': plaisirsCount + entreesCount + sortiesCount,
      'is_migrated': migrated,
      'user_id': AuthService.currentUser?.uid,
      'user_email': AuthService.currentUser?.email,
    };
  }
}