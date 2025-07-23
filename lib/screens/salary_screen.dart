import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_menu_screen.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final TextEditingController _salaryController = TextEditingController();
  bool _isLoading = false;

  Future<void> _goToNextScreen() async {
    final salary = double.tryParse(_salaryController.text);
    if (salary != null && salary > 0) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Sauvegarder le salaire dans SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('monthly_salary', salary);
        
        if (!mounted) return;
        
        // Naviguer vers l'écran principal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainMenuScreen()),
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un montant valide supérieur à 0.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salaire mensuel'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 30),
            Text(
              'Quel est votre salaire net mensuel ?',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _salaryController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Salaire mensuel',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro),
                suffixText: '€',
                helperText: 'Entrez votre salaire net mensuel',
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _goToNextScreen,
                icon: _isLoading 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : const Icon(Icons.arrow_forward),
                label: Text(_isLoading ? 'Sauvegarde...' : 'Suivant'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                );
              },
              child: const Text('Passer cette étape'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }
}