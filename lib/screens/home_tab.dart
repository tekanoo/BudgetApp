import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      final entrees = await _dataService.getEntrees();
      final sorties = await _dataService.getSorties();
      final plaisirs = await _dataService.getPlaisirs();
      
      // Si un mois spécifique est sélectionné, filtrer les données
      if (widget.selectedMonth != null) {
        final monthlyEntrees = entrees.where((e) {
          final date = DateTime.tryParse(e['date'] ?? '');
          return date != null && 
                 date.year == widget.selectedMonth!.year &&
                 date.month == widget.selectedMonth!.month;
        }).toList();
        
        final monthlySorties = sorties.where((s) {
          final date = DateTime.tryParse(s['date'] ?? '');
          return date != null && 
                 date.year == widget.selectedMonth!.year &&
                 date.month == widget.selectedMonth!.month;
        }).toList();
        
        final monthlyPlaisirs = plaisirs.where((p) {
          final date = DateTime.tryParse(p['date'] ?? '');
          return date != null && 
                 date.year == widget.selectedMonth!.year &&
                 date.month == widget.selectedMonth!.month;
        }).toList();
        
        setState(() {
          _monthlyEntrees = monthlyEntrees.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
          _monthlySorties = monthlySorties.fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));
          _monthlyPlaisirs = monthlyPlaisirs.fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));
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
    final monthName = widget.selectedMonth != null 
        ? DateFormat('MMMM yyyy', 'fr_FR').format(widget.selectedMonth!)
        : 'Budget Global';
    final solde = _monthlyEntrees - _monthlySorties - _monthlyPlaisirs;
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carte de résumé mensuel
            Card(
              elevation: 8,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Budget $monthName',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem('Revenus', _monthlyEntrees, Colors.green),
                        _buildSummaryItem('Charges', _monthlySorties, Colors.red),
                        _buildSummaryItem('Dépenses', _monthlyPlaisirs, Colors.purple),
                      ],
                    ),
                    const Divider(color: Colors.white54, height: 30),
                    _buildSummaryItem(
                      'Solde',
                      solde,
                      solde >= 0 ? Colors.green : Colors.red,
                      isLarge: true,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Formulaire d'ajout de dépense (comme votre HomeTab actuel)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ajouter une dépense',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // Champ montant
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.euro),
                        suffixText: '€',
                        helperText: 'Utilisez , ou . pour les décimales',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Champ catégorie avec suggestions
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
                        if (_availableTags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _availableTags.take(6).map((tag) => 
                              ActionChip(
                                label: Text(tag),
                                onPressed: () {
                                  _tagController.text = tag;
                                },
                              ),
                            ).toList(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sélecteur de date (pré-rempli avec le mois sélectionné)
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

                    // Bouton d'ajout
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem(String label, double amount, Color color, {bool isLarge = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isLarge ? 16 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2).replaceAll('.', ',')}€',
          style: TextStyle(
            color: Colors.white,
            fontSize: isLarge ? 24 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
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