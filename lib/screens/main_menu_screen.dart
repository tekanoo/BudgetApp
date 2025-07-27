import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/firebase_service.dart';
import '../services/encrypted_budget_service.dart' as encrypted;

// AJOUTER ces imports manquants
import 'home_tab.dart';
import 'plaisirs_tab.dart';
import 'entrees_tab.dart';
import 'sorties_tab.dart';
import 'analyse_tab.dart';
import 'tags_management_tab.dart';
import 'projections_tab.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final FirebaseService _firebaseService = FirebaseService();
  final encrypted.EncryptedBudgetDataService _dataService = encrypted.EncryptedBudgetDataService();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // SUPPRESSION: Champ non utilisé _allTabs supprimé

  // CORRECTION: Retirer const
  final List<Widget> _mainTabs = [
    const HomeTab(),
    const PlaisirsTab(),
    const EntreesTab(),
    const SortiesTab(),
  ];

  // Options du menu de sélection (sans les options de thème)
  List<Map<String, dynamic>> get _menuOptions => [
    {
      'title': 'Dashboard',
      'icon': Icons.dashboard,
      'color': Colors.blue,
      'index': 0,
    },
    {
      'title': 'Dépenses',
      'icon': Icons.shopping_cart,
      'color': Colors.purple,
      'index': 1,
    },
    {
      'title': 'Revenus',
      'icon': Icons.trending_up,
      'color': Colors.green,
      'index': 2,
    },
    {
      'title': 'Charges',
      'icon': Icons.receipt_long,
      'color': Colors.red,
      'index': 3,
    },
    {
      'title': 'Analyse',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'index': 4,
    },
    {
      'title': 'Catégories',
      'icon': Icons.category,
      'color': Colors.teal,
      'index': 5,
    },
    {
      'title': 'Projections',
      'icon': Icons.trending_up,
      'color': Colors.indigo,
      'index': 6,
    },
  ];

  // CORRECTION: Retirer const
  List<NavigationDestination> get _mainDestinations => [
    const NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    const NavigationDestination(
      icon: Icon(Icons.shopping_cart_outlined),
      selectedIcon: Icon(Icons.shopping_cart),
      label: 'Dépenses',
    ),
    const NavigationDestination(
      icon: Icon(Icons.trending_up_outlined),
      selectedIcon: Icon(Icons.trending_up),
      label: 'Revenus',
    ),
    const NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Charges',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    // CORRECTION: Utiliser _analytics au lieu de _firebaseService.logEvent
    _logScreenView();
  }

  Future<void> _initializeServices() async {
    try {
      await _dataService.initialize();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur initialisation services: $e');
      }
    }
  }

  // NOUVELLE MÉTHODE: Log des événements Firebase Analytics
  Future<void> _logScreenView() async {
    try {
      await _analytics.logScreenView(
        screenName: 'main_menu',
        screenClass: 'MainMenuScreen',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur Analytics: $e');
      }
    }
  }

  void _onItemTapped(int index) {
    if (index < _mainTabs.length) {
      setState(() {
        _selectedIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _trackTabChange(index);
    }
  }

  void _navigateToTab(int tabIndex) {
    // CORRECTION: Gérer la navigation vers les onglets non-principaux
    if (tabIndex < 4) {
      // Onglets principaux (accessibles via PageView)
      setState(() {
        _selectedIndex = tabIndex;
      });
      _pageController.animateToPage(
        tabIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Onglets supplémentaires (navigation directe)
      Widget targetScreen;
      String title;
      
      switch (tabIndex) {
        case 4:
          targetScreen = const AnalyseTab();
          title = 'Analyse';
          break;
        case 5:
          targetScreen = const TagsManagementTab();
          title = 'Catégories';
          break;
        case 6:
          targetScreen = const ProjectionsTab();
          title = 'Projections';
          break;
        default:
          targetScreen = const HomeTab();
          title = 'Dashboard';
      }
      
      // CORRECTION: Fermer le menu d'abord
      Navigator.pop(context);
      
      // Puis naviguer vers l'écran
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(title),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: targetScreen,
          ),
        ),
      );
      
      // Retourner ici pour éviter de fermer le menu deux fois
      return;
    }
    
    _trackTabChange(tabIndex);
    Navigator.pop(context);
  }

  Future<void> _trackTabChange(int index) async {
    final tabNames = ['home', 'plaisirs', 'entrees', 'sorties', 'analyse', 'tags', 'projections']; // AJOUT
    if (index < tabNames.length) {
      try {
        await _analytics.logEvent(
          name: 'tab_changed',
          parameters: {
            'tab_name': tabNames[index],
            'tab_index': index,
          },
        );
      } catch (e) {
        if (kDebugMode) {
          print('❌ Erreur tracking: $e');
        }
      }
    }
  }

  void _showTabSelectionMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Titre
            const Row(
              children: [
                Icon(Icons.apps, color: Colors.blue),
                SizedBox(width: 12),
                Text(
                  'Navigation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Liste des options
            ...(_menuOptions.map((option) {
              final isSelected = _selectedIndex == option['index'] && option['index'] < 4;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: isSelected 
                      ? (option['color'] as Color).withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _navigateToTab(option['index']),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? option['color']
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            option['icon'],
                            color: isSelected 
                                ? option['color']
                                : Colors.grey.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option['title'],
                              style: TextStyle(
                                fontWeight: isSelected 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                color: isSelected 
                                    ? option['color']
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: option['color'],
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showUserMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // En-tête
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.person, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _firebaseService.currentUser?.displayName ?? 'Utilisateur',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _firebaseService.currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Informations de sécurité
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Données chiffrées',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vos données financières sont automatiquement chiffrées avant d\'être envoyées dans le cloud. Même le développeur ne peut pas voir vos montants !',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.orange),
                  title: const Text('Se déconnecter'),
                  onTap: () async {
                    try {
                      await _firebaseService.signOut();
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (kDebugMode) print('❌ Erreur déconnexion: $e');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Supprimer toutes les données'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    _showDeleteAllDataDialog();
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteAllDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Attention !'),
          ],
        ),
        content: const Text(
          'Cette action supprimera définitivement toutes vos données (revenus, charges, dépenses, catégories).\n\nCette action est IRRÉVERSIBLE !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              // Fermer le dialogue d'abord
              Navigator.of(context).pop();
              
              // Afficher un indicateur de chargement
              if (!mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                await _dataService.deleteAllData();
                
                // Fermer l'indicateur de chargement
                if (context.mounted) {
                  Navigator.of(context).pop();
                  
                  // Afficher le message de succès
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🗑️ Toutes les données ont été supprimées'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                // Fermer l'indicateur de chargement
                if (context.mounted) {
                  Navigator.of(context).pop();
                  
                  // Afficher l'erreur
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de la suppression: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _firebaseService.currentUser;
    final tabTitles = _menuOptions.map((option) => option['title'] as String).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tabTitles[_selectedIndex]),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.menu,
              color: Theme.of(context).primaryColor,
            ),
          ),
          onPressed: _showTabSelectionMenu,
          tooltip: 'Navigation',
        ),
        actions: [
          // Profil utilisateur
          if (user != null)
            IconButton(
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  user.email?.substring(0, 1).toUpperCase() ?? '?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              onPressed: _showUserMenu,
              tooltip: 'Profil',
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _trackTabChange(index);
        },
        children: _mainTabs,
      ),
      bottomNavigationBar: NavigationBar(
        destinations: _mainDestinations,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
      ),
    );
  }
}