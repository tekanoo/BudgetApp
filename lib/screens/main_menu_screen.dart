import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  final List<Widget> _tabs = const [
    HomeTab(),
    PlaisirsTab(),
    EntreesTab(),
    SortiesTab(),
    AnalyseTab(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.celebration_outlined),
      selectedIcon: Icon(Icons.celebration),
      label: 'Plaisirs',
    ),
    NavigationDestination(
      icon: Icon(Icons.trending_up_outlined),
      selectedIcon: Icon(Icons.trending_up),
      label: 'Entrées',
    ),
    NavigationDestination(
      icon: Icon(Icons.trending_down_outlined),
      selectedIcon: Icon(Icons.trending_down),
      label: 'Sorties',
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
    _loadConnectionStatus();
  }

  Future<void> _loadConnectionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isConnected = prefs.getBool('isConnected') ?? false;
    final userEmail = prefs.getString('userEmail');
    
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
        _userEmail = userEmail;
      });
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
              const SizedBox(height: 8),
              const Text(
                'Vos données sont synchronisées de manière sécurisée.',
                style: TextStyle(color: Colors.green),
              ),
            ] else ...[
              const Text(
                'Connectez-vous pour synchroniser vos données de manière sécurisée.',
              ),
            ],
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

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await GoogleSignIn().signIn();
      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isConnected', true);
        await prefs.setString('userEmail', account.email);
        
        if (mounted) {
          setState(() {
            _isConnected = true;
            _userEmail = account.email;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connexion réussie !'),
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
      await GoogleSignIn().signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isConnected', false);
      await prefs.remove('userEmail');
      
      if (mounted) {
        setState(() {
          _isConnected = false;
          _userEmail = null;
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
          ['Nouvelle dépense', 'Mes Plaisirs', 'Entrées', 'Sorties', 'Analyse'][_selectedIndex],
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
        onPressed: () => _showQuickAddDialog(context),
        icon: const Icon(Icons.add),
        label: Text(_selectedIndex == 2 ? 'Entrée' : 'Sortie'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ) : null,
    );
  }

  void _showQuickAddDialog(BuildContext context) {
    final descController = TextEditingController();
    final montantController = TextEditingController();
    final isEntree = _selectedIndex == 2;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isEntree ? Icons.trending_up : Icons.trending_down,
              color: isEntree ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text('Ajouter ${isEntree ? 'une entrée' : 'une sortie'}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: montantController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro),
                suffixText: '€',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final desc = descController.text.trim();
              final montant = montantController.text.trim();
              
              if (desc.isNotEmpty && montant.isNotEmpty && double.tryParse(montant) != null) {
                _saveTransaction(desc, double.parse(montant), isEntree);
                Navigator.pop(context);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${isEntree ? 'Entrée' : 'Sortie'} ajoutée avec succès'),
                      backgroundColor: isEntree ? Colors.green : Colors.orange,
                    ),
                  );
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransaction(String description, double montant, bool isEntree) async {
    final prefs = await SharedPreferences.getInstance();
    final key = isEntree ? 'entrees' : 'sorties';
    final existing = prefs.getStringList(key) ?? [];
    
    final transaction = {'description': description, 'montant': montant.toString()};
    existing.add(transaction.toString());
    
    await prefs.setStringList(key, existing);
  }
}