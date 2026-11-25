# proto/

🌐 **English** · [Polski](README.pl.md)

The shared gRPC contract (`remote_tester.proto`, package `remotetester.v1`, service `HostAgent`): the
single source of truth for `host/` (server) and `android_app/` (client). Change the contract only
here, then regenerate the Dart code on both sides.

Authentication (HMAC/nonce/timestamp) is deliberately **not** part of the contract. It travels in
gRPC metadata; see the comment at the top of the `.proto` file. The rule: the phone sends only opaque
identifiers and choices from closed enums, never commands or paths.

## Requirements

- `protoc` (Protocol Buffers compiler) in `PATH`: https://github.com/protocolbuffers/protobuf/releases
- `dart pub global activate protoc_plugin` (`protoc-gen-dart` in `PATH`)

## Generating the Dart code

From the `proto/` folder:

```sh
protoc --dart_out=grpc:../host/lib/generated remote_tester.proto
protoc --dart_out=grpc:../android_app/lib/generated remote_tester.proto
```

The generated code is committed (so a checkout does not need `protoc`) and is identical on both
sides. Do not edit it by hand.

**Package versions:** `protoc-gen-dart` generates code for `protobuf ^6.0.0`, which needs this in
both `pubspec.yaml` files:

```yaml
dependencies:
  grpc: ^5.1.0       # not ^4.x: the older BuilderInfo API lacks methods the generated code uses
  protobuf: ^6.0.0
  fixnum: ^1.1.0     # Int64 type for int64 fields
```

A mismatch shows up as analysis errors in the generated file (`undefined_method: pPM/aE/aI`).
Check the versions in `pubspec.yaml` first, not the generated code.
