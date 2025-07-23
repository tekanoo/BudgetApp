import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaisirsTab extends StatefulWidget {
  const PlaisirsTab({super.key});

  @override
  State<PlaisirsTab> createState() => _PlaisirsTabState();
}

class _PlaisirsTabState extends State<PlaisirsTab> {
  List<Map<String, String>> plaisirs = [];
  bool isLoading = true;
  String _sortBy = 'date'; // 'date', 'amount', 'tag'
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _loadPlaisirs();
  }

  Future<void> _loadPlaisirs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('plaisirs') ?? [];
    final parsed = list.map((s) => _parseStringToMap(s)).toList();
    
    setState(() {
      plaisirs = parsed;
      isLoading = false;
    });
    _sortPlaisirs();
  }

  Map<String, String> _parseStringToMap(String s) {
    final clean = s.replaceAll(RegExp(r'[{}]'), '');
    final parts = clean.split(',');
    final map = <String, String>{};
    for (var part in parts) {
      final kv = part.split(':');
      if (kv.length >= 2) {
        final key = kv[0].trim();
        final value = kv.sublist(1).join(':').trim();
        map[key] = value;
      }
    }
    return map;
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
            final amountA = double.tryParse(a['amount'] ?? '0') ?? 0;
            final amountB = double.tryParse(b['amount'] ?? '0') ?? 0;
            comparison = amountA.compareTo(amountB);
            break;
          case 'tag':
            comparison = (a['tag'] ?? '').compareTo(b['tag'] ?? '');
            break;
        }
        return _ascending ? comparison : -comparison;
      });
    });
  }

  double get totalPlaisirs {
    double total = 0;
    for (var plaisir in plaisirs) {
      total += double.tryParse(plaisir['amount'] ?? '0') ?? 0;
    }
    return total;
  }

  Map<String, double> get totalsByTag {
    final Map<String, double> totals = {};
    for (var plaisir in plaisirs) {
      final tag = plaisir['tag'] ?? 'Sans catégorie';
      final amount = double.tryParse(plaisir['amount'] ?? '0') ?? 0;
      totals[tag] = (totals[tag] ?? 0) + amount;
    }
    return totals;
  }

  Future<void> _editPlaisir(int index) async {
    final plaisir = plaisirs[index];
    final amountController = TextEditingController(text: plaisir['amount']);
    final tagController = TextEditingController(text: plaisir['tag']);
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
                final amount = amountController.text.trim();
                final tag = tagController.text.trim();
                
                if (amount.isNotEmpty && double.tryParse(amount) != null && selectedDate != null) {
                  Navigator.pop(context, {
                    'amount': amount,
                    'tag': tag.isEmpty ? 'Sans catégorie' : tag,
                    'date': selectedDate!.toIso8601String(),
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
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('plaisirs') ?? [];
    
    // Créer la nouvelle transaction
    final updatedTransaction = {
      'amount': newData['amount'],
      'tag': newData['tag'],
      'date': newData['date'],
      'timestamp': plaisirs[index]['timestamp'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    list[index] = updatedTransaction.toString();
    await prefs.setStringList('plaisirs', list);
    
    _loadPlaisirs();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dépense modifiée avec succès'),
        backgroundColor: Colors.blue,
      ),
    );
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('plaisirs') ?? [];
      list.removeAt(index);
      await prefs.setStringList('plaisirs', list);
      _loadPlaisirs();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépense supprimée'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: plaisirs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'Aucune dépense plaisir',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Ajoutez votre première dépense dans l\'onglet Home',
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
                            Icons.celebration,
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
                        'Total Plaisirs',
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
                      final amount = double.tryParse(plaisir['amount'] ?? '0') ?? 0;
                      final tag = plaisir['tag'] ?? 'Sans catégorie';
                      final dateStr = plaisir['date'] ?? '';
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
                              Text(
                                tag,
                                style: TextStyle(
                                  color: Colors.purple.shade600,
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
    );
  }
}