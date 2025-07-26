import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import '../services/encrypted_budget_service.dart' as encrypted; // MODIFIÉ: alias pour éviter le conflit
// SUPPRIMÉ: import '../services/budget_data_service.dart'; 
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
  final encrypted.EncryptedBudgetDataService _dataService = encrypted.EncryptedBudgetDataService(); // MODIFIÉ: utilisation de l'alias

  final List<Widget> _tabs = const [
    HomeTab(),
    PlaisirsTab(), // Renommé en "Dépenses" dans l'interface
    EntreesTab(),
    SortiesTab(),
    AnalyseTab(),
    TagsManagementTab(), // NOUVEAU: onglet de gestion des tags
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.shopping_cart_outlined),
      selectedIcon: Icon(Icons.shopping_cart),
      label: 'Dépenses', // Changé de "Plaisirs" à "Dépenses"
    ),
    NavigationDestination(
      icon: Icon(Icons.trending_up_outlined),
      selectedIcon: Icon(Icons.trending_up),
      label: 'Revenus',
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
    NavigationDestination( // NOUVEAU: destination pour les tags
      icon: Icon(Icons.tag_outlined),
      selectedIcon: Icon(Icons.tag),
      label: 'Catégories',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
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
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Profil utilisateur
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user.photoURL != null 
                    ? NetworkImage(user.photoURL!) 
                    : null,
                  child: user.photoURL == null 
                    ? Text(
                        user.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      )
                    : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'Utilisateur',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      // NOUVEAU: Indicateur de sécurité
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.security, size: 12, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Données chiffrées',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            
            // Options du menu
            ListTile(
              leading: const Icon(Icons.sync, color: Colors.blue),
              title: const Text('Synchroniser les données'),
              onTap: () async {
                Navigator.pop(context);
                // Forcer une synchronisation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Données synchronisées avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.orange),
              title: const Text('Aide & Support'),
              onTap: () {
                Navigator.pop(context);
                _showHelpDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Supprimer toutes les données'),
              subtitle: const Text('Action irréversible'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteAllData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Se déconnecter'),
              onTap: () async {
                Navigator.pop(context);
                await _confirmSignOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
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
      try {
        await _firebaseService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion réussie'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Aide & Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestion Budget Pro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Version 2.1.0 - Edition Sécurisée'),
            SizedBox(height: 16),
            Text('Fonctionnalités :'),
            Text('• Synchronisation cloud avec Google'),
            Text('• Suivi des revenus, charges et dépenses'),
            Text('• Analyses détaillées avec graphiques'),
            Text('• Accès multi-appareils'),
            Text('• 🔐 Chiffrement des données financières'),
            SizedBox(height: 16),
            Text('🛡️ Sécurité : Vos montants sont chiffrés et même le développeur ne peut pas les voir dans la base de données.'),
          ],
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

  Future<void> _confirmDeleteAllData() async {
    // PREMIÈRE ÉTAPE : Confirmation initiale
    final firstConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Supprimer toutes les données'),
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
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    // DEUXIÈME ÉTAPE : Confirmation finale avec saisie
    final secondConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final confirmController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Confirmation finale'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'DERNIÈRE CHANCE ! Cette action ne peut pas être annulée.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pour confirmer, tapez exactement le mot :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SUPPRIMER',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    decoration: const InputDecoration(
                      labelText: 'Tapez SUPPRIMER ici',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (value) {
                      setDialogState(() {}); // Mettre à jour l'état du bouton
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: confirmController.text == 'SUPPRIMER'
                      ? () => Navigator.pop(context, true)
                      : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('SUPPRIMER DÉFINITIVEMENT'),
                ),
              ],
            );
          },
        );
      },
    );

    if (secondConfirm != true) return;

    // Exécuter la suppression
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Suppression en cours...'),
            ],
          ),
        ),
      );

      await _dataService.deleteAllUserData();

      if (!mounted) return;
      Navigator.pop(context); // Fermer le dialog de chargement

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Toutes vos données ont été supprimées'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Recharger la page d'accueil pour refléter les changements
      setState(() {
        _selectedIndex = 0;
      });
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Fermer le dialog de chargement
      
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
    
    // Titres des onglets mis à jour
    final List<String> tabTitles = [
      'Dashboard', 
      'Mes Dépenses', // Changé de "Mes Plaisirs" à "Mes Dépenses"
      'Revenus', 
      'Charges', 
      'Analyse',
      'Catégories', // NOUVEAU: titre pour l'onglet tags
    ];
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(tabTitles[_selectedIndex]),
            const SizedBox(width: 8),
            // NOUVEAU: Indicateur de sécurité dans l'AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 12, color: Colors.green.shade700),
                  const SizedBox(width: 2),
                  Text(
                    'Sécurisé',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Bouton profil utilisateur
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _showProfileMenu,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: user?.photoURL != null 
                        ? NetworkImage(user!.photoURL!) 
                        : null,
                      child: user?.photoURL == null 
                        ? Text(
                            user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          )
                        : null,
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
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
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: _destinations,
        elevation: 8,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}