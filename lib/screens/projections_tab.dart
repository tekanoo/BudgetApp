import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/encrypted_budget_service.dart';

class ProjectionsTab extends StatefulWidget {
  const ProjectionsTab({super.key});

  @override
  State<ProjectionsTab> createState() => _ProjectionsTabState();
}

class _ProjectionsTabState extends State<ProjectionsTab> {
  final ScrollController _scrollController = ScrollController();
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  Map<String, Map<String, double>> _monthlyData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getMonthKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}";
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entrees = await _dataService.getEntrees();
      final sorties = await _dataService.getSorties();
      final plaisirs = await _dataService.getPlaisirs();

      Map<String, Map<String, double>> monthlyData = {};

      // Analyser les revenus par mois
      for (var entree in entrees) {
        final dateStr = entree['date'] as String? ?? '';
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final monthKey = _getMonthKey(date);
          final amount = (entree['amount'] as num?)?.toDouble() ?? 0.0;
          
          monthlyData[monthKey] ??= {'revenus': 0.0, 'charges': 0.0, 'depenses': 0.0};
          monthlyData[monthKey]!['revenus'] = monthlyData[monthKey]!['revenus']! + amount;
        }
      }

      // Analyser les charges par mois
      for (var sortie in sorties) {
        final dateStr = sortie['date'] as String? ?? '';
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final monthKey = _getMonthKey(date);
          final amount = (sortie['amount'] as num?)?.toDouble() ?? 0.0;
          
          monthlyData[monthKey] ??= {'revenus': 0.0, 'charges': 0.0, 'depenses': 0.0};
          monthlyData[monthKey]!['charges'] = monthlyData[monthKey]!['charges']! + amount;
        }
      }

      // Analyser les dépenses par mois
      for (var plaisir in plaisirs) {
        final dateStr = plaisir['date'] as String? ?? '';
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final monthKey = _getMonthKey(date);
          final amount = (plaisir['amount'] as num?)?.toDouble() ?? 0.0;
          final isCredit = plaisir['isCredit'] == true;
          
          monthlyData[monthKey] ??= {'revenus': 0.0, 'charges': 0.0, 'depenses': 0.0};
          if (isCredit) {
            monthlyData[monthKey]!['depenses'] = monthlyData[monthKey]!['depenses']! - amount;
          } else {
            monthlyData[monthKey]!['depenses'] = monthlyData[monthKey]!['depenses']! + amount;
          }
        }
      }

      setState(() {
        _monthlyData = monthlyData;
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

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAll('.', ',');
  }

  Widget _buildYearCard(int year) {
    final months = List.generate(12, (index) => DateTime(year, index + 1, 1));
    
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Column(
        children: [
          // En-tête de l'année
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3F51B5), Color(0xFF1A237E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              year.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Grille des mois
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final monthDate = months[index];
                final monthKey = _getMonthKey(monthDate);
                final monthData = _monthlyData[monthKey] ?? {'revenus': 0.0, 'charges': 0.0, 'depenses': 0.0};
                final isCurrentMonth = DateTime.now().year == year && DateTime.now().month == monthDate.month;
                final solde = monthData['revenus']! - monthData['charges']! - monthData['depenses']!;
                
                return GestureDetector(
                  onTap: () => _showMonthDetails(monthDate, monthData),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrentMonth 
                          ? Colors.indigo.withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentMonth 
                            ? Colors.indigo
                            : Colors.grey.shade300,
                        width: isCurrentMonth ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom du mois
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM', 'fr_FR').format(monthDate),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isCurrentMonth ? Colors.indigo : Colors.black87,
                              ),
                            ),
                            if (isCurrentMonth)
                              const Icon(
                                Icons.today,
                                size: 16,
                                color: Colors.indigo,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Revenus
                        _buildDataRow('Revenus', monthData['revenus']!, Colors.green),
                        const SizedBox(height: 4),
                        
                        // Charges
                        _buildDataRow('Charges', monthData['charges']!, Colors.red),
                        const SizedBox(height: 4),
                        
                        // Dépenses
                        _buildDataRow('Dépenses', monthData['depenses']!, Colors.purple),
                        const SizedBox(height: 8),
                        
                        // Solde
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: solde >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: solde >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Solde',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: solde >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                              Text(
                                '${_formatAmount(solde)} €',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: solde >= 0 ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, double amount, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showMonthDetails(DateTime monthDate, Map<String, double> monthData) {
    final solde = monthData['revenus']! - monthData['charges']! - monthData['depenses']!;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
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
            
            // Titre
            Text(
              DateFormat('MMMM yyyy', 'fr_FR').format(monthDate),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            
            // Détails financiers
            Expanded(
              child: Column(
                children: [
                  _buildDetailCard('Revenus', monthData['revenus']!, Colors.green, Icons.trending_up),
                  const SizedBox(height: 16),
                  _buildDetailCard('Charges', monthData['charges']!, Colors.red, Icons.receipt_long),
                  const SizedBox(height: 16),
                  _buildDetailCard('Dépenses', monthData['depenses']!, Colors.purple, Icons.shopping_cart),
                  const SizedBox(height: 24),
                  
                  // Solde total
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: solde >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: solde >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: solde >= 0 ? Colors.green : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Solde du mois',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: solde >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        Text(
                          '${_formatAmount(solde)} €',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: solde >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, double amount, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                Text(
                  '${_formatAmount(amount)} €',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Chargement des projections...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Générer les années de 2020 à 2030
    final years = List.generate(11, (index) => 2020 + index);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projections'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // En-tête informatif
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Visualisez vos finances mois par mois. Tapez sur un mois pour voir les détails.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Années avec leurs mois
              ...years.map((year) => _buildYearCard(year)),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}