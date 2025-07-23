import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntreesTab extends StatefulWidget {
  const EntreesTab({super.key});

  @override
  State<EntreesTab> createState() => _EntreesTabState();
}

class _EntreesTabState extends State<EntreesTab> {
  List<Map<String, String>> entrees = [];

  @override
  void initState() {
    super.initState();
    _loadEntrees();
  }

  Future<void> _loadEntrees() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('entrees') ?? [];
    final parsed = list.map((s) => _parseStringToMap(s)).toList();
    setState(() {
      entrees = parsed;
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

  Future<void> _addEntree() async {
    final result = await _showEntreeDialog();
    if (result != null) {
      entrees.add(result);
      await _saveEntrees();
    }
  }

  Future<void> _editEntree(int index) async {
    final result = await _showEntreeDialog(entree: entrees[index]);
    if (result != null) {
      entrees[index] = result;
      await _saveEntrees();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrée modifiée avec succès'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<Map<String, String>?> _showEntreeDialog({Map<String, String>? entree}) async {
    final descriptionController = TextEditingController(text: entree?['description'] ?? '');
    final montantController = TextEditingController(text: entree?['montant'] ?? '');
    final isEdit = entree != null;

    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isEdit ? Icons.edit : Icons.add,
              color: isEdit ? Colors.blue : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(isEdit ? 'Modifier l\'entrée' : 'Ajouter une entrée'),
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

  Future<void> _deleteEntree(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer cette entrée ?'),
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
      entrees.removeAt(index);
      await _saveEntrees();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrée supprimée'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveEntrees() async {
    final prefs = await SharedPreferences.getInstance();
    final list = entrees.map((e) => e.toString()).toList();
    await prefs.setStringList('entrees', list);
    setState(() {});
  }

  double get totalEntrees {
    double total = 0;
    for (var e in entrees) {
      total += double.tryParse(e['montant'] ?? '0') ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: entrees.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 80,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Aucune entrée enregistrée',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ajoutez vos revenus pour commencer',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _addEntree,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une entrée'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
                      colors: [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
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
                            Icons.trending_up,
                            color: Colors.white,
                            size: 40,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _addEntree,
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Ajouter une entrée',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Total Entrées',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${totalEntrees.toStringAsFixed(2)} €',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${entrees.length} entrée${entrees.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste des entrées
                Expanded(
                  child: ListView.builder(
                    itemCount: entrees.length,
                    itemBuilder: (context, index) {
                      final e = entrees[index];
                      final montant = double.tryParse(e['montant'] ?? '0') ?? 0;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Icon(
                              Icons.euro,
                              color: Colors.green.shade700,
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
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editEntree(index),
                                tooltip: 'Modifier',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteEntree(index),
                                tooltip: 'Supprimer',
                              ),
                            ],
                          ),
                          onTap: () => _editEntree(index),
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