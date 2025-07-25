import 'package:flutter/material.dart';
import '../services/budget_data_service.dart';

class SortiesTab extends StatefulWidget {
  const SortiesTab({super.key});

  @override
  State<SortiesTab> createState() => _SortiesTabState();
}

class _SortiesTabState extends State<SortiesTab> {
  final BudgetDataService _dataService = BudgetDataService();
  List<Map<String, dynamic>> sorties = [];
  bool isLoading = true;
  String _sortBy = 'date'; // 'date', 'amount', 'description'
  bool _ascending = false;

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
      setState(() {
        sorties = data;
        isLoading = false;
      });
      _sortSorties();
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

  void _sortSorties() {
    setState(() {
      sorties.sort((a, b) {
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
          case 'description':
            final descA = a['description'] as String? ?? '';
            final descB = b['description'] as String? ?? '';
            comparison = descA.compareTo(descB);
            break;
        }
        return _ascending ? comparison : -comparison;
      });
    });
  }

  double get totalSorties {
    double total = 0;
    for (var sortie in sorties) {
      total += (sortie['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  Future<void> _addSortie() async {
    final result = await _showSortieDialog();
    if (result != null) {
      try {
        await _dataService.addSortie(
          amount: result['amount'],
          description: result['description'],
        );
        await _loadSorties();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charge ajoutée avec succès'),
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

  Future<void> _editSortie(int index) async {
    final sortie = sorties[index];
    final result = await _showSortieDialog(
      description: sortie['description'] as String? ?? '',
      amount: (sortie['amount'] as num?)?.toDouble() ?? 0,
      isEdit: true,
    );
    
    if (result != null) {
      try {
        await _dataService.updateSortie(
          index: index,
          amount: result['amount'],
          description: result['description'],
        );
        await _loadSorties();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charge modifiée avec succès'),
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

  Future<Map<String, dynamic>?> _showSortieDialog({
    String? description,
    double? amount,
    bool isEdit = false,
  }) async {
    final descriptionController = TextEditingController(text: description ?? '');
    final montantController = TextEditingController(text: amount?.toString() ?? '');

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
              final montant = double.tryParse(montantController.text.trim());
              if (desc.isNotEmpty && montant != null && montant > 0) {
                Navigator.pop(context, {
                  'description': desc,
                  'amount': montant,
                });
              }
            },
            child: Text(isEdit ? 'Modifier' : 'Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSortie(int index) async {
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
        await _dataService.deleteSortie(index);
        await _loadSorties();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charge supprimée'),
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
                  // En-tête avec total
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
                                _sortSorties();
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
                                  value: 'description',
                                  child: Row(
                                    children: [
                                      Icon(_sortBy == 'description' ? Icons.check : Icons.description),
                                      const SizedBox(width: 8),
                                      const Text('Trier par description'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
                        const SizedBox(height: 10),
                        const Text(
                          'Total Charges',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${totalSorties.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${sorties.length} charge${sorties.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade100,
                              child: Text(
                                description.isNotEmpty ? description[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              description,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${amount.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
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
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editSortie(index),
                                  tooltip: 'Modifier',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteSortie(index),
                                  tooltip: 'Supprimer',
                                ),
                              ],
                            ),
                            onTap: () => _editSortie(index),
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