import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProjectionsTab extends StatefulWidget {
  const ProjectionsTab({super.key});

  @override
  State<ProjectionsTab> createState() => _ProjectionsTabState();
}

class _ProjectionsTabState extends State<ProjectionsTab> {
  DateTime _currentDate = DateTime.now();
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Initialiser le contrôleur de page au mois actuel
    _pageController = PageController(initialPage: _getMonthIndex(_currentDate));
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

  Widget _buildWeekDaysHeader() {
    const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: weekDays.map((day) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              day,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final today = DateTime.now();
    
    // Calculer le premier lundi de la grille
    int firstWeekday = firstDayOfMonth.weekday;
    DateTime firstMondayOfGrid = firstDayOfMonth.subtract(Duration(days: firstWeekday - 1));
    
    // Générer 42 jours (6 semaines)
    List<DateTime> calendarDays = List.generate(42, (index) {
      return firstMondayOfGrid.add(Duration(days: index));
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.0,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: 42,
        itemBuilder: (context, index) {
          final day = calendarDays[index];
          final isCurrentMonth = day.month == date.month;
          final isToday = day.day == today.day && 
                         day.month == today.month && 
                         day.year == today.year;
          final isWeekend = day.weekday == 6 || day.weekday == 7;

          return GestureDetector(
            onTap: isCurrentMonth ? () {
              _showDayDetails(day);
            } : null,
            child: Container(
              decoration: BoxDecoration(
                color: _getDayColor(isCurrentMonth, isToday, isWeekend),
                borderRadius: BorderRadius.circular(8),
                border: isToday ? Border.all(
                  color: Colors.indigo,
                  width: 2,
                ) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: _getDayTextColor(isCurrentMonth, isToday, isWeekend),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  // Indicateur pour les jours avec des transactions
                  if (isCurrentMonth && _hasTransactions(day))
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getDayColor(bool isCurrentMonth, bool isToday, bool isWeekend) {
    if (isToday) {
      return Colors.indigo.withValues(alpha: 0.2);
    }
    if (!isCurrentMonth) {
      return Colors.transparent;
    }
    if (isWeekend) {
      return Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    }
    return Theme.of(context).colorScheme.surface;
  }

  Color _getDayTextColor(bool isCurrentMonth, bool isToday, bool isWeekend) {
    if (isToday) {
      return Colors.indigo;
    }
    if (!isCurrentMonth) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
    }
    if (isWeekend) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  bool _hasTransactions(DateTime day) {
    // Exemple simple - remplacer par la vraie logique plus tard
    return day.day % 5 == 0;
  }

  void _showDayDetails(DateTime day) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(day),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Fonctionnalité en développement...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // En-tête avec navigation
          Container(
            margin: const EdgeInsets.all(16),
            child: _buildCalendarHeader(_currentDate),
          ),
          
          // En-tête des jours de la semaine
          _buildWeekDaysHeader(),
          
          // Calendrier avec PageView
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
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCalendarGrid(date),
                      const SizedBox(height: 20),
                    ],
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