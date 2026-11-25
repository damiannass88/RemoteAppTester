import 'package:flutter/material.dart';

import '../guide_content.dart';
import '../i18n.dart';
import 'guide_icons.dart';

/// Przewodnik: bezpieczne korzystanie, ryzyka, sandbox, praca z agentami AI, publikacja.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final guide = guides[UiSettings.code] ?? guides['en']!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(tr('Informacje'), style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.smart_toy_outlined, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(child: Text(guide.intro, style: TextStyle(color: theme.colorScheme.onPrimaryContainer))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        for (final section in guide.sections) GuideSectionCard(guide: guide, section: section),
      ],
    );
  }
}
