import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/encrypted_budget_service.dart';

class ProjectionsTab extends StatefulWidget {
  const ProjectionsTab({super.key});

  @override
  State<ProjectionsTab> createState() => _ProjectionsTabState();
}

class _ProjectionsTabState extends State<ProjectionsTab> {
  DateTime _currentDate = DateTime.now();
  PageController _pageController = PageController();
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  Map<String, Map<String, double>> _monthlyData = {}; // Format: "2024-01" -> {revenus, charges, depenses}
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialiser le contrôleur de page au mois actuel (index 50 pour avoir de la marge)
    _pageController = PageController(initialPage: _getMonthIndex(_currentDate));
    _loadAllData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getMonthIndex(DateTime date) {
    // Index basé sur le nombre de mois depuis janvier 2020
    return (date.year - 2020) * 12 + date.month - 1;
  }

  DateTime _getDateFromIndex(int index) {
    // Convertir l'index en date
    int year = 2020 + (index ~/ 12);
    int month = (index % 12) + 1;
    return DateTime(year, month, 1);
  }

  String _getMonthKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}";
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger toutes les données
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

  void _previousMonth() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextMonth() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToToday() {
    DateTime today = DateTime.now();
    int todayIndex = _getMonthIndex(today);
    _pageController.animateToPage(
      todayIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildCalendarHeader(DateTime date) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy', 'fr_FR').format(date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _goToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Aujourd\'hui',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildYearGrid(int year) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // En-tête de l'année
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade600, Colors.teal.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
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
          
          // Grille des mois (3 colonnes x 4 lignes)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final monthDate = DateTime(year, month, 1);
              final monthKey = _getMonthKey(monthDate);
              final monthData = _monthlyData[monthKey] ?? {'revenus': 0.0, 'charges': 0.0, 'depenses': 0.0};
              final isCurrentMonth = DateTime.now().year == year && DateTime.now().month == month;
              
              return GestureDetector(
                onTap: () => _showMonthDetails(monthDate, monthData),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrentMonth 
                        ? Colors.indigo.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrentMonth 
                          ? Colors.indigo
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      width: isCurrentMonth ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                                color: isCurrentMonth ? Colors.indigo : null,
                              ),
                            ),
                            if (isCurrentMonth)
                              Icon(
                                Icons.today,
                                size: 16,
                                color: Colors.indigo,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Revenus
                        _buildMonthDataRow(
                          'Revenus',
                          monthData['revenus']!,
                          Colors.green,
                          Icons.trending_up,
                        ),
                        const SizedBox(height: 4),
                        
                        // Charges
                        _buildMonthDataRow(
                          'Charges',
                          monthData['charges']!,
                          Colors.red,
                          Icons.receipt_long,
                        ),
                        const SizedBox(height: 4),
                        
                        // Dépenses
                        _buildMonthDataRow(
                          'Dépenses',
                          monthData['depenses']!,
                          Colors.purple,
                          Icons.shopping_cart,
                        ),
                        const SizedBox(height: 8),
                        
                        // Solde du mois
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 12,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Solde',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_formatAmount(monthData['revenus']! - monthData['charges']! - monthData['depenses']!)} €',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: (monthData['revenus']! - monthData['charges']! - monthData['depenses']!) >= 0 
                                ? Colors.green 
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthDataRow(String label, double amount, Color color, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
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

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAll('.', ',');
  }

  void _showMonthDetails(DateTime monthDate, Map<String, double> monthData) {
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
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
                  _buildDetailRow(
                    'Revenus',
                    monthData['revenus']!,
                    Colors.green,
                    Icons.trending_up,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Charges',
                    monthData['charges']!,
                    Colors.red,
                    Icons.receipt_long,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Dépenses',
                    monthData['depenses']!,
                    Colors.purple,
                    Icons.shopping_cart,
                  ),
                  const SizedBox(height: 24),
                  
                  Divider(thickness: 2),
                  const SizedBox(height: 16),
                  
                  // Solde total
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (monthData['revenus']! - monthData['charges']! - monthData['depenses']!) >= 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (monthData['revenus']! - monthData['charges']! - monthData['depenses']!) >= 0
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: (monthData['revenus']! - monthData['charges']! - monthData['depenses']!) >= 0
                              ? Colors.green
                              : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Solde du mois',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: (monthData['revenus']! - monthData['charges']! - monthData['depenses']!) >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                              Text(
                                '${_formatAmount(monthData['revenus']! - monthData['charges']! - monthData['depenses']!)} €',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: (monthData['revenus']! - monthData['charges']! - monthData['depenses']!) >= 0
                                      ? Colors.green
                                      : Colors.red,
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
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, double amount, Color color, IconData icon) {
    return Container(
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
              Text('Chargement des projections...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // En-tête avec navigation
          Container(
            margin: const EdgeInsets.all(16),
            child: _buildCalendarHeader(_currentDate),
          ),
          
          // Vue par années avec défilement
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentDate = _getDateFromIndex(index);
                });
              },
              itemBuilder: (context, index) {
                final date = _getDateFromIndex(index);
                return RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: _buildYearGrid(date.year),
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