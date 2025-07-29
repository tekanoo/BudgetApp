import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'monthly_budget_screen.dart';

class MonthSelectorScreen extends StatefulWidget {
  const MonthSelectorScreen({super.key});

  @override
  State<MonthSelectorScreen> createState() => _MonthSelectorScreenState();
}

class _MonthSelectorScreenState extends State<MonthSelectorScreen> {
  int _currentYear = DateTime.now().year;
  
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
              // Navigation vers analyse globale
            },
          ),
        ],
      ),
      body: Column(
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
                crossAxisCount: 3,
                childAspectRatio: 1.2,
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
    final monthName = DateFormat('MMMM', 'fr_FR').format(monthDate);
    
    return Card(
      elevation: isCurrentMonth ? 8 : 4,
      color: isCurrentMonth ? Theme.of(context).primaryColor : null,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                monthName.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCurrentMonth ? Colors.white : null,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.calendar_month,
                size: 32,
                color: isCurrentMonth ? Colors.white : Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                monthDate.year.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrentMonth ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}