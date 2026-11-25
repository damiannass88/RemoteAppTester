# Współpraca

🌐 [English](CONTRIBUTING.md) · **Polski**

Dzięki za pomoc! Komentarze w kodzie i notatki projektowe są po polsku, a dokumentacja dla
użytkowników jest po angielsku i po polsku. Zgłoszenia i pull requesty możesz pisać w obu językach.

## Podstawowe zasady

- **Najpierw bezpieczeństwo.** Każda nowa metoda budowania albo zmiana kontraktu telefon ↔ host
  wymaga przeglądu bezpieczeństwa według [docs/SECURITY.md](docs/SECURITY.md) („Checklist”). Telefon
  nigdy nie może wysłać polecenia powłoki ani ścieżki pliku. Komendy budowania pochodzą wyłącznie z
  zaszyfrowanej bazy, po zatwierdzeniu przez użytkownika.
- **Nigdy nie commituj sekretów:** magazynów kluczy, `key.properties`, `host-config.yaml`, danych
  parowania, tokenów. `.gitignore` obejmuje typowe pliki, ale i tak sprawdź `git status`.
- **Prosto dla osób nietechnicznych.** Teksty w aplikacjach są krótkie, konkretne i przetłumaczone.

## Rozwój

| Część | Folder | Testy |
|---|---|---|
| Rdzeń hosta + polecenie `rt` | `host/` | `cd host && dart test` |
| Aplikacja Windows | `desktop_app/` | `cd desktop_app && flutter test` |
| Aplikacja Android | `android_app/` | `cd android_app && flutter test` |

- **Tłumaczenia:** teksty interfejsu pisze się po polsku przez `tr('…')`. Wersje EN/DE/CS dodaj w
  `tool/i18n/translations.py`, potem uruchom `python tool/i18n/generate.py`. `i18n_test` nie przejdzie,
  jeśli brakuje klucza.
- **Kontrakt gRPC:** zmieniaj tylko `proto/remote_tester.proto`, potem wygeneruj kod po obu stronach
  ([proto/README.pl.md](proto/README.pl.md)).
- **Wersja:** ta sama wersja jest w `host/lib/version.dart`, `host/deploy/windows/install.ps1`,
  `host/deploy/linux/install.sh`, obu plikach `pubspec.yaml` (`X.Y.Z+N`, N = X·10000+Y·100+Z) i
  `android_app/lib/app_version.dart`. Skrypty wydania odmówią budowania, jeśli się różnią.
- **Dokumentacja:** zmieniając opis dla użytkowników, popraw obie wersje językowe (`docs/*.md` i
  `docs/en/*.md`, `README.md` i `README.pl.md`).
- **Paczki wydania:** `host/tool/build_release.ps1 -WithAndroid` (Windows + APK),
  `host/tool/build_release.sh` (Linux x64/arm64 przez Docker).

## Pull requesty

Małe, skupione PR-y z krótkim opisem *dlaczego*. Dołącz testy do zmian zachowania, zwłaszcza
wszystkiego, co uruchamia procesy, dotyka parowania i uwierzytelniania albo instaluje pakiety.
Wysyłając zmianę, zgadzasz się, że jest objęta [licencją](LICENSE) projektu.
