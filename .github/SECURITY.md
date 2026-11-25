# Security policy / Zgłaszanie problemów bezpieczeństwa

🌐 [English](#reporting-a-vulnerability) · [Polski](#zgłaszanie-po-polsku)

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's private reporting:
repository **Security** tab → **Report a vulnerability**.

Include the version (`rt version` or "About" in the app), the platform, and steps to reproduce.
**Never include** pairing QR codes or links, `pairing_secret`, `control_token`, TLS keys, Tailscale
auth keys or other secrets. If they were exposed, revoke the phone (Windows app: Phones → Revoke; Linux: `sudo rt rv <device_id>`) and
re-pair first.

This is a hobby project maintained in spare time: there is no guaranteed response time, but
reports are taken seriously. Only the latest released version receives fixes.

The threat model and security design are described in [docs/en/SECURITY.md](../docs/en/SECURITY.md).

## Zgłaszanie po polsku

Problemów bezpieczeństwa **nie zgłaszaj publicznie**. Użyj prywatnego zgłoszenia GitHuba:
zakładka **Security** w repozytorium → **Report a vulnerability**.

Podaj wersję (`rt version` albo „O programie” w aplikacji), system i kroki, które prowadzą do problemu.
**Nigdy** nie dołączaj kodów QR ani linków parowania, `pairing_secret`, `control_token`, kluczy TLS,
kluczy Tailscale ani innych sekretów. Jeśli wyciekły, najpierw odwołaj telefon (aplikacja Windows:
Telefony → Odwołaj; Linux: `sudo rt rv <device_id>`) i sparuj go ponownie.

To projekt hobbystyczny, rozwijany w wolnym czasie: nie ma gwarantowanego czasu odpowiedzi, ale
każde zgłoszenie jest traktowane poważnie. Poprawki dotyczą tylko najnowszej wydanej wersji.

Model zagrożeń i projekt zabezpieczeń: [docs/SECURITY.md](../docs/SECURITY.md).
