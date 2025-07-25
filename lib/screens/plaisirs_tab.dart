import 'package:flutter/material.dart';
import '../services/encrypted_budget_service.dart';
import '../services/encryption_service.dart';

class PlaisirsTab extends StatefulWidget {
  const PlaisirsTab({super.key});

  @override
  State<PlaisirsTab> createState() => _PlaisirsTabState();
}

class _PlaisirsTabState extends State<PlaisirsTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  List<Map<String, dynamic>> plaisirs = [];
  bool isLoading = true;
  String _sortBy = 'date'; // 'date', 'amount', 'tag', 'pointed'
  bool _ascending = false;
  double totalPlaisirs = 0.0;
  double totalPointe = 0.0;
  double soldeDisponible = 0.0;

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
        return _ascending ? comparison : -comparison;
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
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Le statut de pointage sera préservé lors de la modification',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
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
                  // En-tête avec totaux et solde
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade400, Colors.pink.shade400],
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
                          children: [
                            const Icon(
                              Icons.shopping_cart,
                              color: Colors.white,
                              size: 40,
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.sort, color: Colors.white),
                              onSelected: (value) {
                                if (value == _sortBy) {
                                  setState(() {
                                    _ascending = !_ascending;
                                  });
                                } else {
                                  setState(() {
                                    _sortBy = value;
                                    _ascending = false;
                                  });
                                }
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Pointées',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
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
                        final pointedAt = plaisir['pointedAt'] != null 
                            ? DateTime.tryParse(plaisir['pointedAt']) 
                            : null;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          elevation: isPointed ? 3 : 1,
                          color: isPointed ? Colors.green.shade50 : null,
                          child: ListTile(
                            leading: GestureDetector(
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
                                Text(
                                  '${AmountParser.formatAmount(amount)} €',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isPointed ? Colors.green.shade700 : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.lock_open,
                                  size: 12,
                                  color: isPointed ? Colors.green.shade400 : Colors.purple.shade400,
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tag,
                                  style: TextStyle(
                                    color: isPointed ? Colors.green.shade600 : Colors.purple.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (date != null)
                                  Text(
                                    '${date.day}/${date.month}/${date.year}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (isPointed && pointedAt != null)
                                  Text(
                                    'Pointé le ${pointedAt!.day}/${pointedAt!.month} à ${pointedAt!.hour}:${pointedAt!.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: Colors.green.shade600,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
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
                                ),
                              ],
                            ),
                            onTap: () => _togglePointing(index),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () {
            // Naviguer vers l'onglet Dashboard pour ajouter une dépense
            DefaultTabController.of(context)?.animateTo(0);
          },
          backgroundColor: Colors.purple.shade400,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
          tooltip: 'Ajouter une dépense',
        ),
      ),
    );
  }
}
                