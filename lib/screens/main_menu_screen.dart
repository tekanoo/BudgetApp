import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    
    // Vérifier que l'utilisateur est toujours connecté
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      // L'utilisateur n'est plus connecté, le StreamBuilder dans AuthWrapper
      // va automatiquement rediriger vers HomeScreen
      return;
    }
    
    // Charger les informations utilisateur
    setState(() {
      _userEmail = currentUser.email;
      _userName = currentUser.displayName;
    });
    
    // Charger les données utilisateur
    await StorageService.loadUserData();
    if (kDebugMode) {
      debugPrint('📱 Données utilisateur chargées pour: $_userEmail');
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
    
    _trackScreenVisit(index);
  }

  void _trackScreenVisit(int index) {
    final screenNames = ['Dashboard', 'Plaisirs', 'Salaires', 'Charges', 'Analyse'];
    
    AnalyticsService.logScreenView(screenNames[index]);
    
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
    final currentUser = AuthService.currentUser;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(
                Icons.account_circle,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Compte connecté',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentUser != null) ...[
              Text('Email: ${currentUser.email}'),
              if (currentUser.displayName != null) 
                Text('Nom: ${currentUser.displayName}'),
              const SizedBox(height: 8),
              const Text(
                'Vos données sont synchronisées avec Firebase.',
                style: TextStyle(color: Colors.green),
              ),
            ],
            const SizedBox(height: 16),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmAndSignOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange),
            SizedBox(width: 12),
            Text('Confirmer la déconnexion'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
            SizedBox(height: 12),
            Text(
              '• Vos données sont sauvegardées\n'
              '• Vous pourrez vous reconnecter plus tard\n'
              '• Toutes vos données seront préservées',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performSignOut();
    }
  }

  Future<void> _performSignOut() async {
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Déconnexion en cours...'),
            ],
          ),
        ),
      );

      // Tracker la déconnexion
      await AnalyticsService.logLogout();
      
      // Effectuer la déconnexion
      await AuthService.signOut();
      
      // Fermer le dialogue de chargement
      if (mounted) {
        Navigator.of(context).pop();
        
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Déconnexion réussie'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Le StreamBuilder dans AuthWrapper va automatiquement rediriger
      // vers HomeScreen car AuthService.authStateChanges va émettre null
      
    } catch (e) {
      // Fermer le dialogue de chargement
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la déconnexion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      if (kDebugMode) {
        debugPrint('❌ Erreur déconnexion: $e');
      }
    }
  }

  Future<void> _showSavedData() async {
    try {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des données: $e'),
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
    // Vérification de sécurité supplémentaire
    if (AuthService.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Icon(
              Icons.account_circle,
              color: Colors.green.shade700,
            ),
          ),
          onPressed: _showAccountDialog,
          tooltip: 'Compte connecté',
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

  // [Garder toutes les autres méthodes existantes comme _showTransactionDialog, _saveDetailedTransaction, etc.]
  void _showTransactionDialog(BuildContext context, bool isSalaire) {
    // ... (garder le code existant)
  }
}