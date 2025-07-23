import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import 'home_tab.dart';
import 'plaisirs_tab.dart';
import 'entrees_tab.dart';
import 'sorties_tab.dart';
import 'analyse_tab.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  bool _isConnected = false;
  String? _userEmail;
  String? _userName;

  final List<Widget> _tabs = const [
    HomeTab(),
    PlaisirsTab(),
    EntreesTab(),
    SortiesTab(),
    AnalyseTab(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.celebration_outlined),
      selectedIcon: Icon(Icons.celebration),
      label: 'Plaisirs',
    ),
    NavigationDestination(
      icon: Icon(Icons.attach_money_outlined),
      selectedIcon: Icon(Icons.attach_money),
      label: 'Salaires',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Charges',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: 'Analyse',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Tracker l'ouverture de l'app
    AnalyticsService.logScreenView('MainMenu');
    AnalyticsService.logFeatureUsed('app_opened');
    
    // Charger le statut de connexion et les données
    await _loadConnectionStatus();
    
    // Vérification de sécurité : si pas d'utilisateur Firebase, rediriger
    if (AuthService.currentUser == null) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/', 
          (Route<dynamic> route) => false,
        );
      }
      return;
    }
    
    // Si l'utilisateur est connecté, charger ses données
    if (_isConnected && AuthService.currentUser != null) {
      await StorageService.loadUserData();
      if (kDebugMode) {
        debugPrint('📱 Données utilisateur rechargées automatiquement');
      }
    }
  }

  Future<void> _loadConnectionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Vérifier l'état Firebase en premier
    final currentUser = AuthService.currentUser;
    
    if (currentUser != null) {
      // Utilisateur connecté à Firebase
      if (mounted) {
        setState(() {
          _isConnected = true;
          _userEmail = currentUser.email;
          _userName = currentUser.displayName;
        });
      }
      
      // Sauvegarder l'état dans SharedPreferences
      await prefs.setBool('isConnected', true);
      await prefs.setString('userEmail', currentUser.email ?? '');
      await prefs.setString('userName', currentUser.displayName ?? '');
      
      // Charger les données utilisateur
      await StorageService.loadUserData();
      if (kDebugMode) {
        debugPrint('🔄 Utilisateur Firebase restauré: ${currentUser.email}');
      }
      
    } else {
      // Pas d'utilisateur Firebase, vérifier SharedPreferences
      final isConnected = prefs.getBool('isConnected') ?? false;
      
      if (isConnected) {
        // État incohérent : connecté dans SharedPreferences mais pas dans Firebase
        // Nettoyer les données
        await prefs.setBool('isConnected', false);
        await prefs.remove('userEmail');
        await prefs.remove('userName');
        
        if (mounted) {
          setState(() {
            _isConnected = false;
            _userEmail = null;
            _userName = null;
          });
        }
        if (kDebugMode) {
          debugPrint('🧹 État nettoyé - utilisateur non connecté');
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    // Tracker la navigation avec des événements spécifiques
    _trackScreenVisit(index);
  }

  void _trackScreenVisit(int index) {
    final screenNames = ['Dashboard', 'Plaisirs', 'Salaires', 'Charges', 'Analyse'];
    
    // Événement général
    AnalyticsService.logScreenView(screenNames[index]);
    
    // Événements spécifiques selon l'onglet
    switch (index) {
      case 0:
        AnalyticsService.logHomeVisit();
        break;
      case 1:
        AnalyticsService.logPlaisirsVisit();
        break;
      case 2:
        AnalyticsService.logEvent(name: 'budget_salaires_visited', parameters: {'section': 'salaires'});
        break;
      case 3:
        AnalyticsService.logEvent(name: 'budget_charges_visited', parameters: {'section': 'charges'});
        break;
      case 4:
        AnalyticsService.logAnalyseVisit();
        break;
    }
  }

  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _isConnected ? Colors.green : Colors.grey,
              child: Icon(
                _isConnected ? Icons.account_circle : Icons.account_circle_outlined,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isConnected ? 'Compte connecté' : 'Compte non connecté',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isConnected && _userEmail != null) ...[
              Text('Email: $_userEmail'),
              if (_userName != null) Text('Nom: $_userName'),
              const SizedBox(height: 8),
              const Text(
                'Vos données sont synchronisées avec Firebase.',
                style: TextStyle(color: Colors.green),
              ),
            ] else ...[
              const Text(
                'Connectez-vous pour synchroniser vos données avec Firebase.',
              ),
            ],
            const SizedBox(height: 16),
            // Bouton pour voir les données sauvegardées
            ElevatedButton.icon(
              onPressed: _showSavedData,
              icon: const Icon(Icons.storage),
              label: const Text('Voir données sauvegardées'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          if (_isConnected) ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _signOut();
              },
              child: const Text('Se déconnecter'),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _signInWithGoogle();
              },
              icon: const Icon(Icons.login),
              label: const Text('Se connecter'),
            ),
          ],
          if (_isConnected)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
        ],
      ),
    );
  }

  // Nouvelle méthode pour afficher les données sauvegardées
  Future<void> _showSavedData() async {
    final transactions = await StorageService.getTransactions();
    final plaisirs = await StorageService.getPlaisirGoals();
    final stats = await StorageService.getStatistics();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Données sauvegardées'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💰 Transactions: ${transactions.length}'),
              Text('🎯 Objectifs: ${plaisirs.length}'),
              Text('💵 Total revenus: €${stats['totalRevenus']?.toStringAsFixed(2)}'),
              Text('💸 Total dépenses: €${stats['totalDepenses']?.toStringAsFixed(2)}'),
              Text('📈 Solde: €${stats['solde']?.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              if (transactions.isNotEmpty) ...[
                const Text('📝 Dernières transactions:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...transactions.take(3).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${t['description']}: €${t['montant']} (${t['isRevenu'] ? 'Revenu' : 'Dépense'})',
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final result = await AuthService.signInWithGoogle();
      if (result != null && mounted) {
        // Migrer les données locales vers le compte Firebase
        await StorageService.migrateLocalDataToUser();
        await StorageService.loadUserData();
        
        setState(() {
          _isConnected = true;
          _userEmail = result.user?.email;
          _userName = result.user?.displayName;
        });
        
        // Tracker la conversion
        await AnalyticsService.logConversion('user_signup');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bienvenue ${_userName ?? _userEmail} ! Données synchronisées.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la connexion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        setState(() {
          _isConnected = false;
          _userEmail = null;
          _userName = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion réussie'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la déconnexion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: _isConnected ? Colors.green.shade100 : Colors.grey.shade200,
            child: Icon(
              _isConnected ? Icons.account_circle : Icons.account_circle_outlined,
              color: _isConnected ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
          onPressed: _showAccountDialog,
          tooltip: _isConnected ? 'Compte connecté' : 'Se connecter',
        ),
        title: Text(
          ['Dashboard', 'Mes Plaisirs', 'Salaires', 'Charges', 'Analyse'][_selectedIndex],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: _destinations,
        elevation: 8,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      floatingActionButton: (_selectedIndex == 2 || _selectedIndex == 3) ? FloatingActionButton.extended(
        onPressed: () {
          // Tracker l'utilisation du FAB
          final isSalaire = _selectedIndex == 2;
          AnalyticsService.logFeatureUsed(isSalaire ? 'fab_add_salaire' : 'fab_add_charge');
          _showTransactionDialog(context, isSalaire);
        },
        icon: const Icon(Icons.add),
        label: Text(_selectedIndex == 2 ? 'Salaire' : 'Charge'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ) : null,
    );
  }

  void _showTransactionDialog(BuildContext context, bool isSalaire) {
    final descController = TextEditingController();
    final montantController = TextEditingController();
    String selectedCategory = isSalaire ? 'Salaire Net' : 'Logement';
    DateTime selectedDate = DateTime.now();

    // Catégories prédéfinies
    final salaireCategories = [
      'Salaire Net',
      'Salaire Brut',
      'Prime',
      'Bonus',
      'Freelance',
      'Investissements',
      'Autre Revenu',
    ];

    final chargeCategories = [
      'Logement',
      'Transport',
      'Alimentation',
      'Santé',
      'Assurances',
      'Téléphone/Internet',
      'Énergie (Électricité/Gaz)',
      'Impôts',
      'Éducation',
      'Loisirs',
      'Vêtements',
      'Cadeaux',
      'Divers',
    ];

    final categories = isSalaire ? salaireCategories : chargeCategories;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isSalaire ? Icons.attach_money : Icons.receipt_long,
                color: isSalaire ? Colors.green : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text('Ajouter ${isSalaire ? 'un salaire' : 'une charge'}'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Description
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.description),
                    hintText: isSalaire ? 'Ex: Salaire janvier 2025' : 'Ex: Loyer appartement',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Montant
                TextField(
                  controller: montantController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Montant',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.euro),
                    suffixText: '€',
                    hintText: isSalaire ? 'Ex: 2500' : 'Ex: 850',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Catégorie
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedCategory = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Date
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        selectedDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () {
                final desc = descController.text.trim();
                final montant = montantController.text.trim();
                
                if (desc.isNotEmpty && montant.isNotEmpty && double.tryParse(montant) != null) {
                  _saveDetailedTransaction(
                    description: desc,
                    montant: double.parse(montant),
                    category: selectedCategory,
                    isSalaire: isSalaire,
                    date: selectedDate,
                  );
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDetailedTransaction({
    required String description,
    required double montant,
    required String category,
    required bool isSalaire,
    required DateTime date,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('💾 Sauvegarde ${isSalaire ? 'salaire' : 'charge'}: $description - €$montant');
      }
      
      await StorageService.addTransaction(
        description: description,
        montant: montant,
        categorie: category,
        isRevenu: isSalaire,
        date: date,
      );
      
      // Vérifier la sauvegarde
      final stats = await StorageService.getStatistics();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${isSalaire ? '💰 Salaire' : '💸 Charge'} enregistré !'),
                Text('€$montant - $category', style: const TextStyle(fontSize: 12)),
                Text('Solde: €${stats['solde']?.toStringAsFixed(2)}', 
                     style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: isSalaire ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Voir tout',
              textColor: Colors.white,
              onPressed: _showSavedData,
            ),
          ),
        );
      }
      
      if (kDebugMode) {
        debugPrint('📊 Nouveau solde: €${stats['solde']?.toStringAsFixed(2)}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur sauvegarde: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}