import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/encrypted_budget_service.dart';
import '../services/encryption_service.dart';
import '../widgets/periodicity_selector.dart';

class EntreesTab extends StatefulWidget {
  final DateTime? selectedMonth; // Ajouter ce paramètre optionnel
  
  const EntreesTab({
    super.key,
    this.selectedMonth,
  });

  @override
  State<EntreesTab> createState() => _EntreesTabState();
}

class _EntreesTabState extends State<EntreesTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  List<Map<String, dynamic>> entrees = [];
  List<Map<String, dynamic>> filteredEntrees = [];
  double totalEntrees = 0.0;
  double soldeDisponible = 0.0;
  bool isLoading = false;

  // Variables de filtrage
  DateTime? _selectedFilterDate;
  String _currentFilter = 'Tous';

  // Variables pour sélection multiple
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};
  bool _isProcessingBatch = false;

  @override
  void initState() {
    super.initState();
    _loadEntrees();
  }

  Future<void> _loadEntrees() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await _dataService.getEntrees();
      
      setState(() {
        entrees = data;
        // Si un mois spécifique est sélectionné, filtrer automatiquement
        if (widget.selectedMonth != null) {
          _currentFilter = 'Mois';
          _selectedFilterDate = widget.selectedMonth;
          _applyFilter();
        } else {
          filteredEntrees = List.from(entrees);
          _calculateTotals();
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
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

  void _applyFilter() {
    if (_currentFilter == 'Tous' || _selectedFilterDate == null) {
      filteredEntrees = List.from(entrees);
    } else {
      filteredEntrees = entrees.where((entree) {
        final entreeDate = DateTime.tryParse(entree['date'] ?? '');
        if (entreeDate == null) return false;
        
        if (_currentFilter == 'Mois') {
          return entreeDate.year == _selectedFilterDate!.year &&
                 entreeDate.month == _selectedFilterDate!.month;
        } else if (_currentFilter == 'Année') {
          return entreeDate.year == _selectedFilterDate!.year;
        }
        return true;
      }).toList();
    }
    
    // Recalculer le total des entrées filtrées
    final filteredTotal = filteredEntrees.fold(0.0, 
      (sum, entree) => sum + ((entree['amount'] as num?)?.toDouble() ?? 0.0));
    
    setState(() {
      totalEntrees = filteredTotal;
    });
  }

  void _showFilterDialog() {
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
            
            const Text(
              'Filtrer les revenus',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Options de filtre
            ListTile(
              leading: Radio<String>(
                value: 'Tous',
                groupValue: _currentFilter,
                onChanged: (value) {
                  setState(() {
                    _currentFilter = value!;
                    _selectedFilterDate = null;
                  });
                  _applyFilter();
                  Navigator.pop(context);
                },
              ),
              title: const Text('Tous les revenus'),
              subtitle: Text('${entrees.length} revenus'),
            ),
            
            ListTile(
              leading: Radio<String>(
                value: 'Mois',
                groupValue: _currentFilter,
                onChanged: (value) async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _currentFilter = value!;
                      _selectedFilterDate = date;
                    });
                    _applyFilter();
                    if (!mounted) return; // Protection async
                    Navigator.pop(context);
                  }
                },
              ),
              title: const Text('Par mois'),
              subtitle: _currentFilter == 'Mois' && _selectedFilterDate != null
                  ? Text('${_getMonthName(_selectedFilterDate!.month)} ${_selectedFilterDate!.year}')
                  : const Text('Sélectionner un mois'),
            ),
            
            ListTile(
              leading: Radio<String>(
                value: 'Année',
                groupValue: _currentFilter,
                onChanged: (value) async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _currentFilter = value!;
                      _selectedFilterDate = date;
                    });
                    _applyFilter();
                    if (!mounted) return; // Protection async
                    Navigator.pop(context);
                  }
                },
              ),
              title: const Text('Par année'),
              subtitle: _currentFilter == 'Année' && _selectedFilterDate != null
                  ? Text('Année ${_selectedFilterDate!.year}')
                  : const Text('Sélectionner une année'),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month - 1];
  }

  // Ajout de la méthode _addEntree manquante
  Future<void> _addEntree() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddEntreeDialog(
        onAdd: (amount, description, date, periodicity) async {
          try {
            await _dataService.addEntree(
              amountStr: amount,
              description: description,
              date: date,
              periodicity: periodicity,
            );
            return true;
          } catch (e) {
            return false;
          }
        },
      ),
    );

    if (result != null && result['success'] == true) {
      _loadEntrees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revenu ajouté avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // Ajout de la méthode _editEntree manquante
  Future<void> _editEntree(int displayIndex) async {
    final entree = entrees[displayIndex];
    final entreeId = entree['id'] ?? '';
    
    // Trouver l'index réel
    final originalEntrees = await _dataService.getEntrees();
    final realIndex = originalEntrees.indexWhere((e) => e['id'] == entreeId);
    
    if (realIndex == -1) return;
    
    final result = await _showEntreeDialog(
      isEdit: true,
      description: entree['description'],
      amount: entree['amount'],
      date: DateTime.tryParse(entree['date'] ?? ''), // Ajouter la date existante
    );
    
    if (result != null) {
      try {
        await _dataService.updateEntree(
          index: realIndex,
          amountStr: result['amountStr'],
          description: result['description'],
          date: result['date'], // Ajouter la date
        );
        await _loadEntrees();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔐 Revenu modifié et chiffré avec succès'),
            backgroundColor: Colors.blue,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la modification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showEntreeDialog({
    String? description,
    double? amount,
    DateTime? date,
    bool isEdit = false,
  }) async {
    final descriptionController = TextEditingController(text: description ?? '');
    final montantController = TextEditingController(
      text: amount != null ? AmountParser.formatAmount(amount) : ''
    );
    // CORRECTION: Utiliser le mois sélectionné par défaut
    DateTime? selectedDate = date ?? widget.selectedMonth ?? DateTime.now();
    String? selectedPeriodicity = 'ponctuel';

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit : Icons.add,
                color: isEdit ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'Modifier le revenu' : 'Ajouter un revenu'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  helperText: 'Salaire, Prime, Freelance...',
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
                  helperText: 'Utilisez , ou . pour les décimales',
                ),
              ),
              const SizedBox(height: 16),
              // Sélecteur de date
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedDate != null 
                            ? '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}'
                            : 'Sélectionner une date',
                          style: TextStyle(
                            color: selectedDate != null ? Colors.black87 : Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                final desc = descriptionController.text.trim();
                final amountStr = montantController.text.trim();
                final montant = AmountParser.parseAmount(amountStr);
                if (desc.isNotEmpty && montant > 0 && selectedDate != null) {
                  Navigator.pop(context, {
                    'description': desc,
                    'amountStr': amountStr,
                    'date': selectedDate, // S'assurer que la date est bien passée
                    'periodicity': selectedPeriodicity,
                  });
                }
              },
              child: Text(isEdit ? 'Modifier' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEntree(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer ce revenu ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dataService.deleteEntree(index);
        await _loadEntrees();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revenu supprimé'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIndices.clear();
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _batchDeleteEntrees() async {
    if (_selectedIndices.isEmpty) return;

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer ${_selectedIndices.length} revenu(s) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessingBatch = true;
    });

    try {
      // Convertir les index d'affichage en index réels
      final originalEntrees = await _dataService.getEntrees();
      List<int> realIndices = [];
      
      for (int displayIndex in _selectedIndices) {
        final entree = filteredEntrees[displayIndex];
        final entreeId = entree['id'] ?? '';
        final realIndex = originalEntrees.indexWhere((e) => e['id'] == entreeId);
        
        if (realIndex != -1) {
          realIndices.add(realIndex);
        }
      }
      
      // Traiter dans l'ordre inverse pour éviter les décalages d'index
      realIndices.sort((a, b) => b.compareTo(a));
      
      for (int realIndex in realIndices) {
        await _dataService.deleteEntree(realIndex);
      }

      // Recharger les données
      await _loadEntrees();

      if (!mounted) return;

      // Sortir du mode sélection
      setState(() {
        _isSelectionMode = false;
        _selectedIndices.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${realIndices.length} revenu(s) supprimé(s)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingBatch = false;
        });
      }
    }
  }

  void _calculateTotals() {
    // Calculer le total des entrées
    totalEntrees = entrees.fold(0.0, (sum, entree) => sum + ((entree['amount'] as num?)?.toDouble() ?? 0.0));
    
    // Si un filtre est appliqué, recalculer le total des entrées filtrées
    if (_currentFilter != 'Tous' && _selectedFilterDate != null) {
      final filteredTotal = filteredEntrees.fold(0.0, 
        (sum, entree) => sum + ((entree['amount'] as num?)?.toDouble() ?? 0.0));
      
      setState(() {
        totalEntrees = filteredTotal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Chargement des revenus...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Contenu principal
          filteredEntrees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 100,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _currentFilter == 'Tous' 
                            ? 'Aucun revenu enregistré'
                            : 'Aucun revenu pour cette période',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ajoutez vos revenus (salaire, primes...)',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _addEntree,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un revenu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // En-tête avec totaux et filtres
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Revenus',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${AmountParser.formatAmount(totalEntrees)} €',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${filteredEntrees.length} revenu${filteredEntrees.length > 1 ? 's' : ''}${_currentFilter != 'Tous' ? ' • $_currentFilter' : ''}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              // Bouton de sélection multiple
                              if (!_isSelectionMode)
                                IconButton(
                                  onPressed: _toggleSelectionMode,
                                  icon: const Icon(Icons.checklist, color: Colors.white),
                                  tooltip: 'Sélection multiple',
                                ),
                              IconButton(
                                onPressed: _showFilterDialog,
                                icon: const Icon(Icons.filter_list, color: Colors.white),
                                tooltip: 'Filtrer',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredEntrees.length,
                        itemBuilder: (context, index) {
                          final entree = filteredEntrees[index];
                          final amount = (entree['amount'] as num?)?.toDouble() ?? 0;
                          final description = entree['description'] as String? ?? 'Sans description';
                          final date = DateTime.tryParse(entree['date'] ?? '') ?? DateTime.now();
                          final isSelected = _selectedIndices.contains(index);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            elevation: isSelected ? 8 : 2,
                            color: isSelected ? Colors.green.shade50 : null,
                            child: ListTile(
                              // Mode sélection
                              leading: _isSelectionMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleSelection(index),
                                      activeColor: Colors.green,
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: const Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ),
                              title: Text(
                                description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('dd/MM/yyyy').format(date),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              trailing: _isSelectionMode
                                  ? null
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '+ ${AmountParser.formatAmount(amount)} €',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'edit':
                                                _editEntree(index);
                                                break;
                                              case 'delete':
                                                _deleteEntree(index);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit, color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text('Modifier'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Supprimer'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(index)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

          // Barre d'actions en mode sélection
          if (_isSelectionMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  child: Row(
                    children: [
                      Text(
                        '${_selectedIndices.length} sélectionné(s)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          _isSelectionMode = false;
                          _selectedIndices.clear();
                        }),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _selectedIndices.isEmpty || _isProcessingBatch
                            ? null
                            : _batchDeleteEntrees,
                        icon: _isProcessingBatch
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                ),
                              )
                            : const Icon(Icons.delete),
                        label: Text(_isProcessingBatch ? 'Suppression...' : 'Supprimer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _addEntree,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _AddEntreeDialog extends StatefulWidget {
  final Future<bool> Function(String amount, String description, DateTime date, String periodicity) onAdd;

  const _AddEntreeDialog({required this.onAdd});

  @override
  State<_AddEntreeDialog> createState() => _AddEntreeDialogState();
}

class _AddEntreeDialogState extends State<_AddEntreeDialog> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedPeriodicity = 'ponctuel';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un revenu'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Champ montant
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.euro),
                  suffixText: '€',
                ),
              ),
              const SizedBox(height: 16),

              // Champ description
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),

              // Sélecteur de date
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 12),
                      Text(
                        'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sélecteur de périodicité
              PeriodicitySelector(
                selectedPeriodicity: _selectedPeriodicity,
                onChanged: (value) {
                  setState(() {
                    _selectedPeriodicity = value ?? 'ponctuel';
                  });
                },
                enabled: !_isLoading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleAdd,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Ajouter'),
        ),
      ],
    );
  }

  void _handleAdd() async {
    if (_amountController.text.trim().isEmpty || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs requis'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await widget.onAdd(
        _amountController.text,
        _descriptionController.text,
        _selectedDate,
        _selectedPeriodicity,
      );

      if (success && mounted) {
        Navigator.of(context).pop({'success': true});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}