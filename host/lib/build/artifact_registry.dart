/// Mapowanie `build_id` -> lokalizacja i suma kontrolna zbudowanego artefaktu.
/// Wyłącznie w pamięci procesu (jak `ProjectDiscovery`) — telefon nigdy nie
/// zna ścieżki na dysku agenta, tylko `build_id` (docs/architektura-remote-build.md,
/// sekcja 4, punkt 5: "Po sukcesie liczy SHA-256 artefaktu i wysyła razem z
/// plikiem").
class BuiltArtifact {
  const BuiltArtifact({
    required this.filePath,
    required this.sha256Hex,
    required this.sizeBytes,
  });

  final String filePath;
  final String sha256Hex;
  final int sizeBytes;
}

class ArtifactRegistry {
  final Map<String, BuiltArtifact> _byBuildId = {};

  void register(String buildId, BuiltArtifact artifact) {
    _byBuildId[buildId] = artifact;
  }

  BuiltArtifact? operator [](String buildId) => _byBuildId[buildId];
}
