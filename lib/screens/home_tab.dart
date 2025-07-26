import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  
  // Variables manquantes ajoutées
  bool isLoading = false;
  double totalEntrees = 0.0;
  double totalSorties = 0.0;
  double totalPlaisirs = 0.0;
  double soldeDisponible = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadAvailableTags();
    _tagController.addListener(_onTagTextChanged);
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
          const SnackBar(
            content: Text('Erreur de chargement des tags'),
            backgroundColor: Colors.red,
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

  // CORRECTION: Renommer _saveTransaction en _addExpense
  Future<void> _addExpense() async {
    if (_amountController.text.trim().isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir le montant et la date.'),
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
          content: Text('Veuillez entrer un montant valide.'),
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

      // Recharger les tags disponibles
      await _loadAvailableTags();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Dépense ajoutée avec succès'),
          backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section des soldes
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Solde prévisionnel',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            FutureBuilder<double>(
                              future: _dataService.getTotals().then((totals) => totals['solde'] ?? 0.0),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(
                                    '${AmountParser.formatAmount(snapshot.data!)} €',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Solde débité',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            FutureBuilder<double>(
                              future: _dataService.getSoldeDisponible(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(
                                    '${AmountParser.formatAmount(snapshot.data!)} €',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Icône et titre
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            const Text(
              'Ajouter une dépense',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                          ? 'Sélectionner une date'
                          : 'Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
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
                onPressed: _isLoading ? null : _addExpense,
                icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
                label: Text(
                  _isLoading 
                    ? 'Enregistrement...'
                    : 'Ajouter une dépense',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Text(
              '* Champs obligatoires',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}