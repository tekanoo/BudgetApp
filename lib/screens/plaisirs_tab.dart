import 'package:flutter/material.dart';
import '../services/encrypted_budget_service.dart';
import '../services/encryption_service.dart';

class PlaisirsTab extends StatefulWidget {
  const PlaisirsTab({super.key});

  @override
  State<PlaisirsTab> createState() => _PlaisirsTabState();
}

class _PlaisirsTabState extends State<PlaisirsTab> { // Correction: PlaisirsTab au lieu de PlaisirTab
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  List<Map<String, dynamic>> plaisirs = [];
  double totalPlaisirs = 0.0;
  double totalPointe = 0.0;
  double soldeDisponible = 0.0;
  bool isLoading = false;
  String _sortBy = 'date';
  bool _sortAscending = false;

  // Nouveaux états pour la sélection multiple
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
      final totals = await _dataService.getTotals();
      final solde = await _dataService.getSoldeDisponible();
      
      setState(() {
        plaisirs = data;
        totalPlaisirs = totals['plaisirs'] ?? 0.0;
        totalPointe = totals['plaisirsTotaux'] ?? 0.0;
        soldeDisponible = solde;
        isLoading = false;
      });
      _sortPlaisirs();
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

  void _sortPlaisirs() {
    setState(() {
      plaisirs.sort((a, b) {
        int comparison = 0;
        switch (_sortBy) {
          case 'date':
            final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
            final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
            comparison = dateA.compareTo(dateB);
            break;
          case 'amount':
            final amountA = (a['amount'] as num?)?.toDouble() ?? 0;
            final amountB = (b['amount'] as num?)?.toDouble() ?? 0;
            comparison = amountA.compareTo(amountB);
            break;
          case 'tag':
            final tagA = a['tag'] as String? ?? '';
            final tagB = b['tag'] as String? ?? '';
            comparison = tagA.compareTo(tagB);
            break;
          case 'pointed':
            final pointedA = a['isPointed'] == true ? 1 : 0;
            final pointedB = b['isPointed'] == true ? 1 : 0;
            comparison = pointedA.compareTo(pointedB);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  Future<void> _togglePointing(int index) async {
    try {
      await _dataService.togglePlaisirPointing(index);
      await _loadPlaisirs(); // Recharger pour mettre à jour les totaux
      
      if (!mounted) return;
      final isPointed = plaisirs[index]['isPointed'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPointed 
              ? '✅ Dépense pointée - Solde mis à jour'
              : '↩️ Dépense dépointée - Solde mis à jour'
          ),
          backgroundColor: isPointed ? Colors.green : Colors.orange,
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

  Future<void> _editPlaisir(int index) async {
    final plaisir = plaisirs[index];
    final amountController = TextEditingController(
      text: AmountParser.formatAmount((plaisir['amount'] as num?)?.toDouble() ?? 0)
    );
    final tagController = TextEditingController(
      text: plaisir['tag'] as String? ?? ''
    );
    DateTime? selectedDate = DateTime.tryParse(plaisir['date'] ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text('Modifier la dépense'),
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
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(DateTime.now().year - 5),
                    lastDate: DateTime(DateTime.now().year + 1),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = picked;
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
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _updatePlaisir(index, result);
    }
  }

  Future<void> _updatePlaisir(int index, Map<String, dynamic> newData) async {
    try {
      await _dataService.updatePlaisir(
        index: index,
        amountStr: newData['amountStr'],
        tag: newData['tag'],
        date: newData['date'],
      );
      
      await _loadPlaisirs();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Dépense modifiée avec succès'),
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

  Future<void> _deletePlaisir(int index) async {
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
        await _dataService.deletePlaisir(index);
        await _loadPlaisirs();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Dépense supprimée'),
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

  // Nouvelles méthodes pour la sélection multiple
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

  Future<void> _batchTogglePointing() async {
    if (_selectedIndices.isEmpty) return;

    setState(() {
      _isProcessingBatch = true;
    });

    try {
      // Traiter chaque sélection
      for (int index in _selectedIndices.toList()..sort((a, b) => b.compareTo(a))) {
        await _dataService.togglePlaisirPointing(index);
      }

      // Recharger les données
      await _loadPlaisirs();

      if (!mounted) return;
      
      // Sortir du mode sélection
      setState(() {
        _isSelectionMode = false;
        _selectedIndices.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${_selectedIndices.length} dépense(s) mises à jour'),
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
      body: RefreshIndicator(
        onRefresh: _loadPlaisirs,
        child: plaisirs.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 20),
                    Text(
                      'Aucune dépense enregistrée',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Ajoutez votre première dépense dans l\'onglet Dashboard',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // En-tête avec totaux et boutons
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
                            
                            // Tri et autres actions
                            Row(
                              children: [
                                if (!_isSelectionMode)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.sort, color: Colors.white),
                                    onSelected: (value) {
                                      setState(() {
                                        if (_sortBy == value) {
                                          _sortAscending = !_sortAscending;
                                        } else {
                                          _sortBy = value;
                                          _sortAscending = false;
                                        }
                                      });
                                      _sortPlaisirs();
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'date',
                                        child: Row(
                                          children: [
                                            Icon(_sortBy == 'date' ? Icons.check : Icons.calendar_today),
                                            const SizedBox(width: 8),
                                            const Text('Trier par date'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'amount',
                                        child: Row(
                                          children: [
                                            Icon(_sortBy == 'amount' ? Icons.check : Icons.euro),
                                            const SizedBox(width: 8),
                                            const Text('Trier par montant'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'tag',
                                        child: Row(
                                          children: [
                                            Icon(_sortBy == 'tag' ? Icons.check : Icons.tag),
                                            const SizedBox(width: 8),
                                            const Text('Trier par catégorie'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'pointed',
                                        child: Row(
                                          children: [
                                            Icon(_sortBy == 'pointed' ? Icons.check : Icons.check_circle),
                                            const SizedBox(width: 8),
                                            const Text('Trier par pointage'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // Bouton d'action pour la sélection multiple
                        if (_isSelectionMode && _selectedIndices.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox( // Changement: Container vers SizedBox
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isProcessingBatch ? null : _batchTogglePointing,
                              icon: _isProcessingBatch
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.check_circle),
                              label: Text(
                                _isProcessingBatch
                                    ? 'Traitement en cours...'
                                    : 'Pointer ${_selectedIndices.length} dépense(s)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],

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
                                : CircleAvatar(
                                    backgroundColor: isPointed ? Colors.green : Colors.purple.shade100,
                                    child: Icon(
                                      isPointed ? Icons.check_circle : Icons.shopping_cart,
                                      color: isPointed ? Colors.white : Colors.purple,
                                      size: 20,
                                    ),
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
                                if (isPointed)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.green.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Pointée',
                                        style: TextStyle(
                                          color: Colors.green.shade600,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            trailing: !_isSelectionMode
                                ? PopupMenuButton(
                                    icon: const Icon(Icons.more_vert),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Row(
                                          children: [
                                            Icon(Icons.radio_button_unchecked, color: Colors.orange),
                                            SizedBox(width: 8),
                                            Text('Dépointer'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Modifier'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
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
      ),
    );
  }
}