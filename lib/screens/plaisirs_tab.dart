import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/encrypted_budget_service.dart';
import '../utils/amount_parser.dart';

class PlaisirsTab extends StatefulWidget {
  final DateTime? selectedMonth;
  
  const PlaisirsTab({
    super.key,
    this.selectedMonth,
  });

  @override
  State<PlaisirsTab> createState() => _PlaisirsTabState();
}

class _PlaisirsTabState extends State<PlaisirsTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  List<Map<String, dynamic>> plaisirs = [];
  List<Map<String, dynamic>> filteredPlaisirs = [];
  double totalPlaisirs = 0.0;
  double totalPointe = 0.0;
  double totalRevenus = 0.0;
  double totalCharges = 0.0;
  double totalChargesPointees = 0.0;
  bool isLoading = false;

  // Variables de filtrage
  DateTime? _selectedFilterDate;
  String _currentFilter = 'Tous';

  // Variables pour la sélection multiple
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};
  bool _isProcessingBatch = false;

  @override
  void initState() {
    super.initState();
    _loadPlaisirs();
  }

  Future<void> _loadPlaisirs() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await _dataService.getPlaisirs();
      
      // Charger aussi les totaux pour les calculs
      final totals = await _dataService.getTotals();
      final charges = await _dataService.getSorties();
      
      setState(() {
        plaisirs = data;
        totalRevenus = totals['entrees'] ?? 0.0;
        totalCharges = totals['sorties'] ?? 0.0;
        
        // Calculer charges pointées
        totalChargesPointees = charges
            .where((s) => s['isPointed'] == true)
            .fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));
        
        // Si un mois spécifique est sélectionné, filtrer automatiquement
        if (widget.selectedMonth != null) {
          _currentFilter = 'Mois';
          _selectedFilterDate = widget.selectedMonth;
          _applyFilter();
        } else {
          filteredPlaisirs = List.from(plaisirs);
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
  
  void _calculateTotals() {
    final total = filteredPlaisirs.fold(0.0, 
      (sum, plaisir) => sum + ((plaisir['amount'] as num?)?.toDouble() ?? 0.0));
    final pointe = filteredPlaisirs
        .where((p) => p['isPointed'] == true)
        .fold(0.0, (sum, plaisir) => sum + ((plaisir['amount'] as num?)?.toDouble() ?? 0.0));
    
    setState(() {
      totalPlaisirs = total;
      totalPointe = pointe;
    });
  }

  void _applyFilter() {
    if (_currentFilter == 'Tous' || _selectedFilterDate == null) {
      filteredPlaisirs = List.from(plaisirs);
    } else {
      filteredPlaisirs = plaisirs.where((plaisir) {
        final plaisirDate = DateTime.tryParse(plaisir['date'] ?? '');
        if (plaisirDate == null) return false;
        
        if (_currentFilter == 'Mois') {
          return plaisirDate.year == _selectedFilterDate!.year &&
                 plaisirDate.month == _selectedFilterDate!.month;
        } else if (_currentFilter == 'Année') {
          return plaisirDate.year == _selectedFilterDate!.year;
        }
        return true;
      }).toList();
    }
    
    _calculateTotals();
  }

  Future<void> _togglePointing(int displayIndex) async {
    try {
      final plaisirToToggle = filteredPlaisirs[displayIndex];
      final plaisirId = plaisirToToggle['id'] ?? '';
      
      final originalPlaisirs = await _dataService.getPlaisirs();
      final realIndex = originalPlaisirs.indexWhere((p) => p['id'] == plaisirId);
      
      if (realIndex == -1) {
        throw Exception('Dépense non trouvée');
      }
      
      await _dataService.togglePlaisirPointing(realIndex);
      await _loadPlaisirs();
      
      if (!mounted) return;
      final isPointed = plaisirToToggle['isPointed'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !isPointed 
              ? '✅ Dépense pointée - Solde mis à jour'
              : '↩️ Dépense dépointée - Solde mis à jour'
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

  Widget _buildFinancialHeader() {
    final soldePrevu = totalRevenus - totalPlaisirs - totalCharges;
    final soldeDebite = totalRevenus - totalPointe - totalChargesPointees;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
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
                  if (filteredPlaisirs.isNotEmpty)
                    InkWell(
                      onTap: _toggleSelectionMode,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Icon(
                          _isSelectionMode ? Icons.close : Icons.checklist,
                          color: Colors.white,
                          size: 24,
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
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.filter_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  InkWell(
                    onTap: _addPlaisir,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 15),
          
          // Informations financières
          Column(
            children: [
              const Text(
                'Dépenses',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              Text(
                '${AmountParser.formatAmount(totalPlaisirs)} €',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
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
                              color: soldePrevu >= 0 ? Colors.white : Colors.red.shade200,
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
                              color: soldeDebite >= 0 ? Colors.green.shade200 : Colors.red.shade200,
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
                '${filteredPlaisirs.length} dépense${filteredPlaisirs.length > 1 ? 's' : ''} • ${filteredPlaisirs.where((p) => p['isPointed'] == true).length} pointée${filteredPlaisirs.where((p) => p['isPointed'] == true).length > 1 ? 's' : ''}${_currentFilter != 'Tous' ? ' • $_currentFilter' : ''}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
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
              Text('Chargement des dépenses...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          filteredPlaisirs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        size: 100,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _currentFilter == 'Tous' 
                            ? 'Aucune dépense enregistrée'
                            : 'Aucune dépense pour cette période',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ajoutez vos dépenses quotidiennes',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _addPlaisir,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une dépense'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // En-tête financier
                    _buildFinancialHeader(),

                    // Liste des dépenses
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredPlaisirs.length,
                        itemBuilder: (context, index) {
                          final plaisir = filteredPlaisirs[index];
                          final amount = (plaisir['amount'] as num?)?.toDouble() ?? 0;
                          final tag = plaisir['tag'] as String? ?? 'Sans catégorie';
                          final dateStr = plaisir['date'] as String? ?? '';
                          final date = DateTime.tryParse(dateStr);
                          final isPointed = plaisir['isPointed'] == true;
                          final isSelected = _selectedIndices.contains(index);
                          final pointedAt = plaisir['pointedAt'] != null 
                              ? DateTime.tryParse(plaisir['pointedAt']) 
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
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
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
                                          color: isPointed ? Colors.green.shade100 : Colors.purple.shade100,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isPointed ? Colors.green.shade300 : Colors.purple.shade300,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          isPointed ? Icons.check_circle : Icons.radio_button_unchecked,
                                          color: isPointed ? Colors.green.shade700 : Colors.purple.shade700,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
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
                                          color: isPointed ? Colors.green.shade700 : Colors.purple,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.lock_open,
                                        size: 12,
                                        color: isPointed ? Colors.green.shade400 : Colors.purple.shade400,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (date != null)
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(date),
                                      style: TextStyle(
                                        color: isPointed ? Colors.green.shade600 : Colors.grey,
                                      ),
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
                                            _editPlaisir(index);
                                            break;
                                          case 'delete':
                                            _deletePlaisir(index);
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
                                  : () => _showPlaisirDetails(index),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

          if (_isSelectionMode && _selectedIndices.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedIndices.length} dépense${_selectedIndices.length > 1 ? 's' : ''} sélectionnée${_selectedIndices.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_isProcessingBatch)
                        const CircularProgressIndicator(strokeWidth: 2)
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

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == filteredPlaisirs.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices = Set.from(List.generate(filteredPlaisirs.length, (index) => index));
      }
    });
  }

  Future<void> _batchTogglePointing() async {
    if (_selectedIndices.isEmpty) return;

    setState(() {
      _isProcessingBatch = true;
    });

    try {
      final originalPlaisirs = await _dataService.getPlaisirs();
      List<int> realIndices = [];
      
      for (int displayIndex in _selectedIndices) {
        final plaisir = filteredPlaisirs[displayIndex];
        final plaisirId = plaisir['id'] ?? '';
        final realIndex = originalPlaisirs.indexWhere((p) => p['id'] == plaisirId);
        
        if (realIndex != -1) {
          realIndices.add(realIndex);
        }
      }
      
      realIndices.sort((a, b) => b.compareTo(a));
      
      for (int realIndex in realIndices) {
        await _dataService.togglePlaisirPointing(realIndex);
      }

      await _loadPlaisirs();

      if (!mounted) return;
      
      setState(() {
        _isSelectionMode = false;
        _selectedIndices.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${realIndices.length} dépense(s) mise(s) à jour'),
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

  // Ajouter les méthodes manquantes _addPlaisir, _editPlaisir, _deletePlaisir, _showFilterDialog
  Future<void> _addPlaisir() async {
    final result = await _showPlaisirDialog();
    if (result != null) {
      try {
        await _dataService.addPlaisir(
          amountStr: result['amountStr'],
          tag: result['tag'],
          date: result['date'],
        );
        await _loadPlaisirs();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔐 Dépense ajoutée et chiffrée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ajout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editPlaisir(int displayIndex) async {
    final plaisir = filteredPlaisirs[displayIndex];
    final plaisirId = plaisir['id'] ?? '';
    
    final originalPlaisirs = await _dataService.getPlaisirs();
    final realIndex = originalPlaisirs.indexWhere((p) => p['id'] == plaisirId);
    
    if (realIndex == -1) return;
    
    final result = await _showPlaisirDialog(
      isEdit: true,
      tag: plaisir['tag'],
      amount: plaisir['amount'],
      date: DateTime.tryParse(plaisir['date'] ?? ''),
    );
    
    if (result != null) {
      try {
        await _dataService.updatePlaisir(
          index: realIndex,
          amountStr: result['amountStr'],
          tag: result['tag'],
          date: result['date'],
        );
        await _loadPlaisirs();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔐 Dépense modifiée et chiffrée avec succès'),
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

  Future<void> _deletePlaisir(int index) async {
    final plaisir = filteredPlaisirs[index];
    final plaisirId = plaisir['id'] ?? '';
    
    final originalPlaisirs = await _dataService.getPlaisirs();
    final realIndex = originalPlaisirs.indexWhere((p) => p['id'] == plaisirId);
    
    if (realIndex == -1) return;
    
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la dépense'),
        content: Text('Voulez-vous vraiment supprimer "${plaisir['tag']}" ?'),
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
        await _dataService.deletePlaisir(realIndex);
        await _loadPlaisirs();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dépense supprimée'),
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
              'Filtrer les dépenses',
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
              title: const Text('Toutes les dépenses'),
              subtitle: Text('${plaisirs.length} dépenses'),
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

  Future<Map<String, dynamic>?> _showPlaisirDialog({
    String? tag,
    double? amount,
    DateTime? date,
    bool isEdit = false,
  }) async {
    final tagController = TextEditingController(text: tag ?? '');
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
                color: isEdit ? Colors.blue : Colors.purple,
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'Modifier la dépense' : 'Ajouter une dépense'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tagController,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                    helperText: 'Restaurant, Courses, Transport...',
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
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: widget.selectedMonth != null 
                          ? DateTime(widget.selectedMonth!.year, widget.selectedMonth!.month, 1)
                          : DateTime(2020),
                      lastDate: widget.selectedMonth != null 
                          ? DateTime(widget.selectedMonth!.year, widget.selectedMonth!.month + 1, 0)
                          : DateTime(2030),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final tagText = tagController.text.trim();
                final amountStr = montantController.text.trim();
                final montant = AmountParser.parseAmount(amountStr);
                if (tagText.isNotEmpty && montant > 0 && selectedDate != null) {
                  Navigator.pop(context, {
                    'tag': tagText,
                    'amountStr': amountStr,
                    'date': selectedDate,
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

  Future<void> _showPlaisirDetails(int index) async {
    final plaisir = filteredPlaisirs[index];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_bag, color: Colors.purple),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    plaisir['tag'] as String? ?? 'Sans catégorie',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '${AmountParser.formatAmount((plaisir['amount'] as num?)?.toDouble() ?? 0)} €',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  plaisir['date'] != null 
                      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(plaisir['date']))
                      : 'Date inconnue',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _togglePointing(index);
                  },
                  icon: Icon(
                    plaisir['isPointed'] == true 
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle_outline,
                    color: plaisir['isPointed'] == true ? Colors.orange : Colors.green,
                  ),
                  label: Text(
                    plaisir['isPointed'] == true ? 'Dépointer' : 'Pointer',
                    style: TextStyle(
                      color: plaisir['isPointed'] == true ? Colors.orange : Colors.green,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _editPlaisir(index);
                  },
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  label: const Text('Modifier', style: TextStyle(color: Colors.blue)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _deletePlaisir(index);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}