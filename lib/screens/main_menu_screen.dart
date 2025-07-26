import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/firebase_service.dart';
import '../services/encrypted_budget_service.dart' as encrypted;
import '../services/translation_service.dart';
import '../widgets/language_selector.dart';
import 'home_tab.dart';
import 'plaisirs_tab.dart';
import 'entrees_tab.dart';
import 'sorties_tab.dart';
import 'analyse_tab.dart';
import 'tags_management_tab.dart';

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

  // Tous les onglets disponibles
  final List<Widget> _allTabs = const [
    HomeTab(),
    PlaisirsTab(),
    EntreesTab(),
    SortiesTab(),
    AnalyseTab(),
    TagsManagementTab(),
  ];

  // Onglets principaux (affichés dans la navigation du bas)
  final List<Widget> _mainTabs = const [
    HomeTab(),
    PlaisirsTab(),
    EntreesTab(),
    SortiesTab(),
  ];

  // Options du menu de sélection - utilisant le service de traduction
  List<Map<String, dynamic>> get _menuOptions => [
    {
      'title': TranslationService.t('dashboard'),
      'icon': Icons.dashboard,
      'color': Colors.blue,
      'index': 0,
    },
    {
      'title': TranslationService.t('expenses'),
      'icon': Icons.shopping_cart,
      'color': Colors.purple,
      'index': 1,
    },
    {
      'title': TranslationService.t('revenues'),
      'icon': Icons.trending_up,
      'color': Colors.green,
      'index': 2,
    },
    {
      'title': TranslationService.t('charges'),
      'icon': Icons.receipt_long,
      'color': Colors.red,
      'index': 3,
    },
    {
      'title': TranslationService.t('analysis'),
      'icon': Icons.analytics,
      'color': Colors.orange,
      'index': 4,
    },
    {
      'title': TranslationService.t('categories'),
      'icon': Icons.tag,
      'color': Colors.indigo,
      'index': 5,
    },
  ];

  // Navigation du bas (simplifiée) - utilisant le service de traduction
  List<NavigationDestination> get _mainDestinations => [
    NavigationDestination(
      icon: const Icon(Icons.dashboard_outlined),
      selectedIcon: const Icon(Icons.dashboard),
      label: TranslationService.t('dashboard'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.shopping_cart_outlined),
      selectedIcon: const Icon(Icons.shopping_cart),
      label: TranslationService.t('expenses'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.trending_up_outlined),
      selectedIcon: const Icon(Icons.trending_up),
      label: TranslationService.t('revenues'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.receipt_long_outlined),
      selectedIcon: const Icon(Icons.receipt_long),
      label: TranslationService.t('charges'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _trackScreenView();
  }

  Future<void> _trackScreenView() async {
    await _analytics.logScreenView(
      screenName: 'main_menu',
      screenClass: 'MainMenuScreen',
    );
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
    setState(() {
      _selectedIndex = tabIndex;
    });
    _pageController.animateToPage(
      tabIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _trackTabChange(tabIndex);
    Navigator.pop(context);
  }

  Future<void> _trackTabChange(int index) async {
    final tabNames = ['home', 'plaisirs', 'entrees', 'sorties', 'analyse', 'tags'];
    if (index < tabNames.length) {
      await _analytics.logEvent(
        name: 'tab_changed',
        parameters: {
          'tab_name': tabNames[index],
          'tab_index': index,
        },
      );
    }
  }

  void _onLanguageChanged() {
    setState(() {
      // Déclenche un rebuild pour mettre à jour les traductions
    });
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
            Row(
              children: [
                Icon(Icons.menu, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(
                  TranslationService.t('navigation'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Grid des options
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _menuOptions.length,
              itemBuilder: (context, index) {
                final option = _menuOptions[index];
                final isSelected = _selectedIndex == option['index'];
                
                return Material(
                  color: isSelected 
                      ? option['color'].withValues(alpha: 0.1)
                      : Colors.grey.shade50,
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
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showProfileMenu() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    await showModalBottomSheet(
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
            
            // Photo de profil et infos
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                user.email?.substring(0, 1).toUpperCase() ?? '?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.email ?? 'Utilisateur',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🔐 ${TranslationService.t('encrypted_data')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Options
            _buildMenuOption(
              icon: Icons.delete_forever,
              title: TranslationService.t('delete_all_data'),
              subtitle: 'Action irréversible',
              color: Colors.red,
              onTap: _confirmDeleteAllData,
            ),
            const SizedBox(height: 16),
            _buildMenuOption(
              icon: Icons.logout,
              title: TranslationService.t('logout'),
              subtitle: 'Retour à l\'écran de connexion',
              color: Colors.orange,
              onTap: () async {
                Navigator.pop(context);
                await _firebaseService.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAllData() async {
    Navigator.pop(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(TranslationService.t('delete_all_data')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ ATTENTION : Cette action est IRRÉVERSIBLE !',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 16),
            Text('Cela supprimera définitivement :'),
            SizedBox(height: 8),
            Text('• Tous vos revenus'),
            Text('• Toutes vos charges'),
            Text('• Toutes vos dépenses'),
            Text('• Votre solde bancaire'),
            Text('• Vos catégories personnalisées'),
            SizedBox(height: 16),
            Text(
              'Êtes-vous absolument certain de vouloir continuer ?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(TranslationService.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAllData();
    }
  }

  Future<void> _deleteAllData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('${TranslationService.t('loading')}'),
          ],
        ),
      ),
    );

    try {
      await _dataService.deleteAllUserData();
      
      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Toutes les données ont été supprimées'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de la suppression: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _firebaseService.currentUser;
    
    // Titres des onglets traduits
    final List<String> tabTitles = [
      TranslationService.t('dashboard'), 
      TranslationService.t('my_expenses'),
      TranslationService.t('revenues'), 
      TranslationService.t('charges'), 
      TranslationService.t('analysis'),
      TranslationService.t('categories'),
    ];

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
          tooltip: TranslationService.t('navigation'),
        ),
        actions: [
          // Sélecteur de langue
          LanguageSelector(
            onLanguageChanged: _onLanguageChanged,
          ),
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
              onPressed: _showProfileMenu,
              tooltip: TranslationService.t('profile'),
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _allTabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex < _mainTabs.length ? _selectedIndex : 0,
        destinations: _mainDestinations,
        onDestinationSelected: _onItemTapped,
      ),
    );
  }
}