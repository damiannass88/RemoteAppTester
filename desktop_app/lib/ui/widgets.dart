import 'package:flutter/material.dart';

import '../i18n.dart';

void showError(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      icon: const Icon(Icons.error_outline, color: Colors.red),
      title: Text(tr('Coś poszło nie tak')),
      content: SingleChildScrollView(child: SelectableText(message)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 5)));
}

Future<bool> confirm(BuildContext context, String title, String message, {String? action}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Anuluj'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action ?? tr('Tak'))),
      ],
    ),
  );
  return result ?? false;
}

/// Długa operacja z oknem postępu; `null` gdy rzuciła wyjątek (pokazany użytkownikowi).
Future<T?> runWithProgress<T>(BuildContext context, String message, Future<T> Function() action) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(children: [
        const CircularProgressIndicator(),
        const SizedBox(width: 20),
        Expanded(child: Text(message)),
      ]),
    ),
  );
  Object? error;
  T? result;
  try {
    result = await action();
  } on Object catch (e) {
    error = e;
  }
  if (context.mounted) Navigator.pop(context);
  if (error != null && context.mounted) showError(context, error.toString());
  return result;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
