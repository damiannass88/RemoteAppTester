// This is a generated file - do not edit.
//
// Generated from remote_tester.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'remote_tester.pb.dart' as $0;

export 'remote_tester.pb.dart';

@$pb.GrpcServiceName('remotetester.v1.HostAgent')
class HostAgentClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  HostAgentClient(super.channel, {super.options, super.interceptors});

  /// Zdrowie/ping — lekki RPC do health-checku z telefonu.
  $grpc.ResponseFuture<$0.Pong> ping(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$ping, request, options: options);
  }

  /// Projekty skonfigurowane na hoście.
  $grpc.ResponseFuture<$0.ProjectList> listProjects(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listProjects, request, options: options);
  }

  /// Start builda — server-streaming statusu/logów do zlecającego urządzenia.
  $grpc.ResponseStream<$0.BuildEvent> startBuild(
    $0.BuildRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$startBuild, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Status ostatniego/aktywnego builda — używane przy reconnect, żeby klient
  /// nie zakładał, że trzeba zacząć od nowa po zerwaniu połączenia.
  $grpc.ResponseStream<$0.BuildEvent> getBuildStatus(
    $0.BuildId request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$getBuildStatus, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Transfer artefaktu w chunkach, wznawialny.
  $grpc.ResponseStream<$0.Chunk> downloadArtifact(
    $0.ArtifactRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$downloadArtifact, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Oszczędny transfer: różnica (delta, skompresowana) między instalką, którą
  /// telefon już ma (base_sha256), a nową. Pusty base_sha256 = cała instalka
  /// skompresowana. FAILED_PRECONDITION = host nie ma już tej bazy (telefon
  /// ponawia z pustym base_sha256).
  $grpc.ResponseStream<$0.Chunk> downloadDelta(
    $0.DeltaRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$downloadDelta, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Opcje projektu z telefonu (pilot): instalacja, uruchamianie, sygnał agenta,
  /// czy TEN telefon dostaje nowe wersje. Komend i „budowania z telefonu”
  /// telefon nie zmienia. Zwraca projekt po zmianie.
  $grpc.ResponseFuture<$0.Project> updateProjectOptions(
    $0.ProjectOptionsUpdate request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateProjectOptions, request, options: options);
  }

  /// Wymiana sekretu urządzenia: po parowaniu (kod z QR jest jednorazowy) i
  /// okresowo. Stary sekret działa do pierwszego żądania podpisanego nowym.
  $grpc.ResponseFuture<$0.SecretRotation> rotateSecret(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$rotateSecret, request, options: options);
  }

  /// Anulowanie aktywnego/kolejkowanego builda przez zlecające urządzenie.
  $grpc.ResponseFuture<$0.Ack> cancelBuild(
    $0.BuildId request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$cancelBuild, request, options: options);
  }

  /// Stały strumień dostaw: host wysyła nowe wersje aplikacji (zbudowane z
  /// dowolnego wyzwalacza) do urządzeń z `deliver.devices` w remoteapptester.yaml.
  /// Najpierw zaległa dostawa per projekt (gdy telefon był offline), potem
  /// nowe na bieżąco, a między nimi heartbeat — telefon po jego braku sam
  /// nawiązuje połączenie od nowa.
  $grpc.ResponseStream<$0.DeliveryEvent> watchDeliveries(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$watchDeliveries, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Telefon potwierdza obsłużenie dostawy (zainstalowana albo odrzucona) —
  /// host przestaje ją wysyłać przy kolejnych połączeniach.
  $grpc.ResponseFuture<$0.Ack> ackDelivery(
    $0.BuildId request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$ackDelivery, request, options: options);
  }

  /// Foldery w katalogu projektów hosta, które nie są jeszcze projektami — same
  /// nazwy, bez ścieżek. Pusta lista, gdy host nie pozwala telefonom dodawać projektów.
  $grpc.ResponseFuture<$0.FolderList> listAvailableFolders(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listAvailableFolders, request, options: options);
  }

  /// Nowy projekt z telefonu: WYŁĄCZNIE w katalogu projektów hosta, po samej
  /// nazwie folderu (bez ścieżek). Komendy wpisuje host z własnych szablonów.
  $grpc.ResponseFuture<$0.Project> createProject(
    $0.CreateProjectRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createProject, request, options: options);
  }

  /// Podgląd aplikacji web: host uruchamia serwer deweloperski projektu komendą
  /// z WŁASNEJ bazy (telefon wskazuje tylko project_id) i udostępnia go w sieci
  /// Tailscale przez proxy z tokenem. Strumień: stan, log serwera, sygnał
  /// „odśwież” (np. po zmianach agenta) — do zamknięcia przez telefon. Zamknięcie
  /// strumienia nie zatrzymuje podglądu (zatrzymuje StopPreview albo bezczynność).
  $grpc.ResponseStream<$0.PreviewEvent> startPreview(
    $0.PreviewRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$startPreview, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseFuture<$0.Ack> stopPreview(
    $0.PreviewRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$stopPreview, request, options: options);
  }

  /// Zgłoszenie problemu z podglądu (notatka, adres strony, konsola JS) — host
  /// dopisuje je do pliku w folderze projektu, skąd czyta je agent AI.
  $grpc.ResponseFuture<$0.Ack> reportPreviewIssue(
    $0.PreviewIssue request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reportPreviewIssue, request, options: options);
  }

  // method descriptors

  static final _$ping = $grpc.ClientMethod<$0.Empty, $0.Pong>(
      '/remotetester.v1.HostAgent/Ping',
      ($0.Empty value) => value.writeToBuffer(),
      $0.Pong.fromBuffer);
  static final _$listProjects = $grpc.ClientMethod<$0.Empty, $0.ProjectList>(
      '/remotetester.v1.HostAgent/ListProjects',
      ($0.Empty value) => value.writeToBuffer(),
      $0.ProjectList.fromBuffer);
  static final _$startBuild =
      $grpc.ClientMethod<$0.BuildRequest, $0.BuildEvent>(
          '/remotetester.v1.HostAgent/StartBuild',
          ($0.BuildRequest value) => value.writeToBuffer(),
          $0.BuildEvent.fromBuffer);
  static final _$getBuildStatus = $grpc.ClientMethod<$0.BuildId, $0.BuildEvent>(
      '/remotetester.v1.HostAgent/GetBuildStatus',
      ($0.BuildId value) => value.writeToBuffer(),
      $0.BuildEvent.fromBuffer);
  static final _$downloadArtifact =
      $grpc.ClientMethod<$0.ArtifactRequest, $0.Chunk>(
          '/remotetester.v1.HostAgent/DownloadArtifact',
          ($0.ArtifactRequest value) => value.writeToBuffer(),
          $0.Chunk.fromBuffer);
  static final _$downloadDelta = $grpc.ClientMethod<$0.DeltaRequest, $0.Chunk>(
      '/remotetester.v1.HostAgent/DownloadDelta',
      ($0.DeltaRequest value) => value.writeToBuffer(),
      $0.Chunk.fromBuffer);
  static final _$updateProjectOptions =
      $grpc.ClientMethod<$0.ProjectOptionsUpdate, $0.Project>(
          '/remotetester.v1.HostAgent/UpdateProjectOptions',
          ($0.ProjectOptionsUpdate value) => value.writeToBuffer(),
          $0.Project.fromBuffer);
  static final _$rotateSecret = $grpc.ClientMethod<$0.Empty, $0.SecretRotation>(
      '/remotetester.v1.HostAgent/RotateSecret',
      ($0.Empty value) => value.writeToBuffer(),
      $0.SecretRotation.fromBuffer);
  static final _$cancelBuild = $grpc.ClientMethod<$0.BuildId, $0.Ack>(
      '/remotetester.v1.HostAgent/CancelBuild',
      ($0.BuildId value) => value.writeToBuffer(),
      $0.Ack.fromBuffer);
  static final _$watchDeliveries =
      $grpc.ClientMethod<$0.Empty, $0.DeliveryEvent>(
          '/remotetester.v1.HostAgent/WatchDeliveries',
          ($0.Empty value) => value.writeToBuffer(),
          $0.DeliveryEvent.fromBuffer);
  static final _$ackDelivery = $grpc.ClientMethod<$0.BuildId, $0.Ack>(
      '/remotetester.v1.HostAgent/AckDelivery',
      ($0.BuildId value) => value.writeToBuffer(),
      $0.Ack.fromBuffer);
  static final _$listAvailableFolders =
      $grpc.ClientMethod<$0.Empty, $0.FolderList>(
          '/remotetester.v1.HostAgent/ListAvailableFolders',
          ($0.Empty value) => value.writeToBuffer(),
          $0.FolderList.fromBuffer);
  static final _$createProject =
      $grpc.ClientMethod<$0.CreateProjectRequest, $0.Project>(
          '/remotetester.v1.HostAgent/CreateProject',
          ($0.CreateProjectRequest value) => value.writeToBuffer(),
          $0.Project.fromBuffer);
  static final _$startPreview =
      $grpc.ClientMethod<$0.PreviewRequest, $0.PreviewEvent>(
          '/remotetester.v1.HostAgent/StartPreview',
          ($0.PreviewRequest value) => value.writeToBuffer(),
          $0.PreviewEvent.fromBuffer);
  static final _$stopPreview = $grpc.ClientMethod<$0.PreviewRequest, $0.Ack>(
      '/remotetester.v1.HostAgent/StopPreview',
      ($0.PreviewRequest value) => value.writeToBuffer(),
      $0.Ack.fromBuffer);
  static final _$reportPreviewIssue =
      $grpc.ClientMethod<$0.PreviewIssue, $0.Ack>(
          '/remotetester.v1.HostAgent/ReportPreviewIssue',
          ($0.PreviewIssue value) => value.writeToBuffer(),
          $0.Ack.fromBuffer);
}

@$pb.GrpcServiceName('remotetester.v1.HostAgent')
abstract class HostAgentServiceBase extends $grpc.Service {
  $core.String get $name => 'remotetester.v1.HostAgent';

  HostAgentServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.Pong>(
        'Ping',
        ping_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.Pong value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.ProjectList>(
        'ListProjects',
        listProjects_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.ProjectList value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BuildRequest, $0.BuildEvent>(
        'StartBuild',
        startBuild_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.BuildRequest.fromBuffer(value),
        ($0.BuildEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BuildId, $0.BuildEvent>(
        'GetBuildStatus',
        getBuildStatus_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.BuildId.fromBuffer(value),
        ($0.BuildEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ArtifactRequest, $0.Chunk>(
        'DownloadArtifact',
        downloadArtifact_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.ArtifactRequest.fromBuffer(value),
        ($0.Chunk value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeltaRequest, $0.Chunk>(
        'DownloadDelta',
        downloadDelta_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.DeltaRequest.fromBuffer(value),
        ($0.Chunk value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ProjectOptionsUpdate, $0.Project>(
        'UpdateProjectOptions',
        updateProjectOptions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ProjectOptionsUpdate.fromBuffer(value),
        ($0.Project value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.SecretRotation>(
        'RotateSecret',
        rotateSecret_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.SecretRotation value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BuildId, $0.Ack>(
        'CancelBuild',
        cancelBuild_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BuildId.fromBuffer(value),
        ($0.Ack value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.DeliveryEvent>(
        'WatchDeliveries',
        watchDeliveries_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.DeliveryEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BuildId, $0.Ack>(
        'AckDelivery',
        ackDelivery_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BuildId.fromBuffer(value),
        ($0.Ack value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.FolderList>(
        'ListAvailableFolders',
        listAvailableFolders_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.FolderList value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateProjectRequest, $0.Project>(
        'CreateProject',
        createProject_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateProjectRequest.fromBuffer(value),
        ($0.Project value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PreviewRequest, $0.PreviewEvent>(
        'StartPreview',
        startPreview_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.PreviewRequest.fromBuffer(value),
        ($0.PreviewEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PreviewRequest, $0.Ack>(
        'StopPreview',
        stopPreview_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PreviewRequest.fromBuffer(value),
        ($0.Ack value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PreviewIssue, $0.Ack>(
        'ReportPreviewIssue',
        reportPreviewIssue_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PreviewIssue.fromBuffer(value),
        ($0.Ack value) => value.writeToBuffer()));
  }

  $async.Future<$0.Pong> ping_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return ping($call, await $request);
  }

  $async.Future<$0.Pong> ping($grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.ProjectList> listProjects_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return listProjects($call, await $request);
  }

  $async.Future<$0.ProjectList> listProjects(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Stream<$0.BuildEvent> startBuild_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.BuildRequest> $request) async* {
    yield* startBuild($call, await $request);
  }

  $async.Stream<$0.BuildEvent> startBuild(
      $grpc.ServiceCall call, $0.BuildRequest request);

  $async.Stream<$0.BuildEvent> getBuildStatus_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.BuildId> $request) async* {
    yield* getBuildStatus($call, await $request);
  }

  $async.Stream<$0.BuildEvent> getBuildStatus(
      $grpc.ServiceCall call, $0.BuildId request);

  $async.Stream<$0.Chunk> downloadArtifact_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ArtifactRequest> $request) async* {
    yield* downloadArtifact($call, await $request);
  }

  $async.Stream<$0.Chunk> downloadArtifact(
      $grpc.ServiceCall call, $0.ArtifactRequest request);

  $async.Stream<$0.Chunk> downloadDelta_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.DeltaRequest> $request) async* {
    yield* downloadDelta($call, await $request);
  }

  $async.Stream<$0.Chunk> downloadDelta(
      $grpc.ServiceCall call, $0.DeltaRequest request);

  $async.Future<$0.Project> updateProjectOptions_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ProjectOptionsUpdate> $request) async {
    return updateProjectOptions($call, await $request);
  }

  $async.Future<$0.Project> updateProjectOptions(
      $grpc.ServiceCall call, $0.ProjectOptionsUpdate request);

  $async.Future<$0.SecretRotation> rotateSecret_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return rotateSecret($call, await $request);
  }

  $async.Future<$0.SecretRotation> rotateSecret(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Ack> cancelBuild_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.BuildId> $request) async {
    return cancelBuild($call, await $request);
  }

  $async.Future<$0.Ack> cancelBuild($grpc.ServiceCall call, $0.BuildId request);

  $async.Stream<$0.DeliveryEvent> watchDeliveries_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async* {
    yield* watchDeliveries($call, await $request);
  }

  $async.Stream<$0.DeliveryEvent> watchDeliveries(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Ack> ackDelivery_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.BuildId> $request) async {
    return ackDelivery($call, await $request);
  }

  $async.Future<$0.Ack> ackDelivery($grpc.ServiceCall call, $0.BuildId request);

  $async.Future<$0.FolderList> listAvailableFolders_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return listAvailableFolders($call, await $request);
  }

  $async.Future<$0.FolderList> listAvailableFolders(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Project> createProject_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateProjectRequest> $request) async {
    return createProject($call, await $request);
  }

  $async.Future<$0.Project> createProject(
      $grpc.ServiceCall call, $0.CreateProjectRequest request);

  $async.Stream<$0.PreviewEvent> startPreview_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PreviewRequest> $request) async* {
    yield* startPreview($call, await $request);
  }

  $async.Stream<$0.PreviewEvent> startPreview(
      $grpc.ServiceCall call, $0.PreviewRequest request);

  $async.Future<$0.Ack> stopPreview_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PreviewRequest> $request) async {
    return stopPreview($call, await $request);
  }

  $async.Future<$0.Ack> stopPreview(
      $grpc.ServiceCall call, $0.PreviewRequest request);

  $async.Future<$0.Ack> reportPreviewIssue_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PreviewIssue> $request) async {
    return reportPreviewIssue($call, await $request);
  }

  $async.Future<$0.Ack> reportPreviewIssue(
      $grpc.ServiceCall call, $0.PreviewIssue request);
}
