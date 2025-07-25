import 'package:flutter/material.dart';
import '../services/encrypted_budget_service.dart';
import '../services/encryption_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  DateTime? _selectedDate;
  List<String> _availableTags = [];
  List<String> _filteredTags = [];
  bool _isLoading = false;
  double _currentBalance = 0.0;
  double _soldeDisponible = 0.0;
  double _totalPointe = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadAvailableTags();
    _tagController.addListener(_onTagTextChanged);
    _loadBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTags() async {
    try {
      final tags = await _dataService.getTags();
      setState(() {
        _availableTags = tags;
        _filteredTags = tags;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur chargement tags: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _onTagTextChanged() {
    final query = _tagController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTags = _availableTags;
      } else {
        _filteredTags = _availableTags
            .where((tag) => tag.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir le montant et sélectionner une date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Parse le montant avec support des virgules
    final amount = AmountParser.parseAmount(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un montant valide (utilisez , ou . pour les décimales)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final tag = _tagController.text.trim().isEmpty 
          ? 'Sans catégorie' 
          : _tagController.text.trim();

      // Les données sont automatiquement chiffrées !
      await _dataService.addPlaisir(
        amountStr: _amountController.text,
        tag: tag,
        date: _selectedDate,
      );

      // Réinitialiser le formulaire
      _amountController.clear();
      _tagController.clear();
      setState(() {
        _selectedDate = DateTime.now();
      });

      // Recharger les tags disponibles et les soldes
      await _loadAvailableTags();
      await _loadBalance();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💰 Dépense de ${AmountParser.formatAmount(amount)} € ajoutée avec succès !'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () {
              // Naviguer vers l'onglet des dépenses
              DefaultTabController.of(context)?.animateTo(1);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _dataService.getBankBalance();
      final solde = await _dataService.getSoldeDisponible();
      final totals = await _dataService.getTotals();
      
      setState(() {
        _currentBalance = balance;
        _soldeDisponible = solde;
        _totalPointe = totals['plaisirsTotaux'] ?? 0.0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur chargement solde: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _updateBalance() async {
    final TextEditingController controller = TextEditingController(
      text: AmountParser.formatAmount(_currentBalance),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet),
            SizedBox(width: 8),
            Text('Mettre à jour le solde'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Nouveau solde',
                prefixText: '€ ',
                border: OutlineInputBorder(),
                helperText: 'Utilisez , ou . pour les décimales',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ce montant sera automatiquement chiffré',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
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
            onPressed: () async {
              try {
                await _dataService.setBankBalance(controller.text);
                await _loadBalance();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔐 Solde mis à jour et chiffré avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête avec soldes
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 32,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Chiffré',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _updateBalance,
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Modifier le solde',
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  // Ligne des soldes
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Solde du compte',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${AmountParser.formatAmount(_currentBalance)} €',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Pointé',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white70,
                                  size: 12,
                                ),
                              ],
                            ),
                            Text(
                              '${AmountParser.formatAmount(_totalPointe)} €',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Disponible',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${AmountParser.formatAmount(_soldeDisponible)} €',
                              style: TextStyle(
                                color: _soldeDisponible >= 0 ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Icône et titre
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Ajouter une dépense',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Champ montant avec support virgules
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro),
                suffixText: '€',
                helperText: 'Utilisez , ou . pour les décimales (ex: 15,50 ou 15.50)',
              ),
            ),
            const SizedBox(height: 20),

            // Champ tag avec autocomplétion
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                    helperText: 'Restaurant, Shopping, Loisirs...',
                  ),
                ),
                if (_filteredTags.isNotEmpty && _tagController.text.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredTags.take(5).length,
                      itemBuilder: (context, index) {
                        final tag = _filteredTags[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.tag, size: 16),
                          title: Text(tag),
                          onTap: () {
                            _tagController.text = tag;
                            setState(() {
                              _filteredTags = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Sélecteur de date
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? 'Sélectionner une date *'
                          : 'Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate == null ? Colors.grey.shade600 : null,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Bouton de validation
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _saveTransaction,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _isLoading ? 'Chiffrement et sauvegarde...' : 'Ajouter la dépense',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Informations sur le système de pointage
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Système de pointage des dépenses',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Après avoir ajouté une dépense, vous pouvez la "pointer" dans l\'onglet Dépenses en appuyant dessus. Les dépenses pointées sont déduites de votre solde disponible.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            
            // Informations sur la sécurité
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🔐 Vos données financières sont automatiquement chiffrées avant d\'être envoyées dans le cloud. Même le développeur ne peut pas voir vos montants !',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '* Champs obligatoires',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}