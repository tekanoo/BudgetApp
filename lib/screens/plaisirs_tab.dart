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
  late final PointingService _pointingService;
  
  List<Map<String, dynamic>> plaisirs = [];
  double totalPlaisirs = 0.0;
  double totalPointe = 0.0;
  double soldeDisponible = 0.0;
  bool isLoading = false;

  // Sélection multiple (suppression des variables de tri)
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};
  bool _isProcessingBatch = false;

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
      
      // Calculer le total pointé directement
      final totalPlaisirsPointe = data
          .where((p) => p['isPointed'] == true)
          .fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));
      
      setState(() {
        // Tri par défaut : plus récent en haut (par date de création)
        plaisirs = data..sort((a, b) {
          final aDate = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
          final bDate = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
          return bDate.compareTo(aDate); // Plus récent en premier
        });
        totalPlaisirs = totals['plaisirs'] ?? 0.0;
        totalPointe = totalPlaisirsPointe;
        soldeDisponible = solde;
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

  // Suppression de la méthode _sortPlaisirs()

  Future<void> _togglePointing(int index) async {
    try {
      final newState = await _pointingService.togglePlaisirPointing(index);
      await _loadPlaisirs(); // Recharger pour mettre à jour les totaux
      
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
    final plaisir = plaisirs[displayIndex];
    final plaisirId = plaisir['id'] ?? '';
    
    // Trouver l'index réel
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
      await _updatePlaisir(realIndex, result); // Utiliser realIndex au lieu de index
    }
  }

  // Ajout de la méthode _addPlaisir manquante
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
            content: Text('✅ Dépense ajoutée avec succès'),
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

  Future<void> _updatePlaisir(int realIndex, Map<String, dynamic> newData) async {
    try {
      await _dataService.updatePlaisir(
        index: realIndex,
        amountStr: newData['amountStr'],
        tag: newData['tag'],
        date: newData['date'],
      );
      
      await _loadPlaisirs();
      
      if (!mounted) return; // Protection async
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Dépense modifiée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return; // Protection async
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la modification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePlaisir(int displayIndex) async {
    final plaisir = plaisirs[displayIndex];
    final plaisirId = plaisir['id'] ?? '';
    
    // Trouver l'index réel
    final originalPlaisirs = await _dataService.getPlaisirs();
    final realIndex = originalPlaisirs.indexWhere((p) => p['id'] == plaisirId);
    
    if (realIndex == -1) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer cette dépense ?'),
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
        await _dataService.deletePlaisir(realIndex);
        await _loadPlaisirs();
        
        if (!mounted) return; // Protection async
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dépense supprimée'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        if (!mounted) return; // Protection async
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _batchTogglePointing() async {
    if (_selectedIndices.isEmpty) return;

    setState(() {
      _isProcessingBatch = true;
    });

    try {
      final results = await _pointingService.batchTogglePlaisirs(_selectedIndices.toList());
      
      await _loadPlaisirs();

      if (!mounted) return;
      
      setState(() {
        _isSelectionMode = false;
        _selectedIndices.clear();
        _isProcessingBatch = false;
      });

      // Message de résultat
      final pointed = results['pointed'] ?? 0;
      final unpointed = results['unpointed'] ?? 0;
      final errors = results['errors'] ?? 0;
      
      String message = '';
      if (pointed > 0) message += '✅ $pointed pointée${pointed > 1 ? 's' : ''}';
      if (unpointed > 0) {
        if (message.isNotEmpty) message += ' • ';
        message += '↩️ $unpointed dépointée${unpointed > 1 ? 's' : ''}';
      }
      if (errors > 0) {
        if (message.isNotEmpty) message += ' • ';
        message += '⚠️ $errors erreur${errors > 1 ? 's' : ''}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: errors > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingBatch = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du traitement: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == plaisirs.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices = Set.from(List.generate(plaisirs.length, (index) => index));
      }
    });
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
      body: Column(
        children: [
          // En-tête existant avec boutons de sélection
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.purple.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Boutons de contrôle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Mode sélection
                    Row(
                      children: [
                        IconButton(
                          onPressed: _toggleSelectionMode,
                          icon: Icon(
                            _isSelectionMode ? Icons.close : Icons.checklist,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: _isSelectionMode ? 'Annuler sélection' : 'Sélection multiple',
                        ),
                        if (_isSelectionMode) ...[
                          IconButton(
                            onPressed: _selectAll,
                            icon: Icon(
                              _selectedIndices.length == plaisirs.length 
                                  ? Icons.deselect 
                                  : Icons.select_all,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: _selectedIndices.length == plaisirs.length 
                                ? 'Tout désélectionner' 
                                : 'Tout sélectionner',
                          ),
                        ],
                      ],
                    ),
                    
                    // Tri et autres actions (suppression du bouton de tri)
                    Row(
                      children: [
                        if (!_isSelectionMode)
                          IconButton(
                            onPressed: _addPlaisir,
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Ajouter une dépense',
                          ),
                      ],
                    ),
                  ],
                ),

                // Barre de pointage en lot
                BatchPointingBar(
                  selectedCount: _selectedIndices.length,
                  isProcessing: _isProcessingBatch,
                  onPoint: _batchTogglePointing,
                  onCancel: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIndices.clear();
                    });
                  },
                  itemType: 'dépense',
                ),

                const SizedBox(height: 15),
                
                // Ligne des totaux
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Total Dépenses',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${AmountParser.formatAmount(totalPlaisirs)} €',
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Pointées',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.check_circle,
                                color: Colors.white70,
                                size: 12,
                              ),
                            ],
                          ),
                          Text(
                            '${AmountParser.formatAmount(totalPointe)} €',
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
                            'Solde Disponible',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${AmountParser.formatAmount(soldeDisponible)} €',
                            style: TextStyle(
                              color: soldeDisponible >= 0 ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                Text(
                  '${plaisirs.length} dépense${plaisirs.length > 1 ? 's' : ''} • ${plaisirs.where((p) => p['isPointed'] == true).length} pointée${plaisirs.where((p) => p['isPointed'] == true).length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Texte d'information pour la sélection
          if (_isSelectionMode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedIndices.length} dépense(s) sélectionnée(s). Appuyez sur les cases pour sélectionner/désélectionner.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Liste des dépenses
          Expanded(
            child: ListView.builder(
              itemCount: plaisirs.length,
              itemBuilder: (context, index) {
                final plaisir = plaisirs[index];
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
                    // Case à cocher ou bouton de pointage
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
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: _toggleSelectionMode,
              icon: const Icon(Icons.checklist),
              label: const Text('Sélection'),
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}