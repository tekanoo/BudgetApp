import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/encrypted_budget_service.dart';
import '../utils/amount_parser.dart'; // GARDER SEULEMENT CELUI-CI

class SortiesTab extends StatefulWidget {
  final DateTime? selectedMonth;
  
  const SortiesTab({
    super.key,
    this.selectedMonth,
  });

  @override
  State<SortiesTab> createState() => _SortiesTabState();
}

class _SortiesTabState extends State<SortiesTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  List<Map<String, dynamic>> sorties = [];
  List<Map<String, dynamic>> filteredSorties = [];
  double totalSorties = 0.0;
  double totalPointe = 0.0;
  double soldeDisponible = 0.0;
  bool isLoading = false;

  // Variables de filtrage
  DateTime? _selectedFilterDate;
  String _currentFilter = 'Tous';

  // Variables pour la sélection multiple
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};
  bool _isProcessingBatch = false;

  // Variables financières
  double totalRevenus = 0.0;
  double totalDepenses = 0.0;
  double totalDepensesPointees = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSorties();
  }

  Future<void> _loadSorties() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await _dataService.getSorties();
      
      // Charger TOUTES les données pour les calculs
      final entreesData = await _dataService.getEntrees();
      final plaisirsData = await _dataService.getPlaisirs();
      
      setState(() {
        sorties = data;
        
        // Calculer les totaux selon le mois sélectionné
        if (widget.selectedMonth != null) {
          // Calculs mensuels pour le mois sélectionné
          totalRevenus = entreesData.where((e) {
            final date = DateTime.tryParse(e['date'] ?? '');
            return date != null && 
                   date.year == widget.selectedMonth!.year &&
                   date.month == widget.selectedMonth!.month;
          }).fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
          
          totalDepenses = plaisirsData.where((p) {
            final date = DateTime.tryParse(p['date'] ?? '');
            return date != null && 
                   date.year == widget.selectedMonth!.year &&
                   date.month == widget.selectedMonth!.month;
          }).fold(0.0, (sum, p) {
            final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
            if (p['isCredit'] == true) {
              return sum - amount; // Les crédits réduisent le total des dépenses
            } else {
              return sum + amount; // Les dépenses normales augmentent le total
            }
          });
          
          totalDepensesPointees = plaisirsData.where((p) {
            final date = DateTime.tryParse(p['date'] ?? '');
            return date != null && 
                   date.year == widget.selectedMonth!.year &&
                   date.month == widget.selectedMonth!.month &&
                   p['isPointed'] == true;
          }).fold(0.0, (sum, p) {
            final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
            if (p['isCredit'] == true) {
              return sum - amount; // Les crédits pointés réduisent
            } else {
              return sum + amount; // Les dépenses pointées augmentent
            }
          });
        } else {
          // Calculs globaux (code existant)
          totalRevenus = entreesData.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
          totalDepenses = plaisirsData.fold(0.0, (sum, p) {
            final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
            if (p['isCredit'] == true) {
              return sum - amount;
            } else {
              return sum + amount;
            }
          });
          
          totalDepensesPointees = plaisirsData
              .where((p) => p['isPointed'] == true)
              .fold(0.0, (sum, p) {
                final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                if (p['isCredit'] == true) {
                  return sum - amount;
                } else {
                  return sum + amount;
                }
              });
        }
        
        // Si un mois spécifique est sélectionné, filtrer automatiquement
        if (widget.selectedMonth != null) {
          _currentFilter = 'Mois';
          _selectedFilterDate = widget.selectedMonth;
          _applyFilter();
        } else {
          filteredSorties = List.from(sorties);
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
      filteredSorties = List.from(sorties);
      // Restaurer les totaux globaux
      _loadSorties();
    } else {
      filteredSorties = sorties.where((sortie) {
        final sortieDate = DateTime.tryParse(sortie['date'] ?? '');
        if (sortieDate == null) return false;
        
        if (_currentFilter == 'Mois') {
          return sortieDate.year == _selectedFilterDate!.year &&
                 sortieDate.month == _selectedFilterDate!.month;
        } else if (_currentFilter == 'Année') {
          return sortieDate.year == _selectedFilterDate!.year;
        }
        return true;
      }).toList();
      
      _calculateTotals();
    }
  }

  void _calculateTotals() {
    // Calcul des charges filtrées
    totalSorties = filteredSorties.fold(0.0, 
      (sum, sortie) => sum + ((sortie['amount'] as num?)?.toDouble() ?? 0.0));
    
    totalPointe = filteredSorties
        .where((s) => s['isPointed'] == true)
        .fold(0.0, (sum, sortie) => sum + ((sortie['amount'] as num?)?.toDouble() ?? 0.0));
    
    // CORRECTION : Recalculer les dépenses selon le filtre appliqué
    if (_currentFilter != 'Tous' && _selectedFilterDate != null) {
      // Recharger les dépenses avec le même filtre que les charges
      _loadDepensesByFilter();
    }
    
    setState(() {});
  }

  // Nouvelle méthode pour recalculer les dépenses selon le filtre
  Future<void> _loadDepensesByFilter() async {
    try {
      final plaisirsData = await _dataService.getPlaisirs();
      
      // Filtrer les dépenses avec les mêmes critères que les charges
      final filteredPlaisirs = plaisirsData.where((p) {
        final date = DateTime.tryParse(p['date'] ?? '');
        if (date == null) return false;
        
        if (_currentFilter == 'Mois') {
          return date.year == _selectedFilterDate!.year &&
                 date.month == _selectedFilterDate!.month;
        } else if (_currentFilter == 'Année') {
          return date.year == _selectedFilterDate!.year;
        }
        return true;
      }).toList();
      
      // Recalculer totalDepenses avec les dépenses filtrées
      totalDepenses = filteredPlaisirs.fold(0.0, (sum, p) {
        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        if (p['isCredit'] == true) {
          return sum - amount; // Les crédits réduisent le total des dépenses
        } else {
          return sum + amount; // Les dépenses normales augmentent le total
        }
      });
      
      // Recalculer totalDepensesPointees avec les dépenses filtrées ET pointées
      totalDepensesPointees = filteredPlaisirs
          .where((p) => p['isPointed'] == true)
          .fold(0.0, (sum, p) {
            final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
            if (p['isCredit'] == true) {
              return sum - amount; // Les crédits pointés réduisent
            } else {
              return sum + amount; // Les dépenses pointées augmentent
            }
          });
      
      setState(() {});
    } catch (e) {
      print('Erreur lors du recalcul des dépenses filtrées: $e');
    }
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
              'Filtrer les charges',
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
              title: const Text('Toutes les charges'),
              subtitle: Text('${sorties.length} charges'),
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
                  if (date != null && mounted) {
                    setState(() {
                      _currentFilter = value!;
                      _selectedFilterDate = date;
                    });
                    _applyFilter();
                    if (mounted) {
                      Navigator.pop(context);
                    }
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
                  if (date != null && mounted) {
                    setState(() {
                      _currentFilter = value!;
                      _selectedFilterDate = DateTime(date.year);
                    });
                    _applyFilter();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
              ),
              title: const Text('Par année'),
              subtitle: _currentFilter == 'Année' && _selectedFilterDate != null
                  ? Text(_selectedFilterDate!.year.toString())
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

  Future<void> _togglePointing(int displayIndex) async {
    if (!mounted) return;
    
    try {
      final sortieToToggle = filteredSorties[displayIndex];
      final sortieId = sortieToToggle['id'] ?? '';
      
      final originalSorties = await _dataService.getSorties();
      final realIndex = originalSorties.indexWhere((s) => s['id'] == sortieId);
      
      if (realIndex == -1) {
        throw Exception('Charge non trouvée');
      }
      
      await _dataService.toggleSortiePointing(realIndex);
      await _loadSorties();
      
      if (!mounted) return;
      final isPointed = sortieToToggle['isPointed'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !isPointed 
              ? '✅ Charge pointée - Solde mis à jour'
              : '↩️ Charge dépointée - Solde mis à jour'
          ),
          backgroundColor: !isPointed ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du pointage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addSortie() async {
    final result = await _showSortieDialog();
    if (result != null) {
      try {
        await _dataService.addSortie(
          amountStr: result['amount'].toString(),
          description: result['description'],
          date: result['date'],
          // Suppression du paramètre periodicity
        );
        await _loadSorties();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Charge ajoutée'),
              backgroundColor: Colors.green,
            ),
          );
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
      }
    }
  }

  Future<void> _editSortie(int displayIndex) async {
    final sortie = filteredSorties[displayIndex];
    final sortieId = sortie['id'] ?? '';
    
    final originalSorties = await _dataService.getSorties();
    final realIndex = originalSorties.indexWhere((s) => s['id'] == sortieId);
    
    if (realIndex == -1) return;
    
    final result = await _showSortieDialog(
      description: sortie['description'],
      amount: (sortie['amount'] as num?)?.toDouble(),
      date: DateTime.tryParse(sortie['date'] ?? ''),
      isEdit: true,
    );
    
    if (result != null) {
      try {
        await _dataService.updateSortie(
          index: realIndex,
          amountStr: result['amount'].toString(),
          description: result['description'],
          date: result['date'],
          // Suppression du paramètre periodicity
        );
        await _loadSorties();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Charge modifiée'),
              backgroundColor: Colors.green,
            ),
          );
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
      }
    }
  }

  Future<void> _deleteSortie(int index) async {
    final sortie = filteredSorties[index];
    final sortieId = sortie['id'] ?? '';
    
    final originalSorties = await _dataService.getSorties();
    final realIndex = originalSorties.indexWhere((s) => s['id'] == sortieId);
    
    if (realIndex == -1) return;
    
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la charge'),
        content: Text('Voulez-vous vraiment supprimer "${sortie['description']}" ?'),
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

    if (confirmed == true && mounted) {
      try {
        await _dataService.deleteSortie(realIndex);
        await _loadSorties();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Charge supprimée'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == filteredSorties.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices = Set.from(List.generate(filteredSorties.length, (index) => index));
      }
    });
  }

  Future<void> _batchTogglePointing() async {
    if (_selectedIndices.isEmpty) return;

    setState(() {
      _isProcessingBatch = true;
    });

    try {
      final originalSorties = await _dataService.getSorties();
      List<int> realIndices = [];
      
      for (int displayIndex in _selectedIndices) {
        final sortie = filteredSorties[displayIndex];
        final sortieId = sortie['id'] ?? '';
        final realIndex = originalSorties.indexWhere((s) => s['id'] == sortieId);
        
        if (realIndex != -1) {
          realIndices.add(realIndex);
        }
      }
      
      realIndices.sort((a, b) => b.compareTo(a));
      
      for (int realIndex in realIndices) {
        await _dataService.toggleSortiePointing(realIndex);
      }

      await _loadSorties();

      if (!mounted) return;
      
      setState(() {
        _isSelectionMode = false;
        _selectedIndices.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${realIndices.length} charge(s) mise(s) à jour'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du traitement: $e'),
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

  Future<Map<String, dynamic>?> _showSortieDialog({
    String? description,
    double? amount,
    DateTime? date,
    bool isEdit = false,
  }) async {
    final descriptionController = TextEditingController(text: description ?? '');
    final montantController = TextEditingController(
      text: amount != null ? AmountParser.formatAmount(amount) : ''
    );
    DateTime? selectedDate = date ?? (widget.selectedMonth ?? DateTime.now());

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit : Icons.add,
                color: isEdit ? Colors.blue : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'Modifier la charge' : 'Ajouter une charge'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    helperText: 'Loyer, Électricité, Internet...',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montantController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Montant (€)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.euro),
                    helperText: 'Ex: 50.00',
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
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
                          'Date: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                // Suppression du sélecteur de périodicité
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (descriptionController.text.trim().isNotEmpty &&
                    montantController.text.trim().isNotEmpty &&
                    selectedDate != null) {
                  Navigator.pop(context, {
                    'description': descriptionController.text.trim(),
                    'amount': AmountParser.parseAmount(montantController.text),
                    'date': selectedDate,
                    'success': true,
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

  Widget _buildFinancialHeader() {
    // CORRECTION : Calcul correct du solde avec prise en compte des crédits dans les dépenses
    final soldePrevu = totalRevenus - totalSorties - totalDepenses;
    
    // Pour le solde débité, on utilise les charges pointées ET les dépenses pointées
    final soldeDebite = totalRevenus - totalPointe - totalDepensesPointees;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ligne de contrôles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 8),
              Row(
                children: [
                  if (filteredSorties.isNotEmpty)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isSelectionMode = !_isSelectionMode;
                          if (!_isSelectionMode) {
                            _selectedIndices.clear();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: Icon(
                          _isSelectionMode ? Icons.close : Icons.checklist,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showFilterDialog,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // CORRECTION : Affichage du total net des charges (charges - remboursements des dépenses)
          Column(
            children: [
              const Text(
                'Charges nettes',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                '${AmountParser.formatAmount(totalSorties + totalDepenses)} €',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (totalDepenses != 0)
                Text(
                  '(${AmountParser.formatAmount(totalSorties)} € charges ${totalDepenses > 0 ? '+' : '-'} ${AmountParser.formatAmount(totalDepenses.abs())} € ${totalDepenses > 0 ? 'dépenses' : 'remboursements'})',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Soldes prévu et débité
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Solde Prévu',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '${AmountParser.formatAmount(soldePrevu)} €',
                        style: TextStyle(
                          color: soldePrevu >= 0 ? Colors.white : Colors.orange.shade200,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Solde Débité',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${AmountParser.formatAmount(soldeDebite)} €',
                        style: TextStyle(
                          color: soldeDebite >= 0 ? Colors.green.shade200 : Colors.orange.shade200,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 5),
          Text(
            '${filteredSorties.length} charge${filteredSorties.length > 1 ? 's' : ''} • ${filteredSorties.where((s) => s['isPointed'] == true).length} pointée${filteredSorties.where((s) => s['isPointed'] == true).length > 1 ? 's' : ''}${_currentFilter != 'Tous' ? ' • $_currentFilter' : ''}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
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
              Text('Chargement des charges...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // AJOUTER un FloatingActionButton pour toujours avoir accès au bouton d'ajout
      floatingActionButton: FloatingActionButton(
        onPressed: _addSortie,
        backgroundColor: Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Ajouter une charge',
      ),
      body: Stack(
        children: [
          filteredSorties.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 100,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _currentFilter == 'Tous' 
                            ? 'Aucune charge enregistrée'
                            : 'Aucune charge pour cette période',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ajoutez vos charges fixes et variables',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      // RETIRER ce bouton car on a maintenant le FloatingActionButton
                      // const SizedBox(height: 30),
                      // ElevatedButton.icon(
                      //   onPressed: _addSortie,
                      //   icon: const Icon(Icons.add),
                      //   label: const Text('Ajouter une charge'),
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: Colors.red,
                      //     foregroundColor: Colors.white,
                      //   ),
                      // ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // En-tête avec totaux et filtres
                    _buildFinancialHeader(),

                    // Barre d'outils avec bouton sélection multiple
                    if (filteredSorties.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isSelectionMode = !_isSelectionMode;
                                  if (!_isSelectionMode) {
                                    _selectedIndices.clear();
                                  }
                                });
                              },
                              icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
                              label: Text(_isSelectionMode ? 'Annuler' : 'Sélection multiple'),
                            ),
                            const Spacer(),
                            // AJOUTER un bouton d'ajout dans la barre d'outils aussi
                            IconButton(
                              onPressed: _addSortie,
                              icon: const Icon(Icons.add),
                              tooltip: 'Ajouter une charge',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Liste des charges filtrées
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredSorties.length,
                        itemBuilder: (context, index) {
                          final sortie = filteredSorties[index];
                          final amount = (sortie['amount'] as num?)?.toDouble() ?? 0;
                          final description = sortie['description'] as String? ?? '';
                          final dateStr = sortie['date'] as String? ?? '';
                          final date = DateTime.tryParse(dateStr);
                          final isPointed = sortie['isPointed'] == true;
                          final isSelected = _selectedIndices.contains(index);
                          final pointedAt = sortie['pointedAt'] != null 
                              ? DateTime.tryParse(sortie['pointedAt'] as String)
                              : null;
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? Colors.blue.shade50 
                                  : (isPointed ? Colors.green.shade50 : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                    ? Colors.blue.shade300
                                    : (isPointed ? Colors.green.shade300 : Colors.grey.shade200),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              // Case à cocher en mode sélection
                              leading: _isSelectionMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (value) => _toggleSelection(index),
                                      activeColor: Colors.blue,
                                    )
                                  : GestureDetector(
                                      onTap: () => _togglePointing(index),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isPointed ? Colors.green.shade100 : 
                                                 (sortie['type'] == 'fixe' ? Colors.red.shade100 : Colors.orange.shade100),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isPointed ? Colors.green.shade300 : 
                                                   (sortie['type'] == 'fixe' ? Colors.red.shade300 : Colors.orange.shade300),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          isPointed ? Icons.check_circle : Icons.radio_button_unchecked,
                                          color: isPointed ? Colors.green.shade700 : 
                                                 (sortie['type'] == 'fixe' ? Colors.red.shade700 : Colors.orange.shade700),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      description,
                                      style: TextStyle(
                                        fontWeight: sortie['type'] == 'fixe' ? FontWeight.bold : FontWeight.normal,
                                        color: isPointed ? Colors.green.shade700 : null,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${AmountParser.formatAmount(amount)} €',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isPointed ? Colors.green.shade700 : 
                                                 (sortie['type'] == 'fixe' ? Colors.red : Colors.orange),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.lock_open,
                                        size: 12,
                                        color: isPointed ? Colors.green.shade400 : 
                                               (sortie['type'] == 'fixe' ? Colors.red.shade400 : Colors.orange.shade400),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        sortie['type'] == 'fixe' 
                                            ? Icons.repeat 
                                            : Icons.show_chart,
                                        size: 16,
                                        color: isPointed ? Colors.green.shade600 : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        sortie['type'] == 'fixe' 
                                            ? 'Charge fixe mensuelle'
                                            : 'Charge variable',
                                        style: TextStyle(
                                          color: isPointed ? Colors.green.shade600 : Colors.grey,
                                        ),
                                      ),
                                      if (date != null) ...[
                                        const Text(' • '),
                                        Text(
                                          DateFormat('dd/MM/yyyy').format(date),
                                          style: TextStyle(
                                            color: isPointed ? Colors.green.shade600 : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isPointed && pointedAt != null)
                                    Text(
                                      'Pointée le ${pointedAt.day}/${pointedAt.month} à ${pointedAt.hour}:${pointedAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: Colors.green.shade600,
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: !_isSelectionMode
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'toggle':
                                            _togglePointing(index);
                                            break;
                                          case 'edit':
                                            _editSortie(index);
                                            break;
                                          case 'delete':
                                            _deleteSortie(index);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Row(
                                            children: [
                                              Icon(
                                                isPointed ? Icons.radio_button_unchecked : Icons.check_circle,
                                                color: isPointed ? Colors.orange : Colors.green,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(isPointed ? 'Dépointer' : 'Pointer'),
                                            ],
                                          ),
                                        ),
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
                                    )
                                  : null,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(index)
                                  : () => _togglePointing(index),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

          // CORRECTION: Créer un widget simple au lieu d'utiliser PointingWidget
          if (_isSelectionMode && _selectedIndices.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedIndices.length} charge${_selectedIndices.length > 1 ? 's' : ''} sélectionnée${_selectedIndices.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_isProcessingBatch)
                        const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      else ...[
                        ElevatedButton.icon(
                          onPressed: _batchTogglePointing,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Pointer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _selectAll,
                          icon: const Icon(Icons.select_all),
                          label: const Text('Tout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}