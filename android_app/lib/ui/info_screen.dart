import 'package:flutter/material.dart';

import '../guide_content.dart';
import '../i18n.dart';
import 'guide_icons.dart';

/// Przewodnik: bezpieczne korzystanie, ryzyka, sandbox, praca z agentami AI, publikacja.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final guide = guides[I18n.code] ?? guides['en']!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Informacje'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(guide.intro, style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
            ),
          ),
          const SizedBox(height: 8),
          for (final section in guide.sections) GuideSectionCard(guide: guide, section: section),
        ],
      ),
    );
  }
}
