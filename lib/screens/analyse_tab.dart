import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/encrypted_budget_service.dart'; // CHANGÉ: service chiffré

class AnalyseTab extends StatefulWidget {
  const AnalyseTab({super.key});

  @override
  State<AnalyseTab> createState() => _AnalyseTabState();
}

class _AnalyseTabState extends State<AnalyseTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService(); // CHANGÉ
  double totalEntrees = 0;
  double totalSorties = 0;
  double totalPlaisirs = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Charge toutes les données (automatiquement déchiffrées)
      final totals = await _dataService.getTotals();
      
      setState(() {
        totalEntrees = totals['entrees'] ?? 0.0;
        totalSorties = totals['sorties'] ?? 0.0;
        totalPlaisirs = totals['plaisirs'] ?? 0.0;
        isLoading = false;
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

  void _showEnlargedChart() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Répartition détaillée',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      // Indicateur de sécurité
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.security, size: 12, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Données déchiffrées',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: (totalEntrees > 0 || totalSorties > 0 || totalPlaisirs > 0)
                    ? PieChart(
                        PieChartData(
                          sections: _buildPieChartSections(enlarged: true),
                          centerSpaceRadius: 80,
                          sectionsSpace: 6,
                          borderData: FlBorderData(show: false),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Aucune donnée à afficher',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
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
    );
  }

  Widget _buildLegendItem(String label, Color color, double value) {
    final total = totalEntrees + totalSorties + totalPlaisirs;
    final percentage = total > 0 ? (value / total) * 100 : 0;
    
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${value.toStringAsFixed(2)} €',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.lock_open,
              size: 12,
              color: Colors.green.shade600,
            ),
          ],
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
              Text('🔓 Déchiffrement des données en cours...'),
            ],
          ),
        ),
      );
    }

    final difference = totalEntrees - totalSorties - totalPlaisirs;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // En-tête sécurisé
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
                        const Text(
                          'Analyse Financière Sécurisée',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Données déchiffrées en temps réel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.security, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Sécurisé',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Carte de résumé
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Résumé du mois',
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
                    const SizedBox(height: 10),
                    // Note de sécurité
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.green.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ces montants sont stockés chiffrés dans la base de données',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Graphique en secteurs
            if (totalEntrees > 0 || totalSorties > 0 || totalPlaisirs > 0) ...[
              Card(
                elevation: 4,
                child: InkWell(
                  onTap: _showEnlargedChart,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Répartition des finances',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Icon(
                              Icons.zoom_in,
                              color: Colors.grey,
                            ),
                          ],
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
                        const SizedBox(height: 10),
                        const Text(
                          'Touchez pour agrandir',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],

            // Métriques détaillées
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Métriques détaillées',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _buildMetricRow(
                      'Ratio charges/revenus',
                      '${(totalEntrees == 0 ? 0 : (totalSorties / totalEntrees) * 100).toStringAsFixed(1)}%',
                      _getRatioColor((totalEntrees == 0 ? 0 : (totalSorties / totalEntrees) * 100)),
                    ),
                    _buildMetricRow(
                      'Ratio dépenses/revenus',
                      '${(totalEntrees == 0 ? 0 : (totalPlaisirs / totalEntrees) * 100).toStringAsFixed(1)}%',
                      _getRatioColor((totalEntrees == 0 ? 0 : (totalPlaisirs / totalEntrees) * 100)),
                    ),
                    _buildMetricRow(
                      'Économies potentielles',
                      difference >= 0 ? '${difference.toStringAsFixed(2)} €' : 'Déficit',
                      difference >= 0 ? Colors.green : Colors.red,
                    ),
                    _buildMetricRow(
                      'Santé financière',
                      _getHealthStatus(totalEntrees == 0 ? 0 : ((totalSorties + totalPlaisirs) / totalEntrees) * 100, difference),
                      _getHealthColor(totalEntrees == 0 ? 0 : ((totalSorties + totalPlaisirs) / totalEntrees) * 100, difference),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${value.toStringAsFixed(2)} €',
              style: TextStyle(
                fontSize: isLarge ? 24 : 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.lock_open,
              size: isLarge ? 16 : 12,
              color: Colors.green.shade600,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.calculate,
                size: 14,
                color: Colors.green.shade600,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections({bool enlarged = false}) {
    final double total = totalEntrees + totalSorties + totalPlaisirs;
    final List<PieChartSectionData> sections = [];

    if (totalEntrees > 0) {
      sections.add(PieChartSectionData(
        color: Colors.green,
        value: totalEntrees,
        title: enlarged 
          ? 'Revenus\n${totalEntrees.toStringAsFixed(2)} €\n${((totalEntrees / total) * 100).toStringAsFixed(1)}%' 
          : '${((totalEntrees / total) * 100).toStringAsFixed(1)}%',
        radius: enlarged ? 120.0 : 80.0,
        titleStyle: TextStyle(
          fontSize: enlarged ? 14 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (totalSorties > 0) {
      sections.add(PieChartSectionData(
        color: Colors.red,
        value: totalSorties,
        title: enlarged 
          ? 'Charges\n${totalSorties.toStringAsFixed(2)} €\n${((totalSorties / total) * 100).toStringAsFixed(1)}%' 
          : '${((totalSorties / total) * 100).toStringAsFixed(1)}%',
        radius: enlarged ? 120.0 : 80.0,
        titleStyle: TextStyle(
          fontSize: enlarged ? 14 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (totalPlaisirs > 0) {
      sections.add(PieChartSectionData(
        color: Colors.purple,
        value: totalPlaisirs,
        title: enlarged 
          ? 'Dépenses\n${totalPlaisirs.toStringAsFixed(2)} €\n${((totalPlaisirs / total) * 100).toStringAsFixed(1)}%' 
          : '${((totalPlaisirs / total) * 100).toStringAsFixed(1)}%',
        radius: enlarged ? 120.0 : 80.0,
        titleStyle: TextStyle(
          fontSize: enlarged ? 14 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    return sections;
  }

  Color _getRatioColor(double ratio) {
    if (ratio > 80) return Colors.red;
    if (ratio > 60) return Colors.orange;
    if (ratio > 40) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getHealthStatus(double ratio, double difference) {
    if (difference < 0) return 'Déficitaire';
    if (ratio > 90) return 'À risque';
    if (ratio > 70) return 'Acceptable';
    if (ratio > 50) return 'Bonne';
    return 'Excellente';
  }

  Color _getHealthColor(double ratio, double difference) {
    if (difference < 0) return Colors.red;
    if (ratio > 90) return Colors.red;
    if (ratio > 70) return Colors.orange;
    if (ratio > 50) return Colors.yellow.shade700;
    return Colors.green;
  }
}