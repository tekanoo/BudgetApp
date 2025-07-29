import 'package:flutter/material.dart';

import 'monthly_budget_screen.dart';
import '../services/encrypted_budget_service.dart';

class MonthSelectorScreen extends StatefulWidget {
  const MonthSelectorScreen({super.key});

  @override
  State<MonthSelectorScreen> createState() => _MonthSelectorScreenState();
}

class _MonthSelectorScreenState extends State<MonthSelectorScreen> {
  int _currentYear = DateTime.now().year;
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  Map<String, Map<String, double>> _monthlyData = {};
  bool _isLoading = true;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }
  
  Future<void> _initializeAndLoadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Initialiser le service de données chiffrées
      await _dataService.initialize();
      setState(() {
        _isInitialized = true;
      });
      
      // Charger les données mensuelles
      await _loadMonthlyData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isInitialized = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'initialisation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadMonthlyData() async {
    if (!_isInitialized) return;
    
    try {
      // Charger toutes les données
      final entrees = await _dataService.getEntrees();
      final sorties = await _dataService.getSorties();
      final plaisirs = await _dataService.getPlaisirs();
      
      Map<String, Map<String, double>> monthlyTotals = {};
      
      // Traiter les revenus
      for (var entree in entrees) {
        final date = DateTime.tryParse(entree['date'] ?? '');
        if (date != null) {
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlyTotals[monthKey] ??= {'revenus': 0.0, 'charges': 0.0, 'depenses': 0.0};
          monthlyTotals[monthKey]!['revenus'] = 
              (monthlyTotals[monthKey]!['revenus'] ?? 0.0) + ((entree['amount'] as num?)?.toDouble() ?? 0.0);
        }
      }
      
      // Traiter les charges
      for (var sortie in sorties) {
        final date = DateTime.tryParse(sortie['date'] ?? '');
        if (date != null) {
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlyTotals[monthKey] ??= {'revenus': 0.0, 'charges': 0.0, 'depenses': 0.0};
          monthlyTotals[monthKey]!['charges'] = 
              (monthlyTotals[monthKey]!['charges'] ?? 0.0) + ((sortie['amount'] as num?)?.toDouble() ?? 0.0);
        }
      }
      
      // Traiter les dépenses
      for (var plaisir in plaisirs) {
        final date = DateTime.tryParse(plaisir['date'] ?? '');
        if (date != null) {
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlyTotals[monthKey] ??= {'revenus': 0.0, 'charges': 0.0, 'depenses': 0.0};
          monthlyTotals[monthKey]!['depenses'] = 
              (monthlyTotals[monthKey]!['depenses'] ?? 0.0) + ((plaisir['amount'] as num?)?.toDouble() ?? 0.0);
        }
      }
      
      setState(() {
        _monthlyData = monthlyTotals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestion Budget $_currentYear'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              // Navigation vers analyse globale - peut être ajoutée plus tard
            },
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des données...'),
                ],
              ),
            )
          : !_isInitialized
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Erreur d\'initialisation'),
                      Text('Veuillez redémarrer l\'application'),
                    ],
                  ),
                )
              : Column(
        children: [
          // Sélecteur d'année
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentYear--;
                    });
                    _loadMonthlyData(); // Recharger les données pour la nouvelle année
                  },
                  icon: const Icon(Icons.arrow_back_ios),
                ),
                Text(
                  _currentYear.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentYear++;
                    });
                    _loadMonthlyData(); // Recharger les données pour la nouvelle année
                  },
                  icon: const Icon(Icons.arrow_forward_ios),
                ),
              ],
            ),
          ),
          
          // Grille des mois
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Changé à 2 pour plus d'espace
                childAspectRatio: 1.1, // Ajusté pour plus de hauteur
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final monthDate = DateTime(_currentYear, month);
                final isCurrentMonth = _currentYear == DateTime.now().year && 
                                     month == DateTime.now().month;
                
                return _buildMonthCard(monthDate, isCurrentMonth);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMonthCard(DateTime monthDate, bool isCurrentMonth) {
    final monthKey = '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';
    final monthData = _monthlyData[monthKey];
    final hasData = monthData != null && 
                   (monthData['revenus']! > 0 || monthData['charges']! > 0 || monthData['depenses']! > 0);
    
    final revenus = monthData?['revenus'] ?? 0.0;
    final charges = monthData?['charges'] ?? 0.0;
    final depenses = monthData?['depenses'] ?? 0.0;
    final solde = revenus - charges - depenses;
    
    // Utiliser les noms de mois français directement
    const monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    final monthName = monthNames[monthDate.month - 1];
    
    return Card(
      elevation: isCurrentMonth ? 8 : (hasData ? 6 : 4),
      color: isCurrentMonth 
          ? Theme.of(context).primaryColor 
          : (hasData ? Colors.blue.shade50 : null),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MonthlyBudgetScreen(
                selectedMonth: monthDate,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Nom du mois et année
              Text(
                monthName.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCurrentMonth 
                      ? Colors.white 
                      : (hasData ? Colors.blue.shade700 : Colors.black87),
                ),
                textAlign: TextAlign.center,
              ),
              
              // Icône et indicateur de données
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasData ? Icons.account_balance_wallet : Icons.calendar_month,
                    size: 20,
                    color: isCurrentMonth 
                        ? Colors.white 
                        : (hasData ? Colors.blue.shade600 : Colors.grey.shade600),
                  ),
                  if (hasData) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: solde >= 0 ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              
              // Données financières si disponibles
              if (hasData) ...[
                Column(
                  children: [
                    if (revenus > 0)
                      _buildDataRow('R', revenus, Colors.green, isCurrentMonth),
                    if (charges > 0)
                      _buildDataRow('C', charges, Colors.red, isCurrentMonth),
                    if (depenses > 0)
                      _buildDataRow('D', depenses, Colors.purple, isCurrentMonth),
                    const SizedBox(height: 4),
                    // Solde
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (solde >= 0 ? Colors.green : Colors.red).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: solde >= 0 ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_formatAmount(solde)}€',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: solde >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Aucune donnée',
                  style: TextStyle(
                    fontSize: 11,
                    color: isCurrentMonth ? Colors.white70 : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              // Année en bas
              Text(
                monthDate.year.toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: isCurrentMonth 
                      ? Colors.white70 
                      : (hasData ? Colors.blue.shade600 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDataRow(String label, double amount, Color color, bool isCurrentMonth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isCurrentMonth 
                  ? Colors.white70 
                  : color.withOpacity(0.8),
            ),
          ),
          Text(
            '${_formatAmount(amount)}€',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isCurrentMonth 
                  ? Colors.white 
                  : color,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }
}