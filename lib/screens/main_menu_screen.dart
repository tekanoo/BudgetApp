import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/encrypted_budget_service.dart' as encrypted;

// CORRECTION: Importer home_tab.dart aussi pour éviter l'erreur
import 'month_selector_screen.dart';
import 'home_tab.dart'; // AJOUT pour éviter l'erreur HomeTab
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

  // Onglets principaux avec MonthSelectorScreen en premier
  final List<Widget> _mainTabs = [
    const MonthSelectorScreen(), // Premier onglet = Sélection des mois
    const PlaisirsTab(),
    const EntreesTab(),
    const SortiesTab(),
  ];

  // Titres des onglets
  final List<String> _tabTitles = [
    'Sélection Mois',
    'Dépenses',
    'Revenus', 
    'Charges'
  ];

  // Options du menu de navigation
  List<Map<String, dynamic>> get _menuOptions => [
    {
      'title': 'Sélection Mois',
      'icon': Icons.calendar_month,
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

  List<NavigationDestination> get _mainDestinations => [
    const NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: 'Mois',
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
    _logScreenView();
    _checkAuthState();
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

  void _checkAuthState() {
    _firebaseService.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          // Forcer la reconstruction pour mettre à jour l'icône
        });
        
        if (kDebugMode) {
          print('🔄 État auth changé: ${user?.email}');
        }
      }
    });
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
    if (tabIndex < 4) {
      // Onglets principaux
      setState(() {
        _selectedIndex = tabIndex;
      });
      _pageController.animateToPage(
        tabIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _trackTabChange(tabIndex);
      Navigator.pop(context); // Fermer le menu
    } else {
      // Onglets supplémentaires
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
          targetScreen = const HomeTab(); // CORRECTION: Maintenant HomeTab existe
          title = 'Dashboard';
      }
      
      Navigator.pop(context); // Fermer le menu d'abord
      
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
    }
  }

  Future<void> _trackTabChange(int index) async {
    final tabNames = ['selection_mois', 'depenses', 'revenus', 'charges', 'analyse', 'tags', 'projections'];
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

  // CORRECTION: Ajouter la méthode _showNavigationMenu manquante
  void _showNavigationMenu() {
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
              Navigator.of(context).pop();
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                await _dataService.deleteAllData();
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🗑️ Toutes les données ont été supprimées'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitles[_selectedIndex]),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _showNavigationMenu, // CORRECTION: Méthode maintenant définie
        ),
        actions: [
          // PROFIL UTILISATEUR - Visible sur tous les onglets
          StreamBuilder<User?>(
            stream: _firebaseService.authStateChanges,
            builder: (context, snapshot) {
              final user = snapshot.data;
              
              return PopupMenuButton<String>(
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: user != null ? Colors.blue.shade100 : Colors.grey.shade300,
                  child: user != null 
                    ? Text(
                        user.email?.substring(0, 1).toUpperCase() ?? '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                ),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await _firebaseService.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  } else if (value == 'delete') {
                    _showDeleteAllDataDialog();
                  }
                },
                // CORRECTION: Fixer l'erreur de liste
                itemBuilder: (context) {
                  if (user != null) {
                    return [
                      PopupMenuItem(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'Utilisateur',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              user.email ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Se déconnecter'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer toutes les données'),
                          ],
                        ),
                      ),
                    ];
                  } else {
                    return [
                      const PopupMenuItem(
                        value: 'login',
                        child: Row(
                          children: [
                            Icon(Icons.login, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Se connecter'),
                          ],
                        ),
                      ),
                    ];
                  }
                },
                tooltip: user != null ? 'Profil' : 'Se connecter',
              );
            },
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