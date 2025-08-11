import 'dart:math';
import 'package:flutter/material.dart';
import '../services/encrypted_budget_service.dart';

/// Onglet d'analyse globale remplaçant les projections.
/// Affiche :
/// - Moyennes mensuelles (dépenses, charges, revenus) toutes années confondues
/// - Totaux globaux
/// - Top 10 catégories de dépenses (hors virements)
/// - Evolution annuelle agrégée
class GlobalAnalyseTab extends StatefulWidget {
  const GlobalAnalyseTab({super.key});

  @override
  State<GlobalAnalyseTab> createState() => _GlobalAnalyseTabState();
}

class _GlobalAnalyseTabState extends State<GlobalAnalyseTab> {
  final EncryptedBudgetDataService _dataService = EncryptedBudgetDataService();
  bool _loading = true;

  double _totalRevenus = 0;
  double _totalCharges = 0;
  double _totalDepenses = 0; // hors virements
  double _avgRevenus = 0;
  double _avgCharges = 0;
  double _avgDepenses = 0;

  Map<int, Map<String, double>> _annualAggregates = {}; // year => {revenus, charges, depenses}
  Map<String, double> _depensesParTag = {}; // tag => total

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entrees = await _dataService.getEntrees();
      final sorties = await _dataService.getSorties();
      final plaisirs = await _dataService.getPlaisirs();

      if (entrees.isEmpty && sorties.isEmpty && plaisirs.isEmpty) {
        setState(() { _loading = false; });
        return;
      }

      DateTime? minDate; DateTime? maxDate;
      double totalRevenus = 0;
      double totalCharges = 0;
      double totalDepenses = 0; // sans virements
      final annual = <int, Map<String,double>>{};
      final depensesTag = <String,double>{};

      void updateDateRange(String? dateStr) {
        final d = DateTime.tryParse(dateStr ?? '');
        if (d != null) {
          minDate = (minDate == null || d.isBefore(minDate!)) ? d : minDate;
          maxDate = (maxDate == null || d.isAfter(maxDate!)) ? d : maxDate;
        }
      }

      for (final e in entrees) {
        final amount = (e['amount'] as num?)?.toDouble() ?? 0.0;
        totalRevenus += amount;
        updateDateRange(e['date']);
        final date = DateTime.tryParse(e['date'] ?? '');
        if (date != null) {
          annual.putIfAbsent(date.year, () => {'revenus':0,'charges':0,'depenses':0});
          annual[date.year]!['revenus'] = annual[date.year]!['revenus']! + amount;
        }
      }

      for (final s in sorties) {
        final amount = (s['amount'] as num?)?.toDouble() ?? 0.0;
        totalCharges += amount;
        updateDateRange(s['date']);
        final date = DateTime.tryParse(s['date'] ?? '');
        if (date != null) {
          annual.putIfAbsent(date.year, () => {'revenus':0,'charges':0,'depenses':0});
            annual[date.year]!['charges'] = annual[date.year]!['charges']! + amount;
        }
      }

      for (final p in plaisirs) {
        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        updateDateRange(p['date']);
        final date = DateTime.tryParse(p['date'] ?? '');
        final isCredit = p['isCredit'] == true; // virements / remboursements
        if (!isCredit) {
          totalDepenses += amount;
          final tag = (p['tag'] as String? ?? '').trim();
          if (tag.isNotEmpty) {
            depensesTag[tag] = (depensesTag[tag] ?? 0) + amount;
          }
        }
        if (date != null) {
          annual.putIfAbsent(date.year, () => {'revenus':0,'charges':0,'depenses':0});
          if (!isCredit) {
            annual[date.year]!['depenses'] = annual[date.year]!['depenses']! + amount;
          }
        }
      }

      final totalMonths = _computeDistinctMonthCount(minDate, maxDate);
      double avgRevenus = 0, avgCharges = 0, avgDepenses = 0;
      if (totalMonths > 0) {
        avgRevenus = totalRevenus / totalMonths;
        avgCharges = totalCharges / totalMonths;
        avgDepenses = totalDepenses / totalMonths;
      }

      setState(() {
        _totalRevenus = totalRevenus;
        _totalCharges = totalCharges;
        _totalDepenses = totalDepenses;
        _avgRevenus = avgRevenus;
        _avgCharges = avgCharges;
        _avgDepenses = avgDepenses;
        _annualAggregates = annual;
        _depensesParTag = depensesTag;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement analyse: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _loading = false);
    }
  }

  int _computeDistinctMonthCount(DateTime? minDate, DateTime? maxDate) {
    if (minDate == null || maxDate == null) return 0;
    return (maxDate.year - minDate.year) * 12 + (maxDate.month - minDate.month) + 1;
  }

  String _fmt(double v, {int decimals = 2}) => v.toStringAsFixed(decimals).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final soldeGlobal = _totalRevenus - _totalCharges - _totalDepenses;
    final soldeMoyen = _avgRevenus - _avgCharges - _avgDepenses;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(soldeGlobal, soldeMoyen),
            const SizedBox(height: 16),
            _buildAveragesCard(),
            const SizedBox(height: 16),
            _buildAnnualCard(),
            const SizedBox(height: 16),
            _buildTopTagsCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double soldeGlobal, double soldeMoyen) {
    return Card(
      color: Colors.indigo.shade600,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analyse Globale', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(soldeGlobal >= 0 ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Solde cumulé: ${_fmt(soldeGlobal)} €', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Solde moyen mensuel: ${_fmt(soldeMoyen)} €', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildAveragesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Moyennes Mensuelles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildKpi('Revenus', _avgRevenus, Colors.green),
                _buildKpi('Charges', _avgCharges, Colors.red),
                _buildKpi('Dépenses', _avgDepenses, Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildKpi('Total Rev.', _totalRevenus, Colors.green.shade700),
                _buildKpi('Total Ch.', _totalCharges, Colors.red.shade700),
                _buildKpi('Total Dép.', _totalDepenses, Colors.purple.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnualCard() {
    final years = _annualAggregates.keys.toList()..sort();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Evolution Annuelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final y in years) _buildAnnualRow(y, _annualAggregates[y]!),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnualRow(int year, Map<String,double> data) {
    final solde = data['revenus']! - data['charges']! - data['depenses']!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(year.toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: _buildBar(data['revenus']!, Colors.green)),
          Expanded(child: _buildBar(data['charges']!, Colors.red)),
          Expanded(child: _buildBar(data['depenses']!, Colors.purple)),
          SizedBox(width: 80, child: Text(_fmt(solde), textAlign: TextAlign.right, style: TextStyle(color: solde>=0?Colors.green:Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildBar(double value, Color color) {
    final width = (value <= 0) ? 0.0 : (value.logSafe() * 12); // simple scale
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 12,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _buildTopTagsCard() {
    if (_depensesParTag.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucune catégorie de dépenses disponible.'),
        ),
      );
    }
    final sorted = _depensesParTag.entries.toList()
      ..sort((a,b) => b.value.compareTo(a.value));
    final top = sorted.take(10).toList();
    final total = _depensesParTag.values.fold(0.0, (s,v)=>s+v);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top 10 Dépenses par Catégorie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final e in top) _buildTagRow(e.key, e.value, total),
          ],
        ),
      ),
    );
  }

  Widget _buildTagRow(String tag, double value, double total) {
    final pct = total>0 ? (value/total*100) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: total>0 ? value/total : 0,
              backgroundColor: Colors.purple.withValues(alpha: 0.15),
              color: Colors.purple,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
            Text('${_fmt(value)}€', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          SizedBox(width: 46, child: Text('${pct.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: const TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildKpi(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('${_fmt(value)}€', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

extension _LogSafe on double {
  double logSafe() {
    if (this <= 0) return 0;
    return (log(this) / 2.0) + 1; // scale natural log
  }
}
