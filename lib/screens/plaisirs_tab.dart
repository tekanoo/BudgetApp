import 'package:flutter/material.dart';
import '../services/encrypted_budget_service.dart';
import '../services/encryption_service.dart';
import '../services/pointing_service.dart';
import '../widgets/pointing_widget.dart';

class PlaisirsTab extends StatefulWidget {
  const PlaisirsTab({super.key});

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

  late PointingService _pointingService;

  @override
  void initState() {
    super.initState();
    _pointingService = PointingService(_dataService);
    _loadPlaisirs();
  }

  Future<void> _loadPlaisirs() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await _dataService.getPlaisirs();
      final totals = await _dataService.getTotals();
      final solde = await _dataService.getSoldeDisponible();
      
      final totalPlaisirsPointe = data
          .where((p) => p['isPointed'] == true)
          .fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));
      
      setState(() {
        plaisirs = data..sort((a, b) {
          final aDate = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
          final bDate = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
        totalPlaisirs = totals['plaisirs'] ?? 0.0;
        totalPointe = totalPlaisirsPointe;
        soldeDisponible = solde;
        isLoading = false;
        
        _applyFilter();
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
                  if (date != null) {
                    if (mounted) {
                      setState(() {
                        _currentFilter = value!;
                        _selectedFilterDate = date;
                      });
                      _applyFilter();
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
                  if (date != null) {
                    if (mounted) {
                      setState(() {
                        _currentFilter = value!;
                        _selectedFilterDate = date;
                      });
                      _applyFilter();
                      Navigator.pop(context);
                    }
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

  // Add missing _toggleSelection method
  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  // Add missing _deletePlaisir method
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

  // Add missing _updatePlaisir method
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
          : Column(
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
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: _showFilterDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.filter_list, color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    _currentFilter == 'Tous' 
                                        ? 'Tous'
                                        : _currentFilter == 'Mois'
                                            ? '${_getMonthName(_selectedFilterDate!.month).substring(0, 3)} ${_selectedFilterDate!.year}'
                                            : '${_selectedFilterDate!.year}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
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
                      final dateStr = plaisir['date'] as String? ?? '';
                      final date = DateTime.tryParse(dateStr);
                      final isPointed = plaisir['isPointed'] == true;
                      final isSelected = _selectedIndices.contains(index);
                      final pointedAt = plaisir['pointedAt'] as String?;

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
                          leading: _isSelectionMode
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (value) => _toggleSelection(index),
                                  activeColor: Colors.blue,
                                )
                              : PointingButton(
                                  isPointed: isPointed,
                                  onTap: () => _togglePointing(index),
                                  baseColor: Colors.purple,
                                ),
                          title: Row(
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (date != null)
                                Text(
                                  '${date.day}/${date.month}/${date.year}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  PointingStatus(
                                    isPointed: isPointed,
                                    pointedAt: pointedAt,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: !_isSelectionMode
                              ? PopupMenuButton(
                                  icon: const Icon(Icons.more_vert),
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
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'toggle':
                                        await _togglePointing(index);
                                        break;
                                      case 'edit':
                                        await _editPlaisir(index);
                                        break;
                                      case 'delete':
                                        await _deletePlaisir(index);
                                        break;
                                    }
                                  },
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
      
      // Add selection mode bottom bar
      bottomSheet: _isSelectionMode && _selectedIndices.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedIndices.length} dépense${_selectedIndices.length > 1 ? 's' : ''} sélectionnée${_selectedIndices.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
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
              ),
            )
          : null,
    );
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
        await _pointingService.togglePlaisirPointing(realIndex);
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
}