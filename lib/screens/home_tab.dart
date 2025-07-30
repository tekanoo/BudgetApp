import 'package:flutter/material.dart';
import '../services/encrypted_budget_service.dart';
import '../utils/amount_parser.dart';

class HomeTab extends StatefulWidget {
  final DateTime? selectedMonth; // Ajouter ce paramètre optionnel
  
  const HomeTab({
    super.key,
    this.selectedMonth, // Paramètre optionnel pour garder la compatibilité
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  
  DateTime? _selectedDate;
  bool _isLoading = false;
  
  // Données du mois
  double _monthlyEntrees = 0.0;
  double _monthlySorties = 0.0;
  double _monthlyPlaisirs = 0.0;
  double _monthlySortiesPointees = 0.0;
  double _monthlyPlaisirsPointees = 0.0;
  List<String> _availableTags = [];
  
  @override
  void initState() {
    super.initState();
    // Si selectedMonth est fourni, l'utiliser comme date sélectionnée
    if (widget.selectedMonth != null) {
      _selectedDate = widget.selectedMonth;
    }
    _loadMonthlyData();
    _loadAvailableTags();
  }
  
  // Modifier la méthode _loadMonthlyData pour filtrer par mois si nécessaire
  Future<void> _loadMonthlyData() async {
    try {
      if (widget.selectedMonth != null) {
        // Filtrer par mois sélectionné
        final entrees = await _dataService.getEntrees();
        final sorties = await _dataService.getSorties();
        final plaisirs = await _dataService.getPlaisirs();
        
        // Filtrer par mois
        final monthlyEntrees = entrees.where((e) {
          final date = DateTime.tryParse(e['date'] ?? '');
          return date != null && 
                 date.year == widget.selectedMonth!.year &&
                 date.month == widget.selectedMonth!.month;
        }).fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
        
        final monthlySorties = sorties.where((s) {
          final date = DateTime.tryParse(s['date'] ?? '');
          return date != null && 
                 date.year == widget.selectedMonth!.year &&
                 date.month == widget.selectedMonth!.month;
        }).fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));
        
        final monthlyPlaisirs = plaisirs.where((p) {
          final date = DateTime.tryParse(p['date'] ?? '');
          return date != null && 
                 date.year == widget.selectedMonth!.year &&
                 date.month == widget.selectedMonth!.month;
        }).fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));
        
        // Calculer les montants pointés pour ce mois
        final monthlySortiesPointees = sorties.where((s) {
          final date = DateTime.tryParse(s['date'] ?? '');
          return date != null && 
                 date.year == widget.selectedMonth!.year &&
                 date.month == widget.selectedMonth!.month &&
                 s['isPointed'] == true;
        }).fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));
        
        final monthlyPlaisirsPointees = plaisirs.where((p) {
          final date = DateTime.tryParse(p['date'] ?? '');
          return date != null && 
                 date.year == widget.selectedMonth!.year &&
                 date.month == widget.selectedMonth!.month &&
                 p['isPointed'] == true;
        }).fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));
        
        setState(() {
          _monthlyEntrees = monthlyEntrees;
          _monthlySorties = monthlySorties;
          _monthlyPlaisirs = monthlyPlaisirs;
          _monthlySortiesPointees = monthlySortiesPointees;
          _monthlyPlaisirsPointees = monthlyPlaisirsPointees;
        });
      } else {
        // Comportement normal (toutes les données)
        final totals = await _dataService.getTotals();
        
        setState(() {
          _monthlyEntrees = totals['entrees'] ?? 0.0;
          _monthlySorties = totals['sorties'] ?? 0.0;
          _monthlyPlaisirs = totals['plaisirs'] ?? 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadAvailableTags() async {
    try {
      final plaisirs = await _dataService.getPlaisirs();
      final tags = plaisirs
          .map((p) => p['tag'] as String? ?? '')
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();
      
      setState(() {
        _availableTags = tags;
      });
    } catch (e) {
      // Gestion d'erreur silencieuse
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Afficher le mois sélectionné si spécifié
    final monthName = widget.selectedMonth != null 
        ? _getMonthName(widget.selectedMonth!)
        : 'Budget Global';
    final solde = _monthlyEntrees - _monthlySorties - _monthlyPlaisirs;
    
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec titre du mois
            if (widget.selectedMonth != null) ...[
              Text(
                'Dashboard - $monthName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Cartes de résumé
            _buildSummaryCards(solde),
            
            const SizedBox(height: 20),
            
            // Section d'ajout rapide
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ajout rapide - Dépense',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Montant',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.euro),
                              suffixText: '€',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _tagController,
                            decoration: InputDecoration(
                              labelText: 'Catégorie',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.tag),
                              suffixIcon: _availableTags.isNotEmpty
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) {
                                        _tagController.text = value;
                                      },
                                      itemBuilder: (context) => _availableTags
                                          .map((tag) => PopupMenuItem(
                                                value: tag,
                                                child: Text(tag),
                                              ))
                                          .toList(),
                                      icon: const Icon(Icons.arrow_drop_down),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedDate != null 
                                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                        : 'Sélectionner une date',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _addExpense, // CORRECTION: Changer _addQuickPlaisir en _addExpense
                          icon: _isLoading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add),
                          label: const Text('Ajouter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Méthode pour obtenir le nom du mois
  String _getMonthName(DateTime date) {
    const monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  Widget _buildSummaryCards(double solde) {
    final soldeDebiteCalcule = _monthlyEntrees - _monthlySortiesPointees - _monthlyPlaisirsPointees;
    
    return Column(
      children: [
        // NOUVELLE SECTION : Seulement Solde Prévu et Solde Débité
        Row(
          children: [
            // Solde Prévu
            Expanded(
              child: Card(
                color: solde >= 0 ? Colors.blue.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        solde >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: solde >= 0 ? Colors.blue.shade600 : Colors.red.shade600,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Solde Prévu',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${AmountParser.formatAmount(solde)} €',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: solde >= 0 ? Colors.blue.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Solde Débité
            Expanded(
              child: Card(
                color: soldeDebiteCalcule >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        soldeDebiteCalcule >= 0 ? Icons.check_circle : Icons.warning,
                        color: soldeDebiteCalcule >= 0 ? Colors.green.shade600 : Colors.red.shade600,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Solde Débité',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${AmountParser.formatAmount(soldeDebiteCalcule)} €',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: soldeDebiteCalcule >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // SECTION DÉTAILS : Revenus, Charges, Dépenses (en plus petit)
        Card(
          color: Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Détails',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDetailItem('Revenus', _monthlyEntrees, Colors.green, Icons.trending_up),
                    _buildDetailItem('Charges', _monthlySorties, Colors.red, Icons.receipt_long),
                    _buildDetailItem('Dépenses', _monthlyPlaisirs, Colors.purple, Icons.shopping_cart),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // NOUVELLE MÉTHODE : Widget pour les détails en petit
  Widget _buildDetailItem(String label, double amount, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(
          '${AmountParser.formatAmount(amount)} €',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Limiter le sélecteur de date au mois sélectionné
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? widget.selectedMonth ?? DateTime.now(),
      firstDate: widget.selectedMonth != null 
          ? DateTime(widget.selectedMonth!.year, widget.selectedMonth!.month, 1)
          : DateTime(2020),
      lastDate: widget.selectedMonth != null 
          ? DateTime(widget.selectedMonth!.year, widget.selectedMonth!.month + 1, 0)
          : DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  // Renommer la méthode pour plus de clarté
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

      await _dataService.addPlaisir(
        amountStr: _amountController.text,
        tag: tag,
        date: _selectedDate,
      );

      // Recharger les données du mois
      await _loadMonthlyData();
      await _loadAvailableTags();

      // Réinitialiser le formulaire
      _amountController.clear();
      _tagController.clear();

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
}