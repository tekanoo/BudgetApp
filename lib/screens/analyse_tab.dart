import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyseTab extends StatefulWidget {
  const AnalyseTab({super.key});

  @override
  State<AnalyseTab> createState() => _AnalyseTabState();
}

class _AnalyseTabState extends State<AnalyseTab> {
  double totalEntrees = 0;
  double totalSorties = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final entreesStr = prefs.getStringList('entrees') ?? [];
    final sortiesStr = prefs.getStringList('sorties') ?? [];

    double sumEntrees = 0;
    for (var s in entreesStr) {
      final montant = _extractMontant(s);
      sumEntrees += montant;
    }

    double sumSorties = 0;
    for (var s in sortiesStr) {
      final montant = _extractMontant(s);
      sumSorties += montant;
    }

    setState(() {
      totalEntrees = sumEntrees;
      totalSorties = sumSorties;
      isLoading = false;
    });
  }

  double _extractMontant(String s) {
    final clean = s.replaceAll(RegExp(r'[{}]'), '');
    final parts = clean.split(',');
    for (var part in parts) {
      final kv = part.split(':');
      if (kv.length == 2) {
        if (kv[0].trim() == 'montant') {
          return double.tryParse(kv[1].trim()) ?? 0;
        }
      }
    }
    return 0;
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
                  Text(
                    'Répartition détaillée',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: totalEntrees > 0 || totalSorties > 0
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
                  _buildLegendItem('Entrées', Colors.green, totalEntrees),
                  _buildLegendItem('Sorties', Colors.red, totalSorties),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double value) {
    final total = totalEntrees + totalSorties;
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final difference = totalEntrees - totalSorties;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                          'Entrées',
                          totalEntrees,
                          Colors.green,
                          Icons.trending_up,
                        ),
                        _buildSummaryItem(
                          'Sorties',
                          totalSorties,
                          Colors.red,
                          Icons.trending_down,
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

            // Graphique en secteurs
            if (totalEntrees > 0 || totalSorties > 0) ...[
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
                              'Répartition',
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
                      'Ratio charges/entrées',
                      '${(totalEntrees == 0 ? 0 : (totalSorties / totalEntrees) * 100).toStringAsFixed(1)}%',
                      (totalEntrees == 0 ? 0 : (totalSorties / totalEntrees) * 100) > 80 ? Colors.red : (totalEntrees == 0 ? 0 : (totalSorties / totalEntrees) * 100) > 60 ? Colors.orange : Colors.green,
                    ),
                    _buildMetricRow(
                      'Économies potentielles',
                      difference >= 0 ? '${difference.toStringAsFixed(2)} €' : 'Déficit',
                      difference >= 0 ? Colors.green : Colors.red,
                    ),
                    _buildMetricRow(
                      'Santé financière',
                      _getHealthStatus(totalEntrees == 0 ? 0 : (totalSorties / totalEntrees) * 100, difference),
                      _getHealthColor(totalEntrees == 0 ? 0 : (totalSorties / totalEntrees) * 100, difference),
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
        Text(
          '${value.toStringAsFixed(2)} €',
          style: TextStyle(
            fontSize: isLarge ? 24 : 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
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
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections({bool enlarged = false}) {
    final double total = totalEntrees + totalSorties;
    return [
      PieChartSectionData(
        color: Colors.green,
        value: totalEntrees.toDouble(),
        title: enlarged ? 'Entrées\n${totalEntrees.toStringAsFixed(2)} €\n${total > 0 ? ((totalEntrees / total) * 100).toStringAsFixed(1) : '0'}%' : 'Entrées\n${total > 0 ? ((totalEntrees / total) * 100).toStringAsFixed(1) : '0'}%',
        radius: enlarged ? 120.0 : 80.0,
        titleStyle: TextStyle(
          fontSize: enlarged ? 14 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: totalSorties.toDouble(),
        title: enlarged ? 'Sorties\n${totalSorties.toStringAsFixed(2)} €\n${total > 0 ? ((totalSorties / total) * 100).toStringAsFixed(1) : '0'}%' : 'Sorties\n${total > 0 ? ((totalSorties / total) * 100).toStringAsFixed(1) : '0'}%',
        radius: enlarged ? 120.0 : 80.0,
        titleStyle: TextStyle(
          fontSize: enlarged ? 14 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  String _getHealthStatus(double ratio, double difference) {
    if (difference < 0) return 'Déficitaire';
    if (ratio > 80) return 'À risque';
    if (ratio > 60) return 'Acceptable';
    return 'Excellente';
  }

  Color _getHealthColor(double ratio, double difference) {
    if (difference < 0) return Colors.red;
    if (ratio > 80) return Colors.red;
    if (ratio > 60) return Colors.orange;
    return Colors.green;
  }
}