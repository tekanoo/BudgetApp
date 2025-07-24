import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _storageKey = 'budget_data';
  static const String _lastUpdateKey = 'last_update';
  static final StorageService _instance = StorageService._internal();
  
  factory StorageService() {
    return _instance;
  }

  StorageService._internal();

  Future<bool> saveData({
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> plaisirs,
    required List<Map<String, dynamic>> entrees,
    required List<Map<String, dynamic>> sorties,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'transactions': transactions,
        'plaisirs': plaisirs,
        'entrees': entrees,
        'sorties': sorties,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      final success = await prefs.setString(_storageKey, jsonEncode(data));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

      if (kDebugMode) {
        print('✅ Données sauvegardées localement');
      }
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur sauvegarde: $e');
      }
      return false;
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedData = prefs.getString(_storageKey);
      
      if (storedData == null) {
        return _getEmptyData();
      }

      final data = jsonDecode(storedData) as Map<String, dynamic>;
      
      return {
        'transactions': List<Map<String, dynamic>>.from(data['transactions'] ?? []),
        'plaisirs': List<Map<String, dynamic>>.from(data['plaisirs'] ?? []),
        'entrees': List<Map<String, dynamic>>.from(data['entrees'] ?? []),
        'sorties': List<Map<String, dynamic>>.from(data['sorties'] ?? []),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chargement: $e');
      }
      return _getEmptyData();
    }
  }

  Map<String, List<Map<String, dynamic>>> _getEmptyData() {
    return {
      'transactions': [],
      'plaisirs': [],
      'entrees': [],
      'sorties': [],
    };
  }

  Future<DateTime?> getLastUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString(_lastUpdateKey);
      return dateStr != null ? DateTime.parse(dateStr) : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> clearData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression: $e');
      }
    }
  }
}