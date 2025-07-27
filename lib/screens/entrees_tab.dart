import 'package:flutter/material.dart';
import '../services/encrypted_budget_service.dart';
import '../services/encryption_service.dart';

class EntreesTab extends StatefulWidget {
  const EntreesTab({super.key});

  @override
  State<EntreesTab> createState() => _EntreesTabState();
}

class _EntreesTabState extends State<EntreesTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  List<Map<String, dynamic>> entrees = [];
  List<Map<String, dynamic>> filteredEntrees = []; // Nouvelle liste filtrée
  double totalEntrees = 0.0;
  double soldeDisponible = 0.0;
  bool isLoading = false;

  // Variables de filtrage
  DateTime? _selectedFilterDate;
  String _currentFilter = 'Tous'; // 'Tous', 'Mois', 'Année'

  @override
  void initState() {
    super.initState();
    _loadEntrees();
  }

  Future<void> _loadEntrees() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await _dataService.getEntrees();
      final totals = await _dataService.getTotals();
      final solde = await _dataService.getSoldeDisponible();
      
      setState(() {
        // Tri par défaut : plus récent en haut (par date de création)
        entrees = data..sort((a, b) {
          final aDate = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
          final bDate = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
          return bDate.compareTo(aDate); // Plus récent en premier
        });
        totalEntrees = totals['entrees'] ?? 0.0;
        soldeDisponible = solde;
        isLoading = false;
        
        // Appliquer le filtre après le chargement
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
      filteredEntrees = List.from(entrees);
    } else {
      filteredEntrees = entrees.where((entree) {
        final entreeDate = DateTime.tryParse(entree['date'] ?? '');
        if (entreeDate == null) return false;
        
        if (_currentFilter == 'Mois') {
          return entreeDate.year == _selectedFilterDate!.year &&
                 entreeDate.month == _selectedFilterDate!.month;
        } else if (_currentFilter == 'Année') {
          return entreeDate.year == _selectedFilterDate!.year;
        }
        return true;
      }).toList();
    }
    
    // Recalculer le total des entrées filtrées
    final filteredTotal = filteredEntrees.fold(0.0, 
      (sum, entree) => sum + ((entree['amount'] as num?)?.toDouble() ?? 0.0));
    
    setState(() {
      totalEntrees = filteredTotal;
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
              'Filtrer les revenus',
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
              title: const Text('Tous les revenus'),
              subtitle: Text('${entrees.length} revenus'),
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
                    setState(() {
                      _currentFilter = value!;
                      _selectedFilterDate = date;
                    });
                    _applyFilter();
                    if (!mounted) return; // Protection async
                    Navigator.pop(context);
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
                    setState(() {
                      _currentFilter = value!;
                      _selectedFilterDate = date;
                    });
                    _applyFilter();
                    if (!mounted) return; // Protection async
                    Navigator.pop(context);
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

  // Ajout de la méthode _addEntree manquante
  Future<void> _addEntree() async {
    final result = await _showEntreeDialog();
    if (result != null) {
      try {
        // Données automatiquement chiffrées avant sauvegarde
        await _dataService.addEntree(
          amountStr: result['amountStr'],
          description: result['description'],
          date: result['date'], // Ajouter la date
        );
        await _loadEntrees();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔐 Revenu ajouté et chiffré avec succès'),
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

  // Ajout de la méthode _editEntree manquante
  Future<void> _editEntree(int displayIndex) async {
    final entree = entrees[displayIndex];
    final entreeId = entree['id'] ?? '';
    
    // Trouver l'index réel
    final originalEntrees = await _dataService.getEntrees();
    final realIndex = originalEntrees.indexWhere((e) => e['id'] == entreeId);
    
    if (realIndex == -1) return;
    
    final result = await _showEntreeDialog(
      isEdit: true,
      description: entree['description'],
      amount: entree['amount'],
      date: DateTime.tryParse(entree['date'] ?? ''), // Ajouter la date existante
    );
    
    if (result != null) {
      try {
        await _dataService.updateEntree(
          index: realIndex,
          amountStr: result['amountStr'],
          description: result['description'],
          date: result['date'], // Ajouter la date
        );
        await _loadEntrees();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔐 Revenu modifié et chiffré avec succès'),
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

  Future<Map<String, dynamic>?> _showEntreeDialog({
    String? description,
    double? amount,
    DateTime? date, // Nouveau paramètre
    bool isEdit = false,
  }) async {
    final descriptionController = TextEditingController(text: description ?? '');
    final montantController = TextEditingController(
      text: amount != null ? AmountParser.formatAmount(amount) : ''
    );
    DateTime? selectedDate = date ?? DateTime.now(); // Date par défaut = aujourd'hui

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit : Icons.add,
                color: isEdit ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'Modifier le revenu' : 'Ajouter un revenu'),
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
                  helperText: 'Salaire, Prime, Freelance...',
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
              // Sélecteur de date
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedDate != null 
                            ? '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}'
                            : 'Sélectionner une date',
                          style: TextStyle(
                            color: selectedDate != null ? Colors.black87 : Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
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
                final desc = descriptionController.text.trim();
                final amountStr = montantController.text.trim();
                final montant = AmountParser.parseAmount(amountStr);
                if (desc.isNotEmpty && montant > 0 && selectedDate != null) {
                  Navigator.pop(context, {
                    'description': desc,
                    'amountStr': amountStr,
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

  Future<void> _deleteEntree(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer ce revenu ?'),
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
        await _dataService.deleteEntree(index);
        await _loadEntrees();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revenu supprimé'),
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
              Text('Chargement des revenus...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: filteredEntrees.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 100,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _currentFilter == 'Tous' 
                        ? 'Aucun revenu enregistré'
                        : 'Aucun revenu pour cette période',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ajoutez vos revenus (salaire, primes...)',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _addEntree,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un revenu'),
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
                // En-tête avec totaux et filtres
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
                      // Ligne des actions (filtre + ajout)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Bouton filtre
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
                          
                          // Bouton ajout - CORRECTION: Déplacer child à la fin
                          InkWell(
                            onTap: _addEntree,
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
                      
                      const SizedBox(height: 15),
                      
                      // Informations totaux
                      Column(
                        children: [
                          const Text(
                            'Total Revenus',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${AmountParser.formatAmount(totalEntrees)} €',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            // CORRECTION: Utiliser interpolation au lieu de concaténation
                            '${filteredEntrees.length} revenu${filteredEntrees.length > 1 ? 's' : ''}${_currentFilter != 'Tous' ? ' • $_currentFilter' : ''}',
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

                // Liste des revenus filtrés
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredEntrees.length,
                    itemBuilder: (context, index) {
                      final entree = filteredEntrees[index];
                      final amount = (entree['amount'] as num?)?.toDouble() ?? 0;
                      final description = entree['description'] as String? ?? '';
                      final dateStr = entree['date'] as String? ?? '';
                      final date = DateTime.tryParse(dateStr);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Icon(
                              Icons.trending_up,
                              color: Colors.green.shade600,
                            ),
                          ),
                          title: Text(
                            description,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: date != null
                              ? Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}')
                              : null,
                          trailing: Text(
                            '+${AmountParser.formatAmount(amount)} €',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          onTap: () => _editEntree(index),
                          onLongPress: () => _deleteEntree(index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // ...rest of existing methods...
}