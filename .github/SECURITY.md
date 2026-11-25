# Security policy / Zgłaszanie problemów bezpieczeństwa

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's private reporting:
repository **Security** tab → **Report a vulnerability**.

Include the version (`rt version` or "About" in the app), the platform, and steps to reproduce.
**Never include** pairing QR codes or links, `pairing_secret`, `control_token`, TLS keys, Tailscale
auth keys or other secrets. If they were exposed, revoke the phone (Windows app: Phones → Revoke; Linux: `sudo rt rv <device_id>`) and
re-pair first.

This is a hobby project maintained in spare time: there is no guaranteed response time, but
reports are taken seriously. Only the latest released version receives fixes.

The threat model and security design are described in [docs/SECURITY.md](../docs/SECURITY.md) (PL).

## Zgłaszanie po polsku

Nie zakładaj publicznego zgłoszenia. Użyj zakładki **Security** → **Report a vulnerability**.
Podaj wersję, system i kroki. **Nigdy** nie dołączaj kodów QR, linków parowania, sekretów,
tokenów ani kluczy. Jeśli wyciekły, najpierw odwołaj telefon i sparuj go ponownie.
Poprawki dotyczą tylko najnowszej wersji.
