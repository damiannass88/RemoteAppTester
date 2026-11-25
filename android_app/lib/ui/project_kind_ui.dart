import 'package:flutter/material.dart';

import '../generated/remote_tester.pbgrpc.dart';
import '../i18n.dart';

/// Ikona i opis typu projektu.
IconData projectKindIcon(Project project) => switch (project.kind) {
      ProjectKind.FLUTTER || ProjectKind.ANDROID_GRADLE => Icons.phone_android,
      ProjectKind.REACT_NATIVE || ProjectKind.CAPACITOR => Icons.web_asset,
      _ => Icons.folder,
    };

/// Status projektu dla pilota: trwający build, ostatni wynik, wariant.
String projectSubtitle(Project project) {
  if (project.specError.isNotEmpty) return project.specError;
  final parts = <String>[if (project.changesPending) tr('nowe zmiany'), projectKindLabel(project)];
  if (project.building) {
    parts.add(project.progressPercent > 0 ? tr('buduje… {0}%', [project.progressPercent]) : tr('w kolejce'));
  } else if (project.lastPhase != BuildPhase.BUILD_PHASE_UNSPECIFIED) {
    final label = switch (project.lastPhase) {
      BuildPhase.DONE => 'gotowe',
      BuildPhase.FAILED => tr('błąd'),
      BuildPhase.CANCELLED => 'anulowano',
      _ => project.lastPhase.name,
    };
    parts.add('$label ${timeAgo(project.lastBuildUnixMs.toInt())}');
  }
  if (project.defaultProfile.isNotEmpty) parts.add(project.defaultProfile);
  if (!project.phoneTriggerAllowed) parts.add(tr('budowanie z telefonu wyłączone'));
  return parts.join(' · ');
}

String timeAgo(int unixMs) {
  if (unixMs <= 0) return '';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(unixMs));
  if (d.inMinutes < 1) return tr('przed chwilą');
  if (d.inHours < 1) return tr('{0} min temu', [d.inMinutes]);
  if (d.inDays < 1) return tr('{0} h temu', [d.inHours]);
  return tr('{0} d temu', [d.inDays]);
}

String projectKindLabel(Project project) {
  return switch (project.kind) {
    ProjectKind.FLUTTER => tr('Flutter'),
    ProjectKind.ANDROID_GRADLE => tr('Android'),
    ProjectKind.REACT_NATIVE => tr('React Native'),
    ProjectKind.CAPACITOR => tr('Capacitor'),
    _ => tr('Folder'),
  };
}
