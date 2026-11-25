#!/usr/bin/env bash
# Buduje paczkę RemoteAppTester na Linux (x64 i arm64) w kontenerach Docker, więc działa
# także na Windows (Git Bash). Biblioteka bazy jest natywna, dlatego budujemy osobno na
# każdą architekturę. Wynik:
#   build/release/RemoteAppTester-linux-<wersja>.tar.gz + .sha256
#
# Na serwerze: tar xzf RemoteAppTester-linux-<wersja>.tar.gz && cd RemoteAppTester-linux-<wersja> && sudo bash install.sh
#
# Opcje: --arch x64|arm64 (domyślnie obie).
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

arches=(x64 arm64)
if [ "${1:-}" = "--arch" ]; then arches=("$2"); fi

version=$(grep -o "hostVersion = '[^']*'" lib/version.dart | cut -d"'" -f2)
installer_version=$(grep -o '^HOST_VERSION="[^"]*"' deploy/linux/install.sh | cut -d'"' -f2)
if [ "$version" != "$installer_version" ]; then
  echo "Wersja programu ($version) różni się od HOST_VERSION w install.sh ($installer_version)." >&2
  exit 1
fi

name="RemoteAppTester-linux-$version"
out="build/release/$name"
rm -rf "$out" "build/release/$name.tar.gz" "build/release/$name.tar.gz.sha256"
mkdir -p "$out"
here=$(pwd -W 2>/dev/null || pwd)

for arch in "${arches[@]}"; do
  case "$arch" in
    x64) platform=linux/amd64 ;;
    arm64) platform=linux/arm64 ;;
    *) echo "Nieznana architektura: $arch" >&2; exit 1 ;;
  esac
  echo "==> Budowanie $arch ($platform)"
  # Źródła kopiujemy do kontenera: .dart_tool z Windows nie może się pomieszać z linuksowym.
  docker run --rm --platform "$platform" -v "$here:/src:ro" -v "$here/$out:/out" dart:stable bash -c "
    set -e
    mkdir /b && cd /src && tar --exclude=./.dart_tool --exclude=./build --exclude=./logs -cf - . | tar -xf - -C /b
    cd /b && dart pub get >/dev/null
    dart build cli -t bin/rt.dart -o /tmp/o >/tmp/log 2>&1 || { tail -30 /tmp/log; exit 1; }
    mkdir -p /out/$arch && cp -r /tmp/o/bundle/. /out/$arch/
  "
done

cp deploy/linux/install.sh deploy/linux/README.md "$out/"
sed -i 's/\r$//' "$out/install.sh"
(cd "$out" && find . -type f ! -name SHA256SUMS | LC_ALL=C sort | xargs sha256sum | sed 's/ \*/  /' > SHA256SUMS)

# Bity wykonywania ustawiamy w archiwum: system plików Windows ich nie przechowuje.
tar -C build/release --mode='u+rwX,go+rX,a+x' --owner=0 --group=0 -czf "build/release/$name.tar.gz" "$name"
(cd build/release && sha256sum "$name.tar.gz" | sed 's/ \*/  /' > "$name.tar.gz.sha256")

echo
ls -la "build/release/$name.tar.gz"
echo "Na serwerze: tar xzf $name.tar.gz && cd $name && sudo bash install.sh"
