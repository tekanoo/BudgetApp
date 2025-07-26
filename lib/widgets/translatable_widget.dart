import 'package:flutter/material.dart';
import '../services/translation_service.dart';

/// Mixin pour faciliter l'utilisation des traductions dans les widgets
mixin TranslatableWidget<T extends StatefulWidget> on State<T> {
  /// Raccourci pour les traductions
  String tr(String key) => TranslationService.t(key);
  
  /// Force le rebuild lors du changement de langue
  void onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }
}

/// Widget de base avec support automatique des traductions
abstract class TranslatableStatefulWidget extends StatefulWidget {
  const TranslatableStatefulWidget({super.key});
}

abstract class TranslatableState<T extends TranslatableStatefulWidget> 
    extends State<T> with TranslatableWidget {
  
  @override
  void initState() {
    super.initState();
    // S'abonner aux changements de langue si nécessaire
  }
}