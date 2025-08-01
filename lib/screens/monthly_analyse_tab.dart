import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/encrypted_budget_service.dart';

class MonthlyAnalyseTab extends StatefulWidget {
  final DateTime selectedMonth;
  
  const MonthlyAnalyseTab({
    super.key,
    required this.selectedMonth,
  });

  @override
  State<MonthlyAnalyseTab> createState() => _MonthlyAnalyseTabState();
}

class _MonthlyAnalyseTabState extends State<MonthlyAnalyseTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  double totalEntrees = 0;
  double totalSorties = 0;
  double totalPlaisirs = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  Future<void> _loadMonthlyData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Charger toutes les données puis filtrer par mois
      final entrees = await _dataService.getEntrees();
      final sorties = await _dataService.getSorties();
      final plaisirs = await _dataService.getPlaisirs();
      
      // Filtrer par mois sélectionné
      final monthlyEntrees = entrees.where((e) {
        final date = DateTime.tryParse(e['date'] ?? '');
        return date != null && 
               date.year == widget.selectedMonth.year &&
               date.month == widget.selectedMonth.month;
      }).fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
      
      final monthlySorties = sorties.where((s) {
        final date = DateTime.tryParse(s['date'] ?? '');
        return date != null && 
               date.year == widget.selectedMonth.year &&
               date.month == widget.selectedMonth.month;
      }).fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0.0));
      
      // Pour les plaisirs, tenir compte des crédits (isCredit)
      double monthlyPlaisirs = 0.0;
      for (var plaisir in plaisirs) {
        final date = DateTime.tryParse(plaisir['date'] ?? '');
        if (date != null && 
            date.year == widget.selectedMonth.year &&
            date.month == widget.selectedMonth.month) {
          final amount = (plaisir['amount'] as num?)?.toDouble() ?? 0.0;
          if (plaisir['isCredit'] == true) {
            monthlyPlaisirs -= amount; // Les crédits réduisent le total
          } else {
            monthlyPlaisirs += amount; // Les dépenses augmentent le total
          }
        }
      }
      
      setState(() {
        totalEntrees = monthlyEntrees;
        totalSorties = monthlySorties;
        totalPlaisirs = monthlyPlaisirs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getMonthName(DateTime date) {
    const monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('🔓 Analyse du mois en cours...'),
          ],
        ),
      );
    }

    final difference = totalEntrees - totalSorties - totalPlaisirs;
    final monthName = _getMonthName(widget.selectedMonth);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // En-tête avec mois sélectionné
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analyse de $monthName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Données mensuelles sécurisées',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Carte de résumé mensuel
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Résumé de $monthName',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Revenus',
                        totalEntrees,
                        Colors.green,
                        Icons.trending_up,
                      ),
                      _buildSummaryItem(
                        'Charges',
                        totalSorties,
                        Colors.red,
                        Icons.receipt_long,
                      ),
                      _buildSummaryItem(
                        'Dépenses',
                        totalPlaisirs,
                        Colors.purple,
                        Icons.shopping_cart,
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  _buildSummaryItem(
                    'Solde',
                    difference,
                    difference >= 0 ? Colors.green : Colors.red,
                    difference >= 0 ? Icons.trending_up : Icons.trending_down,
                    isLarge: true,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          // Affichage des données ou message si vide
          if (totalEntrees > 0 || totalSorties > 0 || totalPlaisirs > 0) ...[
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Répartition des finances',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _buildPieChartSections(),
                          centerSpaceRadius: 60,
                          sectionsSpace: 4,
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendItem('Revenus', Colors.green, totalEntrees),
                        _buildLegendItem('Charges', Colors.red, totalSorties),
                        _buildLegendItem('Dépenses', Colors.purple, totalPlaisirs),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune donnée pour $monthName',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ajoutez des revenus, charges ou dépenses pour voir l\'analyse',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color, IconData icon, {bool isLarge = false}) {
    return Column(
      children: [
        Icon(icon, color: color, size: isLarge ? 32 : 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 18 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(2)} €',
          style: TextStyle(
            fontSize: isLarge ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, double value) {
    final total = totalEntrees + totalSorties + totalPlaisirs.abs();
    final percentage = total > 0 ? (value.abs() / total) * 100 : 0;
    
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(2)} €',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final double total = totalEntrees + totalSorties + totalPlaisirs.abs();
    final List<PieChartSectionData> sections = [];

    if (totalEntrees > 0) {
      sections.add(PieChartSectionData(
        color: Colors.green,
        value: totalEntrees,
        title: '${((totalEntrees / total) * 100).toStringAsFixed(1)}%',
        radius: 80.0,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (totalSorties > 0) {
      sections.add(PieChartSectionData(
        color: Colors.red,
        value: totalSorties,
        title: '${((totalSorties / total) * 100).toStringAsFixed(1)}%',
        radius: 80.0,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (totalPlaisirs.abs() > 0) {
      sections.add(PieChartSectionData(
        color: Colors.purple,
        value: totalPlaisirs.abs(),
        title: '${((totalPlaisirs.abs() / total) * 100).toStringAsFixed(1)}%',
        radius: 80.0,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    return sections;
  }
}