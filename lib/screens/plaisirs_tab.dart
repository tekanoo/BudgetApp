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
      
      // Charger TOUTES les données pour les calculs
      final entreesData = await _dataService.getEntrees();
      final sortiesData = await _dataService.getSorties();
      
      setState(() {
        plaisirs = data;
        
        // Calculer les totaux selon le mois sélectionné
        if (widget.selectedMonth != null) {
          // Calculs mensuels
          totalRevenus = entreesData.where((e) {
            final date = DateTime.tryParse(e['date'] ?? '');
            return date != null && 
                   date.year == widget.selectedMonth!.year &&
                   date.month == widget.selectedMonth!.month;
          }).fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
          
          totalCharges = sortiesData.where((s) {
            final date = DateTime.tryParse(s['date'] ?? '');
            return date != null && 
                   date.year == widget.selectedMonth!.year &&
                   date.month == widget.selectedMonth!.month;
          }).fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));
          
          totalChargesPointees = sortiesData.where((s) {
            final date = DateTime.tryParse(s['date'] ?? '');
            return date != null && 
                   date.year == widget.selectedMonth!.year &&
                   date.month == widget.selectedMonth!.month &&
                   s['isPointed'] == true;
          }).fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));
        } else {
          // Calculs globaux (code existant)
          totalRevenus = entreesData.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
          totalCharges = sortiesData.fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));
          totalChargesPointees = sortiesData
              .where((s) => s['isPointed'] == true)
              .fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));
        }
        
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
    // CORRECTION : Prendre en compte les crédits dans le calcul
    final total = filteredPlaisirs.fold(0.0, (sum, plaisir) {
      final amount = (plaisir['amount'] as num?)?.toDouble() ?? 0.0;
      if (plaisir['isCredit'] == true) {
        return sum - amount; // Les virements/remboursements réduisent le total
      } else {
        return sum + amount; // Les dépenses normales augmentent le total
      }
    });
    
    final pointe = filteredPlaisirs
        .where((p) => p['isPointed'] == true)
        .fold(0.0, (sum, plaisir) {
          final amount = (plaisir['amount'] as num?)?.toDouble() ?? 0.0;
          if (plaisir['isCredit'] == true) {
            return sum - amount; // Les virements pointés réduisent le total pointé
          } else {
            return sum + amount; // Les dépenses pointées augmentent le total pointé
          }
        });
    
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
  // Utiliser les totaux calculés dans _loadPlaisirs()
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
          color: Colors.purple.withValues(alpha: 0.3),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        // Ligne de contrôles (filtres, etc.)
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
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
        
        // Total des dépenses
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
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
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
          '${filteredPlaisirs.length} dépense${filteredPlaisirs.length > 1 ? 's' : ''} • ${filteredPlaisirs.where((p) => p['isPointed'] == true).length} pointée${filteredPlaisirs.where((p) => p['isPointed'] == true).length > 1 ? 's' : ''}${_currentFilter != 'Tous' ? ' • $_currentFilter' : ''}',
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
                        
                          
                       
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            elevation: isSelected ? 4 : 1,
                            color: isSelected ? Colors.blue.shade50 : null,
                            child: ListTile(
                              // Case à cocher en mode sélection ou indicateur de pointage
                              leading: _isSelectionMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleSelection(index),
                                    )
                                  : GestureDetector(
                                      onTap: () => _togglePointing(index),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isPointed ? Colors.green : Colors.grey,
                                            width: 2,
                                          ),
                                          color: isPointed ? Colors.green : Colors.transparent,
                                        ),
                                        child: isPointed
                                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                                            : null,
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
                                        decoration: isPointed ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  // Indicateur visuel pour les virements/remboursements
                                  if (plaisir['isCredit'] == true) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.green.shade300),
                                      ),
                                      child: Text(
                                        '💰',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                DateFormat('dd/MM/yyyy').format(date ?? DateTime.now()),
                                style: TextStyle(
                                  color: isPointed ? Colors.green.shade600 : Colors.grey.shade600,
                                ),
                              ),
                              trailing: Text(
                                // Afficher le montant avec un signe différent selon le type
                                '${plaisir['isCredit'] == true ? '+' : '-'}${AmountParser.formatAmount(amount)} €',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: plaisir['isCredit'] == true 
                                      ? Colors.green.shade600 
                                      : (isPointed ? Colors.green.shade700 : Colors.red.shade600),
                                  decoration: isPointed ? TextDecoration.lineThrough : null,
                                ),
                              ),
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
          amountStr: result['amount'].toString(),
          tag: result['tag'],
          date: result['date'],
          isCredit: result['isCredit'] ?? false, // Nouveau paramètre
        );
        await _loadPlaisirs();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['isCredit'] == true 
                  ? '💰 Virement/Remboursement ajouté avec succès'
                  : '🔐 Dépense ajoutée et chiffrée avec succès'
            ),
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
      tag: plaisir['tag'],
      amount: (plaisir['amount'] as num?)?.toDouble(),
      date: DateTime.tryParse(plaisir['date'] ?? '') ?? DateTime.now(), // Correction ici
      isEdit: true,
      isCredit: plaisir['isCredit'] == true, // Passer la valeur actuelle
    );

    if (result != null) {
      try {
        await _dataService.updatePlaisir(
          index: realIndex,
          amountStr: result['amount'].toString(),
          tag: result['tag'],
          date: result['date'],
          isCredit: result['isCredit'] ?? false, // Nouveau paramètre
        );
        await _loadPlaisirs();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dépense modifiée'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
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
    bool? isCredit, // Nouveau paramètre
  }) async {
    final tagController = TextEditingController(text: tag ?? '');
    final montantController = TextEditingController(
      text: amount != null ? AmountParser.formatAmount(amount) : ''
    );
    DateTime? selectedDate = date ?? (widget.selectedMonth ?? DateTime.now());
    bool isCreditValue = isCredit ?? false; // Valeur locale pour la case à cocher

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
                  decoration: const InputDecoration(
                    labelText: 'Montant (€)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.euro),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                
                // Nouvelle case à cocher pour les virements/remboursements
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: isCreditValue ? Colors.green.shade50 : null,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isCreditValue,
                        onChanged: (value) {
                          setState(() {
                            isCreditValue = value ?? false;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Virement/Remboursement',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCreditValue ? Colors.green.shade700 : Colors.black87,
                              ),
                            ),
                            Text(
                              'Cochez si c\'est un virement entrant ou un remboursement prévu',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.blue),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            selectedDate != null 
                                ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                : 'Aucune date sélectionnée',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
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
                        child: const Text('Modifier'),
                      ),
                    ],
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
                if (tagController.text.trim().isNotEmpty &&
                    montantController.text.trim().isNotEmpty &&
                    selectedDate != null) {
                  Navigator.pop(context, {
                    'tag': tagController.text.trim(),
                    'amount': AmountParser.parseAmount(montantController.text),
                    'date': selectedDate,
                    'isCredit': isCreditValue, // Retourner la valeur de la case à cocher
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