import 'package:flutter/material.dart';

class PeriodicitySelector extends StatelessWidget {
  final String? selectedPeriodicity;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const PeriodicitySelector({
    super.key,
    required this.selectedPeriodicity,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const periodicities = [
      {'value': 'ponctuel', 'label': 'Ponctuel', 'icon': Icons.event},
      {'value': 'mensuel', 'label': 'Mensuel', 'icon': Icons.calendar_month},
      {'value': 'hebdomadaire', 'label': 'Hebdomadaire', 'icon': Icons.view_week},
      {'value': 'annuel', 'label': 'Annuel', 'icon': Icons.calendar_today},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Périodicité',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: periodicities.map((periodicity) {
              final isSelected = selectedPeriodicity == periodicity['value'];
              
              return InkWell(
                onTap: enabled ? () => onChanged(periodicity['value'] as String) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: periodicity != periodicities.last ? 1 : 0,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: periodicity['value'] as String,
                        groupValue: selectedPeriodicity,
                        onChanged: enabled ? onChanged : null,
                        activeColor: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        periodicity['icon'] as IconData,
                        color: isSelected ? Colors.blue : Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          periodicity['label'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.blue,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        _buildPeriodicityHelper(),
      ],
    );
  }

  Widget _buildPeriodicityHelper() {
    if (selectedPeriodicity == null) return const SizedBox.shrink();
    
    String helperText;
    IconData helperIcon;
    Color helperColor;
    
    switch (selectedPeriodicity) {
      case 'ponctuel':
        helperText = 'Cette transaction n\'apparaîtra qu\'une seule fois';
        helperIcon = Icons.info_outline;
        helperColor = Colors.blue;
        break;
      case 'mensuel':
        helperText = 'Cette transaction sera répétée chaque mois dans les projections futures';
        helperIcon = Icons.repeat;
        helperColor = Colors.green;
        break;
      case 'hebdomadaire':
        helperText = 'Cette transaction sera calculée ~4.33 fois par mois (52 semaines/an)';
        helperIcon = Icons.schedule;
        helperColor = Colors.orange;
        break;
      case 'annuel':
        helperText = 'Cette transaction sera répétée chaque année au même mois';
        helperIcon = Icons.event_repeat;
        helperColor = Colors.purple;
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: helperColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: helperColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(helperIcon, color: helperColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: helperColor.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}