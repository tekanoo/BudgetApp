import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return PopupMenuButton<ThemeMode>(
          icon: Icon(
            _getThemeIcon(themeService.themeMode),
            color: Theme.of(context).colorScheme.onSurface,
          ),
          tooltip: 'Changer le thème',
          onSelected: (ThemeMode mode) {
            themeService.setThemeMode(mode);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: ThemeMode.system,
              child: Row(
                children: [
                  Icon(
                    Icons.brightness_auto,
                    color: themeService.themeMode == ThemeMode.system 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Automatique',
                    style: TextStyle(
                      fontWeight: themeService.themeMode == ThemeMode.system 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                      color: themeService.themeMode == ThemeMode.system 
                          ? Theme.of(context).colorScheme.primary 
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: ThemeMode.light,
              child: Row(
                children: [
                  Icon(
                    Icons.light_mode,
                    color: themeService.themeMode == ThemeMode.light 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mode clair',
                    style: TextStyle(
                      fontWeight: themeService.themeMode == ThemeMode.light 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                      color: themeService.themeMode == ThemeMode.light 
                          ? Theme.of(context).colorScheme.primary 
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: ThemeMode.dark,
              child: Row(
                children: [
                  Icon(
                    Icons.dark_mode,
                    color: themeService.themeMode == ThemeMode.dark 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mode sombre',
                    style: TextStyle(
                      fontWeight: themeService.themeMode == ThemeMode.dark 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                      color: themeService.themeMode == ThemeMode.dark 
                          ? Theme.of(context).colorScheme.primary 
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}