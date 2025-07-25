import 'package:flutter/material.dart';
import '../services/encrypted_budget_service.dart';

class TagsManagementTab extends StatefulWidget {
  const TagsManagementTab({super.key});

  @override
  State<TagsManagementTab> createState() => _TagsManagementTabState();
}

class _TagsManagementTabState extends State<TagsManagementTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  List<String> tags = [];
  bool isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<String> get filteredTags {
    if (_searchQuery.isEmpty) {
      return tags;
    }
    return tags.where((tag) => tag.toLowerCase().contains(_searchQuery)).toList();
  }

  Future<void> _loadTags() async {
    setState(() {
      isLoading = true;
    });

    try {
      final loadedTags = await _dataService.getTags();
      if (!mounted) return;  // Add this check
      setState(() {
        tags = loadedTags;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;  // Add this check
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addTag() async {
    final result = await _showTagDialog();
    if (result != null && result.isNotEmpty) {
      // Vérifier si le tag existe déjà
      if (tags.contains(result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cette catégorie existe déjà'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      try {
        // Ajouter le nouveau tag
        final updatedTags = [...tags, result];
        await _dataService.saveTags(updatedTags);
        await _loadTags();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏷️ Catégorie ajoutée avec succès'),
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

  Future<void> _editTag(int index) async {
    final oldTag = tags[index];
    final result = await _showTagDialog(
      initialValue: oldTag,
      isEdit: true,
    );

    if (result != null && result != oldTag) {
      // Vérifier si le nouveau nom existe déjà
      if (tags.contains(result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cette catégorie existe déjà'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      try {
        // Mettre à jour le tag
        final updatedTags = [...tags];
        updatedTags[index] = result;
        await _dataService.saveTags(updatedTags);

        // Mettre à jour toutes les transactions qui utilisent cet ancien tag
        await _updateTransactionsWithNewTag(oldTag, result);

        await _loadTags();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 Catégorie modifiée et transactions mises à jour'),
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

  Future<void> _deleteTag(int index) async {
    final tagToDelete = tags[index];
    
    // Compter les utilisations du tag
    final usageCount = await _countTagUsage(tagToDelete);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Supprimer la catégorie'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous vraiment supprimer la catégorie "$tagToDelete" ?'),
            const SizedBox(height: 12),
            if (usageCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cette catégorie est utilisée dans $usageCount transaction${usageCount > 1 ? 's' : ''}. '
                        'Ces transactions seront marquées comme "Sans catégorie".',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cette catégorie n\'est utilisée dans aucune transaction.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
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
        // Supprimer le tag
        final updatedTags = [...tags];
        updatedTags.removeAt(index);
        await _dataService.saveTags(updatedTags);

        // Mettre à jour les transactions qui utilisent ce tag
        if (usageCount > 0) {
          await _updateTransactionsWithNewTag(tagToDelete, 'Sans catégorie');
        }

        await _loadTags();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              usageCount > 0 
                ? '🗑️ Catégorie supprimée et $usageCount transaction${usageCount > 1 ? 's' : ''} mise${usageCount > 1 ? 's' : ''} à jour'
                : '🗑️ Catégorie supprimée'
            ),
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

  Future<String?> _showTagDialog({
    String? initialValue,
    bool isEdit = false,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isEdit ? Icons.edit : Icons.add,
              color: isEdit ? Colors.blue : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(isEdit ? 'Modifier la catégorie' : 'Ajouter une catégorie'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom de la catégorie',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
                helperText: 'Restaurant, Shopping, Loisirs...',
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
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
                      'Les catégories vous aident à organiser vos dépenses',
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
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: Text(isEdit ? 'Modifier' : 'Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<int> _countTagUsage(String tag) async {
    try {
      final plaisirs = await _dataService.getPlaisirs();
      return plaisirs.where((plaisir) => plaisir['tag'] == tag).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _updateTransactionsWithNewTag(String oldTag, String newTag) async {
    try {
      // Mettre à jour les plaisirs/dépenses
      final plaisirs = await _dataService.getPlaisirs();
      bool needsUpdate = false;

      for (int i = 0; i < plaisirs.length; i++) {
        if (plaisirs[i]['tag'] == oldTag) {
          await _dataService.updatePlaisir(
            index: i,
            amountStr: plaisirs[i]['amount'].toString(), // Changed from amount to amountStr
            tag: newTag,
            date: DateTime.tryParse(plaisirs[i]['date'] ?? '') ?? DateTime.now(),
          );
          needsUpdate = true;
        }
      }

      if (needsUpdate && mounted) {
        // Recharger les données après mise à jour
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour des transactions: $e'),
            backgroundColor: Colors.orange,
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
              Text('Chargement des catégories...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // En-tête avec recherche
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade400, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withValues(alpha: 0.3),
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
                      Icons.tag,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gestion des Catégories',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${tags.length} catégorie${tags.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _addTag,
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                      tooltip: 'Ajouter une catégorie',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Barre de recherche
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une catégorie...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.7)),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          // Liste des tags
          Expanded(
            child: filteredTags.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off : Icons.tag,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _searchQuery.isNotEmpty 
                              ? 'Aucune catégorie trouvée'
                              : 'Aucune catégorie créée',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Essayez un autre terme de recherche'
                              : 'Ajoutez votre première catégorie pour organiser vos dépenses',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: _addTag,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter une catégorie'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTags,
                    child: ListView.builder(
                      itemCount: filteredTags.length,
                      itemBuilder: (context, index) {
                        final tag = filteredTags[index];
                        final actualIndex = tags.indexOf(tag);
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade100,
                              child: Text(
                                tag.isNotEmpty ? tag[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: Colors.indigo.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              tag,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: FutureBuilder<int>(
                              future: _countTagUsage(tag),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Text(
                                  count > 0 
                                      ? 'Utilisé dans $count transaction${count > 1 ? 's' : ''}'
                                      : 'Non utilisé',
                                  style: TextStyle(
                                    color: count > 0 ? Colors.green.shade600 : Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editTag(actualIndex),
                                  tooltip: 'Modifier',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteTag(actualIndex),
                                  tooltip: 'Supprimer',
                                ),
                              ],
                            ),
                            onTap: () => _editTag(actualIndex),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}