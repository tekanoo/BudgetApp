import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SortiesTab extends StatefulWidget {
  const SortiesTab({super.key});

  @override
  State<SortiesTab> createState() => _SortiesTabState();
}

class _SortiesTabState extends State<SortiesTab> {
  List<Map<String, String>> sorties = [];

  @override
  void initState() {
    super.initState();
    _loadSorties();
  }

  Future<void> _loadSorties() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('sorties') ?? [];
    final parsed = list.map((s) => _parseStringToMap(s)).toList();
    setState(() {
      sorties = parsed;
    });
  }

  Map<String, String> _parseStringToMap(String s) {
    final clean = s.replaceAll(RegExp(r'[{}]'), '');
    final parts = clean.split(',');
    final map = <String, String>{};
    for (var part in parts) {
      final kv = part.split(':');
      if (kv.length == 2) {
        map[kv[0].trim()] = kv[1].trim();
      }
    }
    return map;
  }

  Future<void> _addSortie() async {
    final result = await _showSortieDialog();
    if (result != null) {
      sorties.add(result);
      await _saveSorties();
    }
  }

  Future<void> _editSortie(int index) async {
    final result = await _showSortieDialog(sortie: sorties[index]);
    if (result != null) {
      sorties[index] = result;
      await _saveSorties();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sortie modifiée avec succès'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<Map<String, String>?> _showSortieDialog({Map<String, String>? sortie}) async {
    final descriptionController = TextEditingController(text: sortie?['description'] ?? '');
    final montantController = TextEditingController(text: sortie?['montant'] ?? '');
    final isEdit = sortie != null;

    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isEdit ? Icons.edit : Icons.add,
              color: isEdit ? Colors.blue : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isEdit ? 'Modifier la sortie' : 'Ajouter une sortie'),
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
          ElevatedButton(
            onPressed: () {
              final desc = descriptionController.text.trim();
              final montant = montantController.text.trim();
              if (desc.isNotEmpty && montant.isNotEmpty && double.tryParse(montant) != null) {
                Navigator.pop(context, {
                  'description': desc,
                  'montant': montant,
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
        content: const Text('Voulez-vous vraiment supprimer cette sortie ?'),
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
      sorties.removeAt(index);
      await _saveSorties();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sortie supprimée'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveSorties() async {
    final prefs = await SharedPreferences.getInstance();
    final list = sorties.map((e) => e.toString()).toList();
    await prefs.setStringList('sorties', list);
    setState(() {});
  }

  double get totalSorties {
    double total = 0;
    for (var e in sorties) {
      total += double.tryParse(e['montant'] ?? '0') ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: sorties.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_down,
                    size: 80,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Aucune sortie enregistrée',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ajoutez vos dépenses pour commencer',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _addSortie,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une sortie'),
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
                            Icons.trending_down,
                            color: Colors.white,
                            size: 40,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _addSortie,
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Ajouter une sortie',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Total Sorties',
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
                        '${sorties.length} sortie${sorties.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste des sorties
                Expanded(
                  child: ListView.builder(
                    itemCount: sorties.length,
                    itemBuilder: (context, index) {
                      final e = sorties[index];
                      final montant = double.tryParse(e['montant'] ?? '0') ?? 0;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade100,
                            child: Icon(
                              Icons.euro,
                              color: Colors.red.shade700,
                            ),
                          ),
                          title: Text(
                            e['description'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '${montant.toStringAsFixed(2)} €',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
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
    );
  }
}