import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotetester/i18n.dart';

import 'package:remotetester/main.dart';

void main() {
  // Teksty w asercjach są po polsku.
  setUpAll(() => I18n.language.value = AppLanguage.pl);

  testWidgets('Shows a loading indicator while checking saved settings', (tester) async {
    await tester.pumpWidget(const RemoteAppTesterApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
