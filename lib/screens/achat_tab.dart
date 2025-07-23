import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AchatTab extends StatefulWidget {
  const AchatTab({super.key});

  @override
  State<AchatTab> createState() => _AchatTabState();
}

class _AchatTabState extends State<AchatTab> {
  List<Map<String, String>> operations = [];

  @override
  void initState() {
    super.initState();
    _loadOperations();
  }

  Future<void> _loadOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final opsStringList = prefs.getStringList('operations') ?? [];
    final List<Map<String, String>> ops = opsStringList.map((e) {
      // On récupère la string stockée type {amount: ..., date: ..., tag: ...}
      final clean = e.replaceAll(RegExp(r'[{}]'), '');
      final parts = clean.split(',');
      final map = <String, String>{};
      for (var part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          map[keyValue[0].trim()] = keyValue[1].trim();
        }
      }
      return map;
    }).toList();

    setState(() {
      operations = ops;
    });
  }

  double get totalMontant {
    double sum = 0;
    for (var op in operations) {
      sum += double.tryParse(op['amount'] ?? '0') ?? 0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achats'),
      ),
      body: operations.isEmpty
          ? const Center(child: Text('Aucun achat enregistré'))
          : ListView.builder(
              itemCount: operations.length + 1,
              itemBuilder: (context, index) {
                if (index == operations.length) {
                  return ListTile(
                    title: const Text('Total'),
                    trailing: Text('${totalMontant.toStringAsFixed(2)} €'),
                  );
                }
                final op = operations[index];
                return ListTile(
                  title: Text('Montant: ${op['amount']} €'),
                  subtitle: Text('Tag: ${op['tag']}\nDate: ${op['date']?.split('T').first}'),
                );
              },
            ),
    );
  }
}
