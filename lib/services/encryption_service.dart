import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

class FinancialDataEncryption {
  static final FinancialDataEncryption _instance = FinancialDataEncryption._internal();
  factory FinancialDataEncryption() => _instance;
  FinancialDataEncryption._internal();

  // Clé de chiffrement générée à partir de l'ID utilisateur + salt
  late encrypt.Encrypter _encrypter;
  late encrypt.IV _iv;
  
  /// Initialise le chiffrement pour un utilisateur spécifique
  void initializeForUser(String userId) {
    // Génère une clé unique basée sur l'ID utilisateur + salt secret
    final String saltedUserId = '$userId-budget-salt-2024';
    final List<int> keyBytes = sha256.convert(utf8.encode(saltedUserId)).bytes;
    
    // Utilise les 32 premiers bytes pour AES-256
    final encrypt.Key key = encrypt.Key(Uint8List.fromList(keyBytes));
    
    // IV fixe basé sur l'utilisateur (pour pouvoir déchiffrer)
    final List<int> ivBytes = sha256.convert(utf8.encode('$userId-iv')).bytes.take(16).toList();
    _iv = encrypt.IV(Uint8List.fromList(ivBytes));
    
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    if (kDebugMode) {
      print('🔐 Chiffrement initialisé pour l\'utilisateur');
    }
  }

  /// Chiffre un montant financier
  String encryptAmount(double amount) {
    try {
      final String amountStr = amount.toStringAsFixed(2);
      final encrypt.Encrypted encrypted = _encrypter.encrypt(amountStr, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chiffrement: $e');
      }
      // En cas d'erreur, retourne une valeur par défaut chiffrée
      return _encrypter.encrypt('0.00', iv: _iv).base64;
    }
  }

  /// Déchiffre un montant financier
  double decryptAmount(String encryptedAmount) {
    try {
      final encrypt.Encrypted encrypted = encrypt.Encrypted.fromBase64(encryptedAmount);
      final String decryptedStr = _encrypter.decrypt(encrypted, iv: _iv);
      return double.tryParse(decryptedStr) ?? 0.0;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur déchiffrement: $e');
      }
      return 0.0;
    }
  }

  /// Chiffre une description (optionnel)
  String encryptDescription(String description) {
    try {
      if (description.isEmpty) return '';
      final encrypt.Encrypted encrypted = _encrypter.encrypt(description, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur chiffrement description: $e');
      }
      return '';
    }
  }

  /// Déchiffre une description
  String decryptDescription(String encryptedDescription) {
    try {
      if (encryptedDescription.isEmpty) return '';
      final encrypt.Encrypted encrypted = encrypt.Encrypted.fromBase64(encryptedDescription);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur déchiffrement description: $e');
      }
      return 'Description indisponible';
    }
  }

  /// Chiffre un objet transaction complet
  Map<String, dynamic> encryptTransaction(Map<String, dynamic> transaction) {
    final Map<String, dynamic> encryptedTransaction = Map.from(transaction);
    
    // Chiffre le montant
    if (transaction.containsKey('amount')) {
      final double amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
      encryptedTransaction['amount'] = encryptAmount(amount);
      encryptedTransaction['_encrypted'] = true; // Marqueur de chiffrement
    }
    
    // Chiffre la description si présente (optionnel)
    if (transaction.containsKey('description')) {
      final String description = transaction['description'] as String? ?? '';
      encryptedTransaction['description'] = encryptDescription(description);
    }
    
    // Chiffre le tag si présent (optionnel)
    if (transaction.containsKey('tag')) {
      final String tag = transaction['tag'] as String? ?? '';
      encryptedTransaction['tag'] = encryptDescription(tag);
    }
    
    return encryptedTransaction;
  }

  /// Déchiffre un objet transaction complet
  Map<String, dynamic> decryptTransaction(Map<String, dynamic> encryptedTransaction) {
    final Map<String, dynamic> transaction = Map.from(encryptedTransaction);
    
    // Vérifie si la transaction est chiffrée
    if (encryptedTransaction['_encrypted'] != true) {
      return transaction; // Retourne tel quel si pas chiffrée
    }
    
    // Déchiffre le montant
    if (encryptedTransaction.containsKey('amount')) {
      final String encryptedAmount = encryptedTransaction['amount'] as String? ?? '';
      transaction['amount'] = decryptAmount(encryptedAmount);
    }
    
    // Déchiffre la description si présente
    if (encryptedTransaction.containsKey('description')) {
      final String encryptedDesc = encryptedTransaction['description'] as String? ?? '';
      transaction['description'] = decryptDescription(encryptedDesc);
    }
    
    // Déchiffre le tag si présent
    if (encryptedTransaction.containsKey('tag')) {
      final String encryptedTag = encryptedTransaction['tag'] as String? ?? '';
      transaction['tag'] = decryptDescription(encryptedTag);
    }
    
    // Supprime le marqueur de chiffrement
    transaction.remove('_encrypted');
    
    return transaction;
  }

  /// Génère un hash anonyme pour les analytics (sans possibilité de déchiffrement)
  String generateAnonymousHash(double amount) {
    // Crée un hash irreversible pour les statistiques anonymes
    final String data = '${amount.toStringAsFixed(2)}-${DateTime.now().millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(data)).toString().substring(0, 12);
  }
}

/// Extension pour simplifier l'utilisation
extension EncryptedBudgetData on Map<String, dynamic> {
  /// Vérifie si les données sont chiffrées
  bool get isEncrypted => this['_encrypted'] == true;
  
  /// Obtient le montant (déchiffré automatiquement si nécessaire)
  double getAmount() {
    if (isEncrypted && this['amount'] is String) {
      return FinancialDataEncryption().decryptAmount(this['amount']);
    }
    return (this['amount'] as num?)?.toDouble() ?? 0.0;
  }
  
  /// Obtient la description (déchiffrée automatiquement si nécessaire)
  String getDescription() {
    if (isEncrypted && this['description'] is String) {
      return FinancialDataEncryption().decryptDescription(this['description']);
    }
    return this['description'] as String? ?? '';
  }
}