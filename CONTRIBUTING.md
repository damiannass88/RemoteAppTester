# Contributing / Współpraca

Thanks for helping! Most docs and code comments are in Polish. Issues and pull requests in
English or Polish are both fine.

## Ground rules

- **Security first.** Any new build method or change to the phone ↔ host contract needs a
  security review against [docs/SECURITY.md](docs/SECURITY.md) ("Checklist"). The phone must never
  be able to send shell commands or file paths. Build commands come only from the encrypted
  database, after the user has approved them.
- **Never commit secrets:** keystores, `key.properties`, `host-config.yaml`, pairing data, tokens.
  `.gitignore` covers the usual files. Check `git status` anyway.
- **Keep it simple for non-technical users.** UI texts are short, concrete and translated.

## Development

| Part | Folder | Run tests |
|---|---|---|
| Host core + `rt` CLI | `host/` | `cd host && dart test` |
| Windows app | `desktop_app/` | `cd desktop_app && flutter test` |
| Android app | `android_app/` | `cd android_app && flutter test` |

- **Translations:** UI texts are written in Polish via `tr('…')`. Add EN/DE/CS to
  `tool/i18n/translations.py`, then run `python tool/i18n/generate.py`. The `i18n_test` fails on missing keys.
- **gRPC contract:** edit only `proto/remote_tester.proto`, then regenerate both sides ([proto/README.md](proto/README.md)).
- **Version:** the same version lives in `host/lib/version.dart`, `host/deploy/windows/install.ps1`,
  `host/deploy/linux/install.sh`, both `pubspec.yaml` files (`X.Y.Z+N`, N = X·10000+Y·100+Z) and
  `android_app/lib/app_version.dart`. The release scripts refuse to build if they differ.
- **Release packages:** `host/tool/build_release.ps1 -WithAndroid` (Windows + APK),
  `host/tool/build_release.sh` (Linux x64/arm64 via Docker).

## Pull requests

Small, focused PRs with a short description of *why*. Include tests for behaviour changes,
especially anything that starts processes, touches pairing/authentication or installs packages.
By contributing you agree that your contribution is licensed under the project's [LICENSE](LICENSE).
