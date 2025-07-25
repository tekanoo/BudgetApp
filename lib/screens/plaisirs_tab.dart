import 'package:flutter/material.dart';
import '../services/encrypted_budget_service.dart'; // CHANGÉ: import du service chiffré

class PlaisirsTab extends StatefulWidget {
  const PlaisirsTab({super.key});

  @override
  State<PlaisirsTab> createState() => _PlaisirsTabState();
}

class _PlaisirsTabState extends State<PlaisirsTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService(); // CHANGÉ: service chiffré
  List<Map<String, dynamic>> plaisirs = [];
  bool isLoading = true;
  String _sortBy = 'date'; // 'date', 'amount', 'tag'
  bool _ascending = false;

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
      final data = await _dataService.getPlaisirs(); // Les données sont automatiquement déchiffrées
      setState(() {
        plaisirs = data;
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
        }
        return _ascending ? comparison : -comparison;
      });
    });
  }

  double get totalPlaisirs {
    double total = 0;
    for (var plaisir in plaisirs) {
      total += (plaisir['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  Map<String, double> get totalsByTag {
    final Map<String, double> totals = {};
    for (var plaisir in plaisirs) {
      final tag = plaisir['tag'] as String? ?? 'Sans catégorie';
      final amount = (plaisir['amount'] as num?)?.toDouble() ?? 0;
      totals[tag] = (totals[tag] ?? 0) + amount;
    }
    return totals;
  }

  Future<void> _editPlaisir(int index) async {
    final plaisir = plaisirs[index];
    final amountController = TextEditingController(
      text: (plaisir['amount'] as num?)?.toString() ?? ''
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                final tag = tagController.text.trim();
                
                if (amount != null && amount > 0 && selectedDate != null) {
                  Navigator.pop(context, {
                    'amount': amount,
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
      // Les données sont automatiquement chiffrées par le service
      await _dataService.updatePlaisir(
        index: index,
        amount: newData['amount'],
        tag: newData['tag'],
        date: newData['date'],
      );
      
      await _loadPlaisirs(); // Recharger les données
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépense modifiée avec succès'),
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
        await _loadPlaisirs(); // Recharger les données
        
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
                  // Résumé en haut
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
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Total Dépenses',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${totalPlaisirs.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${plaisirs.length} dépense${plaisirs.length > 1 ? 's' : ''}',
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
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple.shade100,
                              child: Text(
                                tag.isNotEmpty ? tag[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              '${amount.toStringAsFixed(2)} €',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      tag,
                                      style: TextStyle(
                                        color: Colors.purple.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Seuls les montants sont chiffrés, pas les tags
                                    Icon(
                                      Icons.lock_open,
                                      size: 12,
                                      color: Colors.purple.shade400,
                                    ),
                                  ],
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
                                  onPressed: () => _editPlaisir(index),
                                  tooltip: 'Modifier',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deletePlaisir(index),
                                  tooltip: 'Supprimer',
                                ),
                              ],
                            ),
                            onTap: () => _editPlaisir(index),
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