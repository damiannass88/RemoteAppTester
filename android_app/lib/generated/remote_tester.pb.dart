// This is a generated file - do not edit.
//
// Generated from remote_tester.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'remote_tester.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'remote_tester.pbenum.dart';

class FolderList extends $pb.GeneratedMessage {
  factory FolderList({
    $core.Iterable<AvailableFolder>? folders,
    $core.bool? addingAllowed,
  }) {
    final result = create();
    if (folders != null) result.folders.addAll(folders);
    if (addingAllowed != null) result.addingAllowed = addingAllowed;
    return result;
  }

  FolderList._();

  factory FolderList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FolderList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FolderList',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..pPM<AvailableFolder>(1, _omitFieldNames ? '' : 'folders',
        subBuilder: AvailableFolder.create)
    ..aOB(2, _omitFieldNames ? '' : 'addingAllowed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FolderList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FolderList copyWith(void Function(FolderList) updates) =>
      super.copyWith((message) => updates(message as FolderList)) as FolderList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FolderList create() => FolderList._();
  @$core.override
  FolderList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FolderList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FolderList>(create);
  static FolderList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AvailableFolder> get folders => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get addingAllowed => $_getBF(1);
  @$pb.TagNumber(2)
  set addingAllowed($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAddingAllowed() => $_has(1);
  @$pb.TagNumber(2)
  void clearAddingAllowed() => $_clearField(2);
}

class AvailableFolder extends $pb.GeneratedMessage {
  factory AvailableFolder({
    $core.String? name,
    ProjectKind? kind,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (kind != null) result.kind = kind;
    return result;
  }

  AvailableFolder._();

  factory AvailableFolder.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AvailableFolder.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AvailableFolder',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aE<ProjectKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: ProjectKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableFolder clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableFolder copyWith(void Function(AvailableFolder) updates) =>
      super.copyWith((message) => updates(message as AvailableFolder))
          as AvailableFolder;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AvailableFolder create() => AvailableFolder._();
  @$core.override
  AvailableFolder createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AvailableFolder getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AvailableFolder>(create);
  static AvailableFolder? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  ProjectKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(ProjectKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);
}

class CreateProjectRequest extends $pb.GeneratedMessage {
  factory CreateProjectRequest({
    $core.String? folderName,
    ProjectTemplate? template,
  }) {
    final result = create();
    if (folderName != null) result.folderName = folderName;
    if (template != null) result.template = template;
    return result;
  }

  CreateProjectRequest._();

  factory CreateProjectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateProjectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateProjectRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'folderName')
    ..aE<ProjectTemplate>(2, _omitFieldNames ? '' : 'template',
        enumValues: ProjectTemplate.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateProjectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateProjectRequest copyWith(void Function(CreateProjectRequest) updates) =>
      super.copyWith((message) => updates(message as CreateProjectRequest))
          as CreateProjectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateProjectRequest create() => CreateProjectRequest._();
  @$core.override
  CreateProjectRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateProjectRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateProjectRequest>(create);
  static CreateProjectRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folderName => $_getSZ(0);
  @$pb.TagNumber(1)
  set folderName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolderName() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolderName() => $_clearField(1);

  @$pb.TagNumber(2)
  ProjectTemplate get template => $_getN(1);
  @$pb.TagNumber(2)
  set template(ProjectTemplate value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTemplate() => $_has(1);
  @$pb.TagNumber(2)
  void clearTemplate() => $_clearField(2);
}

class Empty extends $pb.GeneratedMessage {
  factory Empty() => create();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Empty create() => Empty._();
  @$core.override
  Empty createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Empty>(create);
  static Empty? _defaultInstance;
}

class Pong extends $pb.GeneratedMessage {
  factory Pong({
    $fixnum.Int64? serverTimeUnixMs,
    $core.String? hostVersion,
  }) {
    final result = create();
    if (serverTimeUnixMs != null) result.serverTimeUnixMs = serverTimeUnixMs;
    if (hostVersion != null) result.hostVersion = hostVersion;
    return result;
  }

  Pong._();

  factory Pong.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Pong.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Pong',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'serverTimeUnixMs')
    ..aOS(2, _omitFieldNames ? '' : 'hostVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pong clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pong copyWith(void Function(Pong) updates) =>
      super.copyWith((message) => updates(message as Pong)) as Pong;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Pong create() => Pong._();
  @$core.override
  Pong createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Pong getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Pong>(create);
  static Pong? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get serverTimeUnixMs => $_getI64(0);
  @$pb.TagNumber(1)
  set serverTimeUnixMs($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerTimeUnixMs() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerTimeUnixMs() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get hostVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set hostVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHostVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearHostVersion() => $_clearField(2);
}

class Project extends $pb.GeneratedMessage {
  factory Project({
    $core.String? projectId,
    $core.String? displayName,
    ProjectKind? kind,
    $core.bool? installableOnPhone,
    $core.Iterable<$core.String>? profiles,
    $core.String? defaultProfile,
    $core.String? specError,
    $core.bool? phoneTriggerAllowed,
    $core.bool? launchAfterInstall,
    $core.bool? building,
    BuildPhase? lastPhase,
    $fixnum.Int64? lastBuildUnixMs,
    $core.String? activeBuildId,
    $core.String? lastArtifactBuildId,
    $core.int? progressPercent,
    $core.bool? changesPending,
    $core.String? agentNote,
    $fixnum.Int64? agentNoteUnixMs,
    $core.bool? agentBuildAllowed,
    InstallMode? installMode,
    $core.bool? deliversToThisPhone,
    $core.bool? agentPushAllowed,
    $core.bool? previewAvailable,
    $core.String? previewKind,
    $core.bool? previewRunning,
  }) {
    final result = create();
    if (projectId != null) result.projectId = projectId;
    if (displayName != null) result.displayName = displayName;
    if (kind != null) result.kind = kind;
    if (installableOnPhone != null)
      result.installableOnPhone = installableOnPhone;
    if (profiles != null) result.profiles.addAll(profiles);
    if (defaultProfile != null) result.defaultProfile = defaultProfile;
    if (specError != null) result.specError = specError;
    if (phoneTriggerAllowed != null)
      result.phoneTriggerAllowed = phoneTriggerAllowed;
    if (launchAfterInstall != null)
      result.launchAfterInstall = launchAfterInstall;
    if (building != null) result.building = building;
    if (lastPhase != null) result.lastPhase = lastPhase;
    if (lastBuildUnixMs != null) result.lastBuildUnixMs = lastBuildUnixMs;
    if (activeBuildId != null) result.activeBuildId = activeBuildId;
    if (lastArtifactBuildId != null)
      result.lastArtifactBuildId = lastArtifactBuildId;
    if (progressPercent != null) result.progressPercent = progressPercent;
    if (changesPending != null) result.changesPending = changesPending;
    if (agentNote != null) result.agentNote = agentNote;
    if (agentNoteUnixMs != null) result.agentNoteUnixMs = agentNoteUnixMs;
    if (agentBuildAllowed != null) result.agentBuildAllowed = agentBuildAllowed;
    if (installMode != null) result.installMode = installMode;
    if (deliversToThisPhone != null)
      result.deliversToThisPhone = deliversToThisPhone;
    if (agentPushAllowed != null) result.agentPushAllowed = agentPushAllowed;
    if (previewAvailable != null) result.previewAvailable = previewAvailable;
    if (previewKind != null) result.previewKind = previewKind;
    if (previewRunning != null) result.previewRunning = previewRunning;
    return result;
  }

  Project._();

  factory Project.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Project.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Project',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'projectId')
    ..aOS(2, _omitFieldNames ? '' : 'displayName')
    ..aE<ProjectKind>(3, _omitFieldNames ? '' : 'kind',
        enumValues: ProjectKind.values)
    ..aOB(4, _omitFieldNames ? '' : 'installableOnPhone')
    ..pPS(5, _omitFieldNames ? '' : 'profiles')
    ..aOS(6, _omitFieldNames ? '' : 'defaultProfile')
    ..aOS(7, _omitFieldNames ? '' : 'specError')
    ..aOB(8, _omitFieldNames ? '' : 'phoneTriggerAllowed')
    ..aOB(9, _omitFieldNames ? '' : 'launchAfterInstall')
    ..aOB(10, _omitFieldNames ? '' : 'building')
    ..aE<BuildPhase>(11, _omitFieldNames ? '' : 'lastPhase',
        enumValues: BuildPhase.values)
    ..aInt64(12, _omitFieldNames ? '' : 'lastBuildUnixMs')
    ..aOS(13, _omitFieldNames ? '' : 'activeBuildId')
    ..aOS(14, _omitFieldNames ? '' : 'lastArtifactBuildId')
    ..aI(15, _omitFieldNames ? '' : 'progressPercent')
    ..aOB(16, _omitFieldNames ? '' : 'changesPending')
    ..aOS(17, _omitFieldNames ? '' : 'agentNote')
    ..aInt64(18, _omitFieldNames ? '' : 'agentNoteUnixMs')
    ..aOB(19, _omitFieldNames ? '' : 'agentBuildAllowed')
    ..aE<InstallMode>(20, _omitFieldNames ? '' : 'installMode',
        enumValues: InstallMode.values)
    ..aOB(21, _omitFieldNames ? '' : 'deliversToThisPhone')
    ..aOB(22, _omitFieldNames ? '' : 'agentPushAllowed')
    ..aOB(23, _omitFieldNames ? '' : 'previewAvailable')
    ..aOS(24, _omitFieldNames ? '' : 'previewKind')
    ..aOB(25, _omitFieldNames ? '' : 'previewRunning')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Project clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Project copyWith(void Function(Project) updates) =>
      super.copyWith((message) => updates(message as Project)) as Project;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Project create() => Project._();
  @$core.override
  Project createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Project getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Project>(create);
  static Project? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get projectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set projectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get displayName => $_getSZ(1);
  @$pb.TagNumber(2)
  set displayName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplayName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplayName() => $_clearField(2);

  @$pb.TagNumber(3)
  ProjectKind get kind => $_getN(2);
  @$pb.TagNumber(3)
  set kind(ProjectKind value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get installableOnPhone => $_getBF(3);
  @$pb.TagNumber(4)
  set installableOnPhone($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInstallableOnPhone() => $_has(3);
  @$pb.TagNumber(4)
  void clearInstallableOnPhone() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get profiles => $_getList(4);

  @$pb.TagNumber(6)
  $core.String get defaultProfile => $_getSZ(5);
  @$pb.TagNumber(6)
  set defaultProfile($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDefaultProfile() => $_has(5);
  @$pb.TagNumber(6)
  void clearDefaultProfile() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get specError => $_getSZ(6);
  @$pb.TagNumber(7)
  set specError($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSpecError() => $_has(6);
  @$pb.TagNumber(7)
  void clearSpecError() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get phoneTriggerAllowed => $_getBF(7);
  @$pb.TagNumber(8)
  set phoneTriggerAllowed($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPhoneTriggerAllowed() => $_has(7);
  @$pb.TagNumber(8)
  void clearPhoneTriggerAllowed() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get launchAfterInstall => $_getBF(8);
  @$pb.TagNumber(9)
  set launchAfterInstall($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLaunchAfterInstall() => $_has(8);
  @$pb.TagNumber(9)
  void clearLaunchAfterInstall() => $_clearField(9);

  /// --- status (pilot) ---
  @$pb.TagNumber(10)
  $core.bool get building => $_getBF(9);
  @$pb.TagNumber(10)
  set building($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasBuilding() => $_has(9);
  @$pb.TagNumber(10)
  void clearBuilding() => $_clearField(10);

  @$pb.TagNumber(11)
  BuildPhase get lastPhase => $_getN(10);
  @$pb.TagNumber(11)
  set lastPhase(BuildPhase value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasLastPhase() => $_has(10);
  @$pb.TagNumber(11)
  void clearLastPhase() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get lastBuildUnixMs => $_getI64(11);
  @$pb.TagNumber(12)
  set lastBuildUnixMs($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasLastBuildUnixMs() => $_has(11);
  @$pb.TagNumber(12)
  void clearLastBuildUnixMs() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get activeBuildId => $_getSZ(12);
  @$pb.TagNumber(13)
  set activeBuildId($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasActiveBuildId() => $_has(12);
  @$pb.TagNumber(13)
  void clearActiveBuildId() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get lastArtifactBuildId => $_getSZ(13);
  @$pb.TagNumber(14)
  set lastArtifactBuildId($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasLastArtifactBuildId() => $_has(13);
  @$pb.TagNumber(14)
  void clearLastArtifactBuildId() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get progressPercent => $_getIZ(14);
  @$pb.TagNumber(15)
  set progressPercent($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasProgressPercent() => $_has(14);
  @$pb.TagNumber(15)
  void clearProgressPercent() => $_clearField(15);

  /// --- sygnał od agenta AI (plik .remoteapptester-signal w folderze projektu) ---
  @$pb.TagNumber(16)
  $core.bool get changesPending => $_getBF(15);
  @$pb.TagNumber(16)
  set changesPending($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(16)
  $core.bool hasChangesPending() => $_has(15);
  @$pb.TagNumber(16)
  void clearChangesPending() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get agentNote => $_getSZ(16);
  @$pb.TagNumber(17)
  set agentNote($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasAgentNote() => $_has(16);
  @$pb.TagNumber(17)
  void clearAgentNote() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get agentNoteUnixMs => $_getI64(17);
  @$pb.TagNumber(18)
  set agentNoteUnixMs($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasAgentNoteUnixMs() => $_has(17);
  @$pb.TagNumber(18)
  void clearAgentNoteUnixMs() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.bool get agentBuildAllowed => $_getBF(18);
  @$pb.TagNumber(19)
  set agentBuildAllowed($core.bool value) => $_setBool(18, value);
  @$pb.TagNumber(19)
  $core.bool hasAgentBuildAllowed() => $_has(18);
  @$pb.TagNumber(19)
  void clearAgentBuildAllowed() => $_clearField(19);

  @$pb.TagNumber(20)
  InstallMode get installMode => $_getN(19);
  @$pb.TagNumber(20)
  set installMode(InstallMode value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasInstallMode() => $_has(19);
  @$pb.TagNumber(20)
  void clearInstallMode() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.bool get deliversToThisPhone => $_getBF(20);
  @$pb.TagNumber(21)
  set deliversToThisPhone($core.bool value) => $_setBool(20, value);
  @$pb.TagNumber(21)
  $core.bool hasDeliversToThisPhone() => $_has(20);
  @$pb.TagNumber(21)
  void clearDeliversToThisPhone() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.bool get agentPushAllowed => $_getBF(21);
  @$pb.TagNumber(22)
  set agentPushAllowed($core.bool value) => $_setBool(21, value);
  @$pb.TagNumber(22)
  $core.bool hasAgentPushAllowed() => $_has(21);
  @$pb.TagNumber(22)
  void clearAgentPushAllowed() => $_clearField(22);

  /// --- podgląd aplikacji web ---
  @$pb.TagNumber(23)
  $core.bool get previewAvailable => $_getBF(22);
  @$pb.TagNumber(23)
  set previewAvailable($core.bool value) => $_setBool(22, value);
  @$pb.TagNumber(23)
  $core.bool hasPreviewAvailable() => $_has(22);
  @$pb.TagNumber(23)
  void clearPreviewAvailable() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.String get previewKind => $_getSZ(23);
  @$pb.TagNumber(24)
  set previewKind($core.String value) => $_setString(23, value);
  @$pb.TagNumber(24)
  $core.bool hasPreviewKind() => $_has(23);
  @$pb.TagNumber(24)
  void clearPreviewKind() => $_clearField(24);

  @$pb.TagNumber(25)
  $core.bool get previewRunning => $_getBF(24);
  @$pb.TagNumber(25)
  set previewRunning($core.bool value) => $_setBool(24, value);
  @$pb.TagNumber(25)
  $core.bool hasPreviewRunning() => $_has(24);
  @$pb.TagNumber(25)
  void clearPreviewRunning() => $_clearField(25);
}

class SecretRotation extends $pb.GeneratedMessage {
  factory SecretRotation({
    $core.String? newSecret,
  }) {
    final result = create();
    if (newSecret != null) result.newSecret = newSecret;
    return result;
  }

  SecretRotation._();

  factory SecretRotation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SecretRotation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SecretRotation',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'newSecret')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecretRotation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecretRotation copyWith(void Function(SecretRotation) updates) =>
      super.copyWith((message) => updates(message as SecretRotation))
          as SecretRotation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SecretRotation create() => SecretRotation._();
  @$core.override
  SecretRotation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SecretRotation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SecretRotation>(create);
  static SecretRotation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get newSecret => $_getSZ(0);
  @$pb.TagNumber(1)
  set newSecret($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNewSecret() => $_has(0);
  @$pb.TagNumber(1)
  void clearNewSecret() => $_clearField(1);
}

class ProjectOptionsUpdate extends $pb.GeneratedMessage {
  factory ProjectOptionsUpdate({
    $core.String? projectId,
    $core.bool? launchAfterInstall,
    InstallMode? installMode,
    $core.bool? agentBuildAllowed,
    $core.bool? deliverToThisPhone,
    $core.bool? agentPushAllowed,
  }) {
    final result = create();
    if (projectId != null) result.projectId = projectId;
    if (launchAfterInstall != null)
      result.launchAfterInstall = launchAfterInstall;
    if (installMode != null) result.installMode = installMode;
    if (agentBuildAllowed != null) result.agentBuildAllowed = agentBuildAllowed;
    if (deliverToThisPhone != null)
      result.deliverToThisPhone = deliverToThisPhone;
    if (agentPushAllowed != null) result.agentPushAllowed = agentPushAllowed;
    return result;
  }

  ProjectOptionsUpdate._();

  factory ProjectOptionsUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProjectOptionsUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProjectOptionsUpdate',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'projectId')
    ..aOB(2, _omitFieldNames ? '' : 'launchAfterInstall')
    ..aE<InstallMode>(3, _omitFieldNames ? '' : 'installMode',
        enumValues: InstallMode.values)
    ..aOB(4, _omitFieldNames ? '' : 'agentBuildAllowed')
    ..aOB(5, _omitFieldNames ? '' : 'deliverToThisPhone')
    ..aOB(6, _omitFieldNames ? '' : 'agentPushAllowed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProjectOptionsUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProjectOptionsUpdate copyWith(void Function(ProjectOptionsUpdate) updates) =>
      super.copyWith((message) => updates(message as ProjectOptionsUpdate))
          as ProjectOptionsUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProjectOptionsUpdate create() => ProjectOptionsUpdate._();
  @$core.override
  ProjectOptionsUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProjectOptionsUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProjectOptionsUpdate>(create);
  static ProjectOptionsUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get projectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set projectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProjectId() => $_clearField(1);

  /// Pola nieustawione = bez zmian.
  @$pb.TagNumber(2)
  $core.bool get launchAfterInstall => $_getBF(1);
  @$pb.TagNumber(2)
  set launchAfterInstall($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLaunchAfterInstall() => $_has(1);
  @$pb.TagNumber(2)
  void clearLaunchAfterInstall() => $_clearField(2);

  @$pb.TagNumber(3)
  InstallMode get installMode => $_getN(2);
  @$pb.TagNumber(3)
  set installMode(InstallMode value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasInstallMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearInstallMode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get agentBuildAllowed => $_getBF(3);
  @$pb.TagNumber(4)
  set agentBuildAllowed($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAgentBuildAllowed() => $_has(3);
  @$pb.TagNumber(4)
  void clearAgentBuildAllowed() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get deliverToThisPhone => $_getBF(4);
  @$pb.TagNumber(5)
  set deliverToThisPhone($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDeliverToThisPhone() => $_has(4);
  @$pb.TagNumber(5)
  void clearDeliverToThisPhone() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get agentPushAllowed => $_getBF(5);
  @$pb.TagNumber(6)
  set agentPushAllowed($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAgentPushAllowed() => $_has(5);
  @$pb.TagNumber(6)
  void clearAgentPushAllowed() => $_clearField(6);
}

class ProjectList extends $pb.GeneratedMessage {
  factory ProjectList({
    $core.Iterable<Project>? projects,
  }) {
    final result = create();
    if (projects != null) result.projects.addAll(projects);
    return result;
  }

  ProjectList._();

  factory ProjectList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProjectList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProjectList',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..pPM<Project>(1, _omitFieldNames ? '' : 'projects',
        subBuilder: Project.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProjectList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProjectList copyWith(void Function(ProjectList) updates) =>
      super.copyWith((message) => updates(message as ProjectList))
          as ProjectList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProjectList create() => ProjectList._();
  @$core.override
  ProjectList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProjectList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProjectList>(create);
  static ProjectList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Project> get projects => $_getList(0);
}

class BuildRequest extends $pb.GeneratedMessage {
  factory BuildRequest({
    $core.String? projectId,
    $core.String? profile,
  }) {
    final result = create();
    if (projectId != null) result.projectId = projectId;
    if (profile != null) result.profile = profile;
    return result;
  }

  BuildRequest._();

  factory BuildRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BuildRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BuildRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'projectId')
    ..aOS(2, _omitFieldNames ? '' : 'profile')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuildRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuildRequest copyWith(void Function(BuildRequest) updates) =>
      super.copyWith((message) => updates(message as BuildRequest))
          as BuildRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BuildRequest create() => BuildRequest._();
  @$core.override
  BuildRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BuildRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BuildRequest>(create);
  static BuildRequest? _defaultInstance;

  /// Komendy budowania żyją WYŁĄCZNIE w bazie hosta — telefon wskazuje projekt
  /// i (opcjonalnie) NAZWĘ wariantu z listy Project.profiles.
  @$pb.TagNumber(1)
  $core.String get projectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set projectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get profile => $_getSZ(1);
  @$pb.TagNumber(2)
  set profile($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProfile() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfile() => $_clearField(2);
}

class BuildEvent extends $pb.GeneratedMessage {
  factory BuildEvent({
    $core.String? buildId,
    BuildPhase? phase,
    $core.String? logLine,
    $core.int? progressPercent,
    $core.int? queuePosition,
  }) {
    final result = create();
    if (buildId != null) result.buildId = buildId;
    if (phase != null) result.phase = phase;
    if (logLine != null) result.logLine = logLine;
    if (progressPercent != null) result.progressPercent = progressPercent;
    if (queuePosition != null) result.queuePosition = queuePosition;
    return result;
  }

  BuildEvent._();

  factory BuildEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BuildEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BuildEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'buildId')
    ..aE<BuildPhase>(2, _omitFieldNames ? '' : 'phase',
        enumValues: BuildPhase.values)
    ..aOS(3, _omitFieldNames ? '' : 'logLine')
    ..aI(4, _omitFieldNames ? '' : 'progressPercent')
    ..aI(5, _omitFieldNames ? '' : 'queuePosition')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuildEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuildEvent copyWith(void Function(BuildEvent) updates) =>
      super.copyWith((message) => updates(message as BuildEvent)) as BuildEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BuildEvent create() => BuildEvent._();
  @$core.override
  BuildEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BuildEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BuildEvent>(create);
  static BuildEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get buildId => $_getSZ(0);
  @$pb.TagNumber(1)
  set buildId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBuildId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBuildId() => $_clearField(1);

  @$pb.TagNumber(2)
  BuildPhase get phase => $_getN(1);
  @$pb.TagNumber(2)
  set phase(BuildPhase value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPhase() => $_has(1);
  @$pb.TagNumber(2)
  void clearPhase() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get logLine => $_getSZ(2);
  @$pb.TagNumber(3)
  set logLine($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLogLine() => $_has(2);
  @$pb.TagNumber(3)
  void clearLogLine() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get progressPercent => $_getIZ(3);
  @$pb.TagNumber(4)
  set progressPercent($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProgressPercent() => $_has(3);
  @$pb.TagNumber(4)
  void clearProgressPercent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get queuePosition => $_getIZ(4);
  @$pb.TagNumber(5)
  set queuePosition($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQueuePosition() => $_has(4);
  @$pb.TagNumber(5)
  void clearQueuePosition() => $_clearField(5);
}

class BuildId extends $pb.GeneratedMessage {
  factory BuildId({
    $core.String? buildId,
  }) {
    final result = create();
    if (buildId != null) result.buildId = buildId;
    return result;
  }

  BuildId._();

  factory BuildId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BuildId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BuildId',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'buildId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuildId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuildId copyWith(void Function(BuildId) updates) =>
      super.copyWith((message) => updates(message as BuildId)) as BuildId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BuildId create() => BuildId._();
  @$core.override
  BuildId createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BuildId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BuildId>(create);
  static BuildId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get buildId => $_getSZ(0);
  @$pb.TagNumber(1)
  set buildId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBuildId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBuildId() => $_clearField(1);
}

class Ack extends $pb.GeneratedMessage {
  factory Ack({
    $core.bool? success,
    $core.String? message,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (message != null) result.message = message;
    return result;
  }

  Ack._();

  factory Ack.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ack.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ack',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack copyWith(void Function(Ack) updates) =>
      super.copyWith((message) => updates(message as Ack)) as Ack;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ack create() => Ack._();
  @$core.override
  Ack createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Ack getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ack>(create);
  static Ack? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class ArtifactRequest extends $pb.GeneratedMessage {
  factory ArtifactRequest({
    $core.String? buildId,
    $fixnum.Int64? resumeFromByteOffset,
  }) {
    final result = create();
    if (buildId != null) result.buildId = buildId;
    if (resumeFromByteOffset != null)
      result.resumeFromByteOffset = resumeFromByteOffset;
    return result;
  }

  ArtifactRequest._();

  factory ArtifactRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ArtifactRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArtifactRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'buildId')
    ..aInt64(2, _omitFieldNames ? '' : 'resumeFromByteOffset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArtifactRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArtifactRequest copyWith(void Function(ArtifactRequest) updates) =>
      super.copyWith((message) => updates(message as ArtifactRequest))
          as ArtifactRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ArtifactRequest create() => ArtifactRequest._();
  @$core.override
  ArtifactRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ArtifactRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArtifactRequest>(create);
  static ArtifactRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get buildId => $_getSZ(0);
  @$pb.TagNumber(1)
  set buildId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBuildId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBuildId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get resumeFromByteOffset => $_getI64(1);
  @$pb.TagNumber(2)
  set resumeFromByteOffset($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResumeFromByteOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearResumeFromByteOffset() => $_clearField(2);
}

class DeltaRequest extends $pb.GeneratedMessage {
  factory DeltaRequest({
    $core.String? buildId,
    $core.String? baseSha256,
    $fixnum.Int64? resumeFromByteOffset,
  }) {
    final result = create();
    if (buildId != null) result.buildId = buildId;
    if (baseSha256 != null) result.baseSha256 = baseSha256;
    if (resumeFromByteOffset != null)
      result.resumeFromByteOffset = resumeFromByteOffset;
    return result;
  }

  DeltaRequest._();

  factory DeltaRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeltaRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeltaRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'buildId')
    ..aOS(2, _omitFieldNames ? '' : 'baseSha256')
    ..aInt64(3, _omitFieldNames ? '' : 'resumeFromByteOffset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeltaRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeltaRequest copyWith(void Function(DeltaRequest) updates) =>
      super.copyWith((message) => updates(message as DeltaRequest))
          as DeltaRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeltaRequest create() => DeltaRequest._();
  @$core.override
  DeltaRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeltaRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeltaRequest>(create);
  static DeltaRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get buildId => $_getSZ(0);
  @$pb.TagNumber(1)
  set buildId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBuildId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBuildId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get baseSha256 => $_getSZ(1);
  @$pb.TagNumber(2)
  set baseSha256($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBaseSha256() => $_has(1);
  @$pb.TagNumber(2)
  void clearBaseSha256() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get resumeFromByteOffset => $_getI64(2);
  @$pb.TagNumber(3)
  set resumeFromByteOffset($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasResumeFromByteOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearResumeFromByteOffset() => $_clearField(3);
}

class Chunk extends $pb.GeneratedMessage {
  factory Chunk({
    $core.List<$core.int>? data,
    $fixnum.Int64? offset,
    $core.bool? isLast,
    $core.String? sha256FullFile,
    $fixnum.Int64? totalSize,
    $core.String? targetSha256,
    $fixnum.Int64? targetSize,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (offset != null) result.offset = offset;
    if (isLast != null) result.isLast = isLast;
    if (sha256FullFile != null) result.sha256FullFile = sha256FullFile;
    if (totalSize != null) result.totalSize = totalSize;
    if (targetSha256 != null) result.targetSha256 = targetSha256;
    if (targetSize != null) result.targetSize = targetSize;
    return result;
  }

  Chunk._();

  factory Chunk.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Chunk.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Chunk',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aInt64(2, _omitFieldNames ? '' : 'offset')
    ..aOB(3, _omitFieldNames ? '' : 'isLast')
    ..aOS(4, _omitFieldNames ? '' : 'sha256FullFile')
    ..aInt64(5, _omitFieldNames ? '' : 'totalSize')
    ..aOS(6, _omitFieldNames ? '' : 'targetSha256')
    ..aInt64(7, _omitFieldNames ? '' : 'targetSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Chunk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Chunk copyWith(void Function(Chunk) updates) =>
      super.copyWith((message) => updates(message as Chunk)) as Chunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Chunk create() => Chunk._();
  @$core.override
  Chunk createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Chunk getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Chunk>(create);
  static Chunk? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get offset => $_getI64(1);
  @$pb.TagNumber(2)
  set offset($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isLast => $_getBF(2);
  @$pb.TagNumber(3)
  set isLast($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsLast() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsLast() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sha256FullFile => $_getSZ(3);
  @$pb.TagNumber(4)
  set sha256FullFile($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSha256FullFile() => $_has(3);
  @$pb.TagNumber(4)
  void clearSha256FullFile() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get totalSize => $_getI64(4);
  @$pb.TagNumber(5)
  set totalSize($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTotalSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearTotalSize() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get targetSha256 => $_getSZ(5);
  @$pb.TagNumber(6)
  set targetSha256($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTargetSha256() => $_has(5);
  @$pb.TagNumber(6)
  void clearTargetSha256() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get targetSize => $_getI64(6);
  @$pb.TagNumber(7)
  set targetSize($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTargetSize() => $_has(6);
  @$pb.TagNumber(7)
  void clearTargetSize() => $_clearField(7);
}

class Delivery extends $pb.GeneratedMessage {
  factory Delivery({
    $core.String? buildId,
    $core.String? projectId,
    $core.String? projectName,
    $fixnum.Int64? sizeBytes,
    $core.String? sha256,
    InstallMode? install,
    $core.bool? launch,
    $fixnum.Int64? builtUnixMs,
    $core.String? methodId,
  }) {
    final result = create();
    if (buildId != null) result.buildId = buildId;
    if (projectId != null) result.projectId = projectId;
    if (projectName != null) result.projectName = projectName;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    if (sha256 != null) result.sha256 = sha256;
    if (install != null) result.install = install;
    if (launch != null) result.launch = launch;
    if (builtUnixMs != null) result.builtUnixMs = builtUnixMs;
    if (methodId != null) result.methodId = methodId;
    return result;
  }

  Delivery._();

  factory Delivery.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Delivery.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Delivery',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'buildId')
    ..aOS(2, _omitFieldNames ? '' : 'projectId')
    ..aOS(3, _omitFieldNames ? '' : 'projectName')
    ..aInt64(4, _omitFieldNames ? '' : 'sizeBytes')
    ..aOS(5, _omitFieldNames ? '' : 'sha256')
    ..aE<InstallMode>(6, _omitFieldNames ? '' : 'install',
        enumValues: InstallMode.values)
    ..aOB(7, _omitFieldNames ? '' : 'launch')
    ..aInt64(8, _omitFieldNames ? '' : 'builtUnixMs')
    ..aOS(9, _omitFieldNames ? '' : 'methodId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Delivery clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Delivery copyWith(void Function(Delivery) updates) =>
      super.copyWith((message) => updates(message as Delivery)) as Delivery;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Delivery create() => Delivery._();
  @$core.override
  Delivery createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Delivery getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Delivery>(create);
  static Delivery? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get buildId => $_getSZ(0);
  @$pb.TagNumber(1)
  set buildId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBuildId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBuildId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get projectId => $_getSZ(1);
  @$pb.TagNumber(2)
  set projectId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProjectId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProjectId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get projectName => $_getSZ(2);
  @$pb.TagNumber(3)
  set projectName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProjectName() => $_has(2);
  @$pb.TagNumber(3)
  void clearProjectName() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sizeBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSizeBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearSizeBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sha256 => $_getSZ(4);
  @$pb.TagNumber(5)
  set sha256($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSha256() => $_has(4);
  @$pb.TagNumber(5)
  void clearSha256() => $_clearField(5);

  @$pb.TagNumber(6)
  InstallMode get install => $_getN(5);
  @$pb.TagNumber(6)
  set install(InstallMode value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasInstall() => $_has(5);
  @$pb.TagNumber(6)
  void clearInstall() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get launch => $_getBF(6);
  @$pb.TagNumber(7)
  set launch($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLaunch() => $_has(6);
  @$pb.TagNumber(7)
  void clearLaunch() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get builtUnixMs => $_getI64(7);
  @$pb.TagNumber(8)
  set builtUnixMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBuiltUnixMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearBuiltUnixMs() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get methodId => $_getSZ(8);
  @$pb.TagNumber(9)
  set methodId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMethodId() => $_has(8);
  @$pb.TagNumber(9)
  void clearMethodId() => $_clearField(9);
}

enum DeliveryEvent_Event { delivery, heartbeatUnixMs, notSet }

class DeliveryEvent extends $pb.GeneratedMessage {
  factory DeliveryEvent({
    Delivery? delivery,
    $fixnum.Int64? heartbeatUnixMs,
  }) {
    final result = create();
    if (delivery != null) result.delivery = delivery;
    if (heartbeatUnixMs != null) result.heartbeatUnixMs = heartbeatUnixMs;
    return result;
  }

  DeliveryEvent._();

  factory DeliveryEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeliveryEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, DeliveryEvent_Event>
      _DeliveryEvent_EventByTag = {
    1: DeliveryEvent_Event.delivery,
    2: DeliveryEvent_Event.heartbeatUnixMs,
    0: DeliveryEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeliveryEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<Delivery>(1, _omitFieldNames ? '' : 'delivery',
        subBuilder: Delivery.create)
    ..aInt64(2, _omitFieldNames ? '' : 'heartbeatUnixMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeliveryEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeliveryEvent copyWith(void Function(DeliveryEvent) updates) =>
      super.copyWith((message) => updates(message as DeliveryEvent))
          as DeliveryEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeliveryEvent create() => DeliveryEvent._();
  @$core.override
  DeliveryEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeliveryEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeliveryEvent>(create);
  static DeliveryEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  DeliveryEvent_Event whichEvent() =>
      _DeliveryEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  Delivery get delivery => $_getN(0);
  @$pb.TagNumber(1)
  set delivery(Delivery value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDelivery() => $_has(0);
  @$pb.TagNumber(1)
  void clearDelivery() => $_clearField(1);
  @$pb.TagNumber(1)
  Delivery ensureDelivery() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get heartbeatUnixMs => $_getI64(1);
  @$pb.TagNumber(2)
  set heartbeatUnixMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeatUnixMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartbeatUnixMs() => $_clearField(2);
}

class PreviewRequest extends $pb.GeneratedMessage {
  factory PreviewRequest({
    $core.String? projectId,
  }) {
    final result = create();
    if (projectId != null) result.projectId = projectId;
    return result;
  }

  PreviewRequest._();

  factory PreviewRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PreviewRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PreviewRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'projectId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreviewRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreviewRequest copyWith(void Function(PreviewRequest) updates) =>
      super.copyWith((message) => updates(message as PreviewRequest))
          as PreviewRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PreviewRequest create() => PreviewRequest._();
  @$core.override
  PreviewRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PreviewRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PreviewRequest>(create);
  static PreviewRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get projectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set projectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProjectId() => $_clearField(1);
}

class PreviewEvent extends $pb.GeneratedMessage {
  factory PreviewEvent({
    PreviewState? state,
    $core.String? url,
    $core.String? logLine,
    $core.bool? reload,
    $core.String? message,
    $core.bool? pinnedTls,
  }) {
    final result = create();
    if (state != null) result.state = state;
    if (url != null) result.url = url;
    if (logLine != null) result.logLine = logLine;
    if (reload != null) result.reload = reload;
    if (message != null) result.message = message;
    if (pinnedTls != null) result.pinnedTls = pinnedTls;
    return result;
  }

  PreviewEvent._();

  factory PreviewEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PreviewEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PreviewEvent',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aE<PreviewState>(1, _omitFieldNames ? '' : 'state',
        enumValues: PreviewState.values)
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..aOS(3, _omitFieldNames ? '' : 'logLine')
    ..aOB(4, _omitFieldNames ? '' : 'reload')
    ..aOS(5, _omitFieldNames ? '' : 'message')
    ..aOB(6, _omitFieldNames ? '' : 'pinnedTls')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreviewEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreviewEvent copyWith(void Function(PreviewEvent) updates) =>
      super.copyWith((message) => updates(message as PreviewEvent))
          as PreviewEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PreviewEvent create() => PreviewEvent._();
  @$core.override
  PreviewEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PreviewEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PreviewEvent>(create);
  static PreviewEvent? _defaultInstance;

  @$pb.TagNumber(1)
  PreviewState get state => $_getN(0);
  @$pb.TagNumber(1)
  set state(PreviewState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get logLine => $_getSZ(2);
  @$pb.TagNumber(3)
  set logLine($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLogLine() => $_has(2);
  @$pb.TagNumber(3)
  void clearLogLine() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get reload => $_getBF(3);
  @$pb.TagNumber(4)
  set reload($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReload() => $_has(3);
  @$pb.TagNumber(4)
  void clearReload() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get message => $_getSZ(4);
  @$pb.TagNumber(5)
  set message($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessage() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get pinnedTls => $_getBF(5);
  @$pb.TagNumber(6)
  set pinnedTls($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPinnedTls() => $_has(5);
  @$pb.TagNumber(6)
  void clearPinnedTls() => $_clearField(6);
}

class PreviewIssue extends $pb.GeneratedMessage {
  factory PreviewIssue({
    $core.String? projectId,
    $core.String? note,
    $core.String? pageUrl,
    $core.Iterable<$core.String>? console,
    $core.String? userAgent,
    $core.int? viewportWidth,
    $core.int? viewportHeight,
  }) {
    final result = create();
    if (projectId != null) result.projectId = projectId;
    if (note != null) result.note = note;
    if (pageUrl != null) result.pageUrl = pageUrl;
    if (console != null) result.console.addAll(console);
    if (userAgent != null) result.userAgent = userAgent;
    if (viewportWidth != null) result.viewportWidth = viewportWidth;
    if (viewportHeight != null) result.viewportHeight = viewportHeight;
    return result;
  }

  PreviewIssue._();

  factory PreviewIssue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PreviewIssue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PreviewIssue',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'remotetester.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'projectId')
    ..aOS(2, _omitFieldNames ? '' : 'note')
    ..aOS(3, _omitFieldNames ? '' : 'pageUrl')
    ..pPS(4, _omitFieldNames ? '' : 'console')
    ..aOS(5, _omitFieldNames ? '' : 'userAgent')
    ..aI(6, _omitFieldNames ? '' : 'viewportWidth')
    ..aI(7, _omitFieldNames ? '' : 'viewportHeight')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreviewIssue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreviewIssue copyWith(void Function(PreviewIssue) updates) =>
      super.copyWith((message) => updates(message as PreviewIssue))
          as PreviewIssue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PreviewIssue create() => PreviewIssue._();
  @$core.override
  PreviewIssue createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PreviewIssue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PreviewIssue>(create);
  static PreviewIssue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get projectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set projectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get note => $_getSZ(1);
  @$pb.TagNumber(2)
  set note($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNote() => $_has(1);
  @$pb.TagNumber(2)
  void clearNote() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get pageUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set pageUrl($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPageUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get console => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get userAgent => $_getSZ(4);
  @$pb.TagNumber(5)
  set userAgent($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUserAgent() => $_has(4);
  @$pb.TagNumber(5)
  void clearUserAgent() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get viewportWidth => $_getIZ(5);
  @$pb.TagNumber(6)
  set viewportWidth($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasViewportWidth() => $_has(5);
  @$pb.TagNumber(6)
  void clearViewportWidth() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get viewportHeight => $_getIZ(6);
  @$pb.TagNumber(7)
  set viewportHeight($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasViewportHeight() => $_has(6);
  @$pb.TagNumber(7)
  void clearViewportHeight() => $_clearField(7);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
