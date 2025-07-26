import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/encrypted_budget_service.dart';
import '../services/encryption_service.dart';

class SortiesTab extends StatefulWidget {
  const SortiesTab({super.key});

  @override
  State<SortiesTab> createState() => _SortiesTabState();
}

class _SortiesTabState extends State<SortiesTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  List<Map<String, dynamic>> sorties = [];
  double totalSorties = 0.0;
  double totalPointe = 0.0;
  double soldeDisponible = 0.0;
  bool isLoading = false;

  // Nouveaux états pour la sélection multiple (suppression des variables de tri)
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};
  bool _isProcessingBatch = false;

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
      final totals = await _dataService.getTotals();
      final solde = await _dataService.getSoldeDisponible();
      final totalSortiesPointe = await _dataService.getTotalSortiesTotaux();
      
      setState(() {
        // Tri par défaut : plus récent en haut (par date de création)
        sorties = data..sort((a, b) {
          final aDate = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
          final bDate = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
          return bDate.compareTo(aDate); // Plus récent en premier
        });
        totalSorties = totals['sorties'] ?? 0.0;
        totalPointe = totalSortiesPointe;
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

  Future<void> _togglePointing(int displayIndex) async {
    try {
      // Trouver l'index réel dans la liste non triée
      final sortieToToggle = sorties[displayIndex];
      final sortieId = sortieToToggle['id'] ?? '';
      
      // Charger la liste originale pour trouver le vrai index
      final originalSorties = await _dataService.getSorties();
      final realIndex = originalSorties.indexWhere((s) => s['id'] == sortieId);
      
      if (realIndex == -1) {
        throw Exception('Charge non trouvée');
      }
      
      await _dataService.toggleSortiePointing(realIndex);
      await _loadSorties(); // Recharger pour mettre à jour les totaux
      
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
        // Données automatiquement chiffrées avant sauvegarde
        await _dataService.addSortie(
          amountStr: result['amountStr'],
          description: result['description'],
        );
        await _loadSorties();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔐 Charge ajoutée et chiffrée avec succès'),
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

  Future<void> _editSortie(int displayIndex) async {
    final sortie = sorties[displayIndex];
    final sortieId = sortie['id'] ?? '';
    
    // Trouver l'index réel
    final originalSorties = await _dataService.getSorties();
    final realIndex = originalSorties.indexWhere((s) => s['id'] == sortieId);
    
    if (realIndex == -1) return;
    
    final result = await _showSortieDialog(
      isEdit: true,
      description: sortie['description'],
      amount: sortie['amount'], // Utiliser amount au lieu de amountStr
    );
    
    if (result != null) {
      try {
        await _dataService.updateSortie(
          index: realIndex,
          amountStr: result['amountStr'],
          description: result['description'],
        );
        await _loadSorties();
        
        if (!mounted) return; // Protection async
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔐 Charge modifiée et chiffrée avec succès'),
            backgroundColor: Colors.blue,
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
  }

  Future<void> _deleteSortie(int displayIndex) async {
    final sortie = sorties[displayIndex];
    final sortieId = sortie['id'] ?? '';
    
    // Trouver l'index réel
    final originalSorties = await _dataService.getSorties();
    final realIndex = originalSorties.indexWhere((s) => s['id'] == sortieId);
    
    if (realIndex == -1) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer cette charge ?'),
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
        await _dataService.deleteSortie(realIndex);
        await _loadSorties();
        
        if (!mounted) return; // Protection async ajoutée
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charge supprimée'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        if (!mounted) return; // Protection async ajoutée
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleSortieType(int index) async {
    try {
      final sortie = sorties[index];
      final currentType = sortie['type'] as String? ?? 'variable';
      final newType = currentType == 'fixe' ? 'variable' : 'fixe';
      
      await _dataService.updateSortie(
        index: index,
        amountStr: sortie['amount'].toString(),
        description: sortie['description'],
        type: newType,
      );
      
      await _loadSorties();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Charge passée en ${newType == 'fixe' ? 'fixe' : 'variable'}'),
          backgroundColor: newType == 'fixe' ? Colors.red : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement de type: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Nouvelles méthodes pour la sélection multiple (identiques à plaisirs_tab.dart)
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
      if (_selectedIndices.length == sorties.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices = Set.from(List.generate(sorties.length, (index) => index));
      }
    });
  }

  Future<void> _batchTogglePointing() async {
    if (_selectedIndices.isEmpty) return;

    setState(() {
      _isProcessingBatch = true;
    });

    try {
      // Convertir les index d'affichage en index réels
      final originalSorties = await _dataService.getSorties();
      List<int> realIndices = [];
      
      for (int displayIndex in _selectedIndices) {
        final sortie = sorties[displayIndex];
        final sortieId = sortie['id'] ?? '';
        final realIndex = originalSorties.indexWhere((s) => s['id'] == sortieId);
        
        if (realIndex != -1) {
          realIndices.add(realIndex);
        }
      }
      
      // Traiter dans l'ordre inverse pour éviter les décalages d'index
      realIndices.sort((a, b) => b.compareTo(a));
      
      for (int realIndex in realIndices) {
        await _dataService.toggleSortiePointing(realIndex);
      }

      // Recharger les données
      await _loadSorties();

      if (!mounted) return;
      
      // Sortir du mode sélection
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
    bool isEdit = false,
  }) async {
    final descriptionController = TextEditingController(text: description ?? '');
    final montantController = TextEditingController(
      text: amount != null ? AmountParser.formatAmount(amount) : ''
    );

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
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
        content: Column(
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
                labelText: 'Montant',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro),
                suffixText: '€',
                helperText: 'Utilisez , ou . pour les décimales',
              ),
            ),
            const SizedBox(height: 16),
            // Indicateur de sécurité
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ce montant sera automatiquement chiffré',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isEdit) ...[
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
              if (desc.isNotEmpty && montant > 0) {
                Navigator.pop(context, {
                  'description': desc,
                  'amountStr': amountStr,
                });
              }
            },
            child: Text(isEdit ? 'Modifier' : 'Ajouter'),
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
      body: RefreshIndicator(
        onRefresh: _loadSorties,
        child: sorties.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 80,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Aucune charge enregistrée',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ajoutez vos charges fixes et variables',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _addSortie,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une charge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // En-tête avec totaux et solde
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            // Indicateur de chiffrement
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Chiffré',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _addSortie,
                              icon: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 28,
                              ),
                              tooltip: 'Ajouter une charge',
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        
                        // Ligne des totaux
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    'Total Charges',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${AmountParser.formatAmount(totalSorties)} €',
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
                                    'Solde Débité',
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
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    'Solde Prévisionnel',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  FutureBuilder<double>(
                                    future: _dataService.getTotals().then((totals) => totals['solde'] ?? 0.0),
                                    builder: (context, snapshot) {
                                      final soldePrevi = snapshot.data ?? 0.0;
                                      return Text(
                                        '${AmountParser.formatAmount(soldePrevi)} €',
                                        style: TextStyle(
                                          color: soldePrevi >= 0 ? Colors.greenAccent : Colors.redAccent,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 10),
                        Text(
                          '${sorties.length} charge${sorties.length > 1 ? 's' : ''} • ${sorties.where((s) => s['isPointed'] == true).length} pointée${sorties.where((s) => s['isPointed'] == true).length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Mode sélection
                  Row(
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
                                _selectedIndices.length == sorties.length 
                                    ? Icons.deselect 
                                    : Icons.select_all,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: _selectedIndices.length == sorties.length 
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
                              onPressed: _addSortie,
                              icon: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 28,
                              ),
                              tooltip: 'Ajouter une charge',
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Bouton d'action pour la sélection multiple
                  if (_isSelectionMode && _selectedIndices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
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
                              : 'Pointer ${_selectedIndices.length} charge(s)',
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
                              '${_selectedIndices.length} charge(s) sélectionnée(s). Appuyez sur les cases pour sélectionner/désélectionner.',
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

                  // Liste des charges
                  Expanded(
                    child: ListView.builder(
                      itemCount: sorties.length,
                      itemBuilder: (context, index) {
                        final sortie = sorties[index];
                        final amount = (sortie['amount'] as num?)?.toDouble() ?? 0;
                        final description = sortie['description'] as String? ?? '';
                        final dateStr = sortie['date'] as String? ?? '';
                        final date = DateTime.tryParse(dateStr);
                        final isPointed = sortie['isPointed'] == true;
                        final isSelected = _selectedIndices.contains(index);
                        final pointedAt = sortie['pointedAt'] != null 
                            ? DateTime.tryParse(sortie['pointedAt']) 
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
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isPointed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.shade300),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check, size: 12, color: Colors.green.shade700),
                                              const SizedBox(width: 2),
                                              Text(
                                                'Pointé',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          switch (value) {
                                            case 'toggle':
                                              _togglePointing(index);
                                              break;
                                            case 'type':
                                              _toggleSortieType(index);
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
                                            value: 'type',
                                            child: Row(
                                              children: [
                                                Icon(Icons.swap_horiz, color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text('Changer type'),
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
      ),
    );
  }
}