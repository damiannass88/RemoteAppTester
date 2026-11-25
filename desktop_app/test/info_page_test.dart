import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotetester_desktop/guide_content.dart';
import 'package:remotetester_desktop/i18n.dart';
import 'package:remotetester_desktop/ui/info_page.dart';

void main() {
  for (final (language, code) in [
    (AppLanguage.pl, 'pl'),
    (AppLanguage.en, 'en'),
    (AppLanguage.de, 'de'),
    (AppLanguage.cs, 'cs'),
  ]) {
    testWidgets('the guide renders in $code', (tester) async {
      UiSettings.language.value = language;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 30000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: InfoPage())));
      final guide = guides[code]!;
      expect(find.text(guide.intro), findsOneWidget);
      for (final section in guide.sections) {
        expect(find.text(section.title), findsOneWidget);
      }
      expect(find.text(guide.importantLabel), findsWidgets);
    });
  }

  test('all languages have the same structure and mention checking with an AI chat', () {
    final pl = guides['pl']!;
    for (final g in guides.values) {
      expect(g.sections.map((s) => s.id), pl.sections.map((s) => s.id));
      for (var i = 0; i < g.sections.length; i++) {
        expect(g.sections[i].items.length, pl.sections[i].items.length);
      }
      expect(g.intro, contains('Claude'));
    }
  });
}
