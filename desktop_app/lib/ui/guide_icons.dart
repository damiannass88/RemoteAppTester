import 'package:flutter/material.dart';

import '../guide_content.dart';

IconData guideIcon(String sectionId) => switch (sectionId) {
      'start' => Icons.rocket_launch_outlined,
      'security' => Icons.shield_outlined,
      'risks' => Icons.warning_amber_rounded,
      'agents' => Icons.smart_toy_outlined,
      'sandbox' => Icons.inventory_2_outlined,
      'phone' => Icons.smartphone,
      'publish' => Icons.storefront_outlined,
      'decisions' => Icons.checklist,
      _ => Icons.info_outline,
    };

/// Sekcja przewodnika: rozwijane pytania z odpowiedziami w punktach.
class GuideSectionCard extends StatelessWidget {
  const GuideSectionCard({super.key, required this.guide, required this.section});
  final Guide guide;
  final GuideSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(guideIcon(section.id), color: theme.colorScheme.primary),
            title: Text(section.title, style: theme.textTheme.titleMedium),
          ),
          for (final item in section.items)
            ExpansionTile(
              shape: const Border(),
              initiallyExpanded: item.important,
              title: Text(item.question),
              subtitle: item.important || item.advanced
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 6, children: [
                        if (item.important) _Tag(guide.importantLabel, Colors.orange),
                        if (item.advanced) _Tag(guide.advancedLabel, Colors.blueGrey),
                      ]),
                    )
                  : null,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [SelectableText(item.answer)],
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}
