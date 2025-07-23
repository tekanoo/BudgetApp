import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  DateTime? _selectedDate;
  List<String> _availableTags = [];
  List<String> _filteredTags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableTags();
    _tagController.addListener(_onTagTextChanged);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTags() async {
    final prefs = await SharedPreferences.getInstance();
    final tags = prefs.getStringList('available_tags') ?? [];
    setState(() {
      _availableTags = tags;
      _filteredTags = tags;
    });
  }

  void _onTagTextChanged() {
    final query = _tagController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTags = _availableTags;
      } else {
        _filteredTags = _availableTags
            .where((tag) => tag.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir le montant et sélectionner une date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un montant valide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Créer la transaction
      final transaction = {
        'amount': amount.toString(),
        'tag': _tagController.text.trim().isEmpty ? 'Sans catégorie' : _tagController.text.trim(),
        'date': _selectedDate!.toIso8601String(),
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      // Sauvegarder la transaction dans "plaisirs"
      final plaisirs = prefs.getStringList('plaisirs') ?? [];
      plaisirs.add(transaction.toString());
      await prefs.setStringList('plaisirs', plaisirs);

      // Sauvegarder le tag s'il est nouveau
      final tagText = _tagController.text.trim();
      if (tagText.isNotEmpty && !_availableTags.contains(tagText)) {
        _availableTags.add(tagText);
        await prefs.setStringList('available_tags', _availableTags);
      }

      // Réinitialiser le formulaire
      _amountController.clear();
      _tagController.clear();
      setState(() {
        _selectedDate = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dépense ajoutée avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle dépense'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icône et titre
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Ajouter une dépense plaisir',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Champ montant
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro),
                suffixText: '€',
                helperText: 'Montant de la dépense',
              ),
            ),
            const SizedBox(height: 20),

            // Champ tag avec autocomplétion
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                    helperText: 'Restaurant, Shopping, Loisirs...',
                  ),
                ),
                if (_filteredTags.isNotEmpty && _tagController.text.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredTags.take(5).length,
                      itemBuilder: (context, index) {
                        final tag = _filteredTags[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.tag, size: 16),
                          title: Text(tag),
                          onTap: () {
                            _tagController.text = tag;
                            setState(() {
                              _filteredTags = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Sélecteur de date
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? 'Sélectionner une date *'
                          : 'Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate == null ? Colors.grey.shade600 : null,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Bouton de validation
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveTransaction,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isLoading ? 'Sauvegarde...' : 'Ajouter la dépense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '* Champs obligatoires',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}