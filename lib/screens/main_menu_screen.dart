import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import '../services/firebase_service.dart';
import '../services/encrypted_budget_service.dart' as encrypted;

// CORRECTION: Importer home_tab.dart aussi pour éviter l'erreur
import 'month_selector_screen.dart';


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

  // Onglets principaux - SUPPRESSION des onglets dépenses, revenus, charges
  final List<Widget> _mainTabs = [
    const MonthSelectorScreen(), // Premier onglet = Sélection des mois
    // Supprimer PlaisirsTab(), EntreesTab(), SortiesTab()
  ];

  // SUPPRIMER cette section complètement car elle n'est plus utilisée
  // final List<String> _tabTitles = [
  //   'Sélection Mois',
  // ];

  // Options du menu de navigation - MISE À JOUR
  List<Map<String, dynamic>> get _menuOptions => [
    {
      'title': 'Sélection Mois',
      'icon': Icons.calendar_month,
      'color': Colors.blue,
      'index': 0,
    },
    // Supprimer l'analyse globale et ajouter les analyses mensuelles
    {
      'title': 'Analyse Janvier',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 1,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Février',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 2,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Mars',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 3,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Avril',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 4,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Mai',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 5,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Juin',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 6,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Juillet',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 7,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Août',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 8,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Septembre',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 9,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Octobre',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 10,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Novembre',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 11,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Analyse Décembre',
      'icon': Icons.analytics,
      'color': Colors.orange,
      'month': 12,
      'isMonthlyAnalysis': true,
    },
    {
      'title': 'Catégories',
      'icon': Icons.label,
      'color': Colors.teal,
      'index': 2,
    },
    {
      'title': 'Projections',
      'icon': Icons.trending_up,
      'color': Colors.indigo,
      'index': 3,
    },
  ];

  // Destinations de la barre de navigation - MISE À JOUR
  final List<NavigationDestination> _mainDestinations = [
    const NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: 'Mois',
    ),
    // Supprimer les destinations dépenses, revenus, charges
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

  void _trackTabChange(int index) {
    final option = _menuOptions[index];
    
    try {
      _analytics.logSelectContent(
        contentType: 'tab',
        itemId: option['title'],
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur Analytics tab change: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _showNavigationMenu(),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _mainTabs,
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: _onItemTapped,
        selectedIndex: _selectedIndex,
        destinations: _mainDestinations,
      ),
    );
  }

  void _showNavigationMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Navigation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...List.generate(_menuOptions.length, (index) {
              final option = _menuOptions[index];
              return ListTile(
                leading: Icon(option['icon'], color: option['color']),
                title: Text(option['title']),
                onTap: () => _navigateToTab(index),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _navigateToTab(int index) {
    Navigator.pop(context); // Fermer le menu
    _onItemTapped(index);
  }
}
