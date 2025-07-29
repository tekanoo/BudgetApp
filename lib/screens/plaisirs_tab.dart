import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/encrypted_budget_service.dart';
import '../services/encryption_service.dart';
import '../services/pointing_service.dart';
import '../widgets/pointing_widget.dart';

class PlaisirsTab extends StatefulWidget {
  final DateTime? selectedMonth; // Ajouter ce paramètre optionnel
  
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
  double soldeDisponible = 0.0;
  bool isLoading = false;

  // Variables de filtrage
  DateTime? _selectedFilterDate;
  String _currentFilter = 'Tous';

  // Variables pour sélection multiple
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};
  bool _isProcessingBatch = false;

  late PointingService _pointingService;

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
      
      setState(() {
        plaisirs = data;
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
    final total = plaisirs.fold(0.0, 
      (sum, plaisir) => sum + ((plaisir['amount'] as num?)?.toDouble() ?? 0.0));
    final pointe = plaisirs
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
    
    final filteredTotal = filteredPlaisirs.fold(0.0, 
      (sum, plaisir) => sum + ((plaisir['amount'] as num?)?.toDouble() ?? 0.0));
    final filteredPointe = filteredPlaisirs
        .where((p) => p['isPointed'] == true)
        .fold(0.0, (sum, plaisir) => sum + ((plaisir['amount'] as num?)?.toDouble() ?? 0.0));
    
    setState(() {
      totalPlaisirs = filteredTotal;
      totalPointe = filteredPointe;
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

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _deletePlaisir(int displayIndex) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirmer la suppression'),
          ],
        ),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette dépense ?'),
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

    if (confirmed != true) return;

    try {
      final plaisir = filteredPlaisirs[displayIndex];
      final plaisirId = plaisir['id'] ?? '';
      
      final originalPlaisirs = await _dataService.getPlaisirs();
      final realIndex = originalPlaisirs.indexWhere((p) => p['id'] == plaisirId);
      
      if (realIndex == -1) {
        throw Exception('Dépense non trouvée');
      }
      
      await _dataService.deletePlaisir(realIndex);
      await _loadPlaisirs();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépense supprimée'),
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

  Future<void> _updatePlaisir(int realIndex, Map<String, dynamic> result) async {
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
          backgroundColor: Colors.green,
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
      body: filteredPlaisirs.isEmpty
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
                    'Ajoutez vos plaisirs et dépenses diverses',
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
          : Stack(
              children: [
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Dépenses',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      if (filteredPlaisirs.isNotEmpty)
                                        InkWell(
                                          onTap: _toggleSelectionMode,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
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
                                            color: Colors.white.withValues(alpha: 0.2),
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
                                            color: Colors.white.withValues(alpha: 0.2),
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
                            ],
                          ),
                          
                          const SizedBox(height: 15),
                          
                          Column(
                            children: [
                              const Text(
                                'Total Dépenses',
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
                    ),

                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredPlaisirs.length,
                        itemBuilder: (context, index) {
                          final plaisir = filteredPlaisirs[index];
                          final amount = (plaisir['amount'] as num?)?.toDouble() ?? 0;
                          final tag = plaisir['tag'] as String? ?? 'Sans catégorie';
                          final isPointed = plaisir['isPointed'] == true;

                          String formattedDate = 'Date inconnue';
                          if (plaisir['date'] != null) {
                            final date = DateTime.tryParse(plaisir['date']);
                            if (date != null) {
                              formattedDate = DateFormat('dd/MM/yyyy').format(date);
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: _isSelectionMode && _selectedIndices.contains(index)
                                  ? BorderSide(color: Colors.purple.shade400, width: 2)
                                  : BorderSide.none,
                            ),
                            elevation: _isSelectionMode && _selectedIndices.contains(index) ? 3 : 1,
                            child: InkWell(
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(index)
                                  : () => _showPlaisirDetails(index),
                              onLongPress: !_isSelectionMode
                                  ? () {
                                      _toggleSelectionMode();
                                      _toggleSelection(index);
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isPointed ? Colors.green.shade700 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${AmountParser.formatAmount(amount)} €',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isPointed ? Colors.green.shade700 : Colors.purple.shade700,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formattedDate,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        PointingStatus(
                                          isPointed: isPointed,
                                          pointedAt: plaisir['pointedAt'] as String?,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                
                if (_isSelectionMode)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedIndices.length} sélectionnée${_selectedIndices.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isProcessingBatch ? null : _batchTogglePointing,
                                icon: _isProcessingBatch 
                                    ? const SizedBox(
                                        width: 18, 
                                        height: 18, 
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: const Text('Pointer/Dépointer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
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
                          ),
                        ],
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

  Future<void> _togglePointing(int displayIndex) async {
    try {
      final plaisirToToggle = filteredPlaisirs[displayIndex];
      final plaisirId = plaisirToToggle['id'] ?? '';
      
      final originalPlaisirs = await _dataService.getPlaisirs();
      final realIndex = originalPlaisirs.indexWhere((p) => p['id'] == plaisirId);
      
      if (realIndex == -1) {
        throw Exception('Dépense non trouvée');
      }
      
      final newState = await _pointingService.togglePlaisirPointing(realIndex);
      await _loadPlaisirs();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState 
              ? '✅ Dépense pointée - Solde mis à jour'
              : '↩️ Dépense dépointée - Solde mis à jour'
          ),
          backgroundColor: newState ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 1),
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
      await _updatePlaisir(realIndex, result);
    }
  }

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

  Future<Map<String, dynamic>?> _showPlaisirDialog({
    String? tag,
    double? amount,
    DateTime? date,
    bool isEdit = false,
  }) async {
    final tagController = TextEditingController(text: tag ?? '');
    final amountController = TextEditingController(
      text: amount != null ? AmountParser.formatAmount(amount) : ''
    );
    DateTime? selectedDate = date ?? DateTime.now();

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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
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
              TextField(
                controller: tagController,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  helperText: 'Restaurant, Shopping, Transport...',
                ),
              ),
              const SizedBox(height: 16),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 12),
                      Text(
                        selectedDate == null
                            ? 'Sélectionner une date'
                            : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  border: Border.fromBorderSide(BorderSide(color: Color(0xFFBBDEFB))),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: Color(0xFF1976D2),
                      size: 16
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Le statut de pointage sera préservé lors de la modification',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1976D2),
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
              onPressed: () {
                final amountStr = amountController.text.trim();
                final tag = tagController.text.trim();
                
                if (amountStr.isNotEmpty && selectedDate != null) {
                  Navigator.pop(context, {
                    'amountStr': amountStr,
                    'tag': tag.isEmpty ? 'Sans catégorie' : tag,
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