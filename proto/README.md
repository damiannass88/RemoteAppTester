# proto/

Wspólny kontrakt gRPC (`remote_tester.proto`, pakiet `remotetester.v1`, usługa `HostAgent`) —
źródło prawdy dla `host/` (serwer) i `android_app/` (klient). Zmiana kontraktu = zmiana tylko
tutaj, potem regeneracja kodu Dart po obu stronach.

Uwierzytelnienie (HMAC/nonce/timestamp) celowo **nie** jest częścią kontraktu — idzie w
metadanych gRPC, patrz komentarz na górze `.proto`. Zasada: telefon wysyła wyłącznie
nieprzezroczyste identyfikatory i wybory z zamkniętych enumów, nigdy polecenia ani ścieżki.

## Wymagania

- `protoc` (Protocol Buffers compiler) w `PATH` — https://github.com/protocolbuffers/protobuf/releases
- `dart pub global activate protoc_plugin` (`protoc-gen-dart` w `PATH`)

## Generowanie kodu Dart

Z katalogu `proto/`:

```sh
protoc --dart_out=grpc:../host/lib/generated remote_tester.proto
protoc --dart_out=grpc:../android_app/lib/generated remote_tester.proto
```

Wygenerowany kod jest commitowany (brak zależności od `protoc` przy checkout) i identyczny
po obu stronach — nie edytować ręcznie.

**Wersje pakietów:** `protoc-gen-dart` generuje kod pod `protobuf ^6.0.0`, co wymaga w obu
`pubspec.yaml`:

```yaml
dependencies:
  grpc: ^5.1.0       # nie ^4.x — starsze API BuilderInfo nie ma metod używanych przez wygenerowany kod
  protobuf: ^6.0.0
  fixnum: ^1.1.0     # typ Int64 dla pól int64
```

Niedopasowanie objawia się błędami analizy w wygenerowanym pliku (`undefined_method:
pPM/aE/aI`) — wtedy najpierw sprawdzić wersje w `pubspec.yaml`, nie sam wygenerowany kod.
