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

import 'package:protobuf/protobuf.dart' as $pb;

class ProjectTemplate extends $pb.ProtobufEnum {
  static const ProjectTemplate PROJECT_TEMPLATE_UNSPECIFIED = ProjectTemplate._(
      0, _omitEnumNames ? '' : 'PROJECT_TEMPLATE_UNSPECIFIED');
  static const ProjectTemplate EXISTING_FOLDER =
      ProjectTemplate._(1, _omitEnumNames ? '' : 'EXISTING_FOLDER');
  static const ProjectTemplate EMPTY_FOLDER =
      ProjectTemplate._(2, _omitEnumNames ? '' : 'EMPTY_FOLDER');
  static const ProjectTemplate FLUTTER_APP =
      ProjectTemplate._(3, _omitEnumNames ? '' : 'FLUTTER_APP');

  static const $core.List<ProjectTemplate> values = <ProjectTemplate>[
    PROJECT_TEMPLATE_UNSPECIFIED,
    EXISTING_FOLDER,
    EMPTY_FOLDER,
    FLUTTER_APP,
  ];

  static final $core.List<ProjectTemplate?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ProjectTemplate? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProjectTemplate._(super.value, super.name);
}

/// Rozpoznany typ projektu — wyłącznie informacja o tym, jak projekt da się
/// zbudować (zamknięta lista receptur w kodzie hosta).
class ProjectKind extends $pb.ProtobufEnum {
  static const ProjectKind PROJECT_KIND_UNSPECIFIED =
      ProjectKind._(0, _omitEnumNames ? '' : 'PROJECT_KIND_UNSPECIFIED');
  static const ProjectKind OTHER =
      ProjectKind._(1, _omitEnumNames ? '' : 'OTHER');
  static const ProjectKind FLUTTER =
      ProjectKind._(2, _omitEnumNames ? '' : 'FLUTTER');
  static const ProjectKind ANDROID_GRADLE =
      ProjectKind._(3, _omitEnumNames ? '' : 'ANDROID_GRADLE');
  static const ProjectKind REACT_NATIVE =
      ProjectKind._(4, _omitEnumNames ? '' : 'REACT_NATIVE');
  static const ProjectKind CAPACITOR =
      ProjectKind._(5, _omitEnumNames ? '' : 'CAPACITOR');

  static const $core.List<ProjectKind> values = <ProjectKind>[
    PROJECT_KIND_UNSPECIFIED,
    OTHER,
    FLUTTER,
    ANDROID_GRADLE,
    REACT_NATIVE,
    CAPACITOR,
  ];

  static final $core.List<ProjectKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ProjectKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProjectKind._(super.value, super.name);
}

class BuildPhase extends $pb.ProtobufEnum {
  static const BuildPhase BUILD_PHASE_UNSPECIFIED =
      BuildPhase._(0, _omitEnumNames ? '' : 'BUILD_PHASE_UNSPECIFIED');
  static const BuildPhase QUEUED =
      BuildPhase._(1, _omitEnumNames ? '' : 'QUEUED');
  static const BuildPhase PREPARE =
      BuildPhase._(2, _omitEnumNames ? '' : 'PREPARE');
  static const BuildPhase BUILDING =
      BuildPhase._(3, _omitEnumNames ? '' : 'BUILDING');
  static const BuildPhase PACKAGING =
      BuildPhase._(4, _omitEnumNames ? '' : 'PACKAGING');
  static const BuildPhase DONE = BuildPhase._(5, _omitEnumNames ? '' : 'DONE');
  static const BuildPhase FAILED =
      BuildPhase._(6, _omitEnumNames ? '' : 'FAILED');
  static const BuildPhase CANCELLED =
      BuildPhase._(7, _omitEnumNames ? '' : 'CANCELLED');

  static const $core.List<BuildPhase> values = <BuildPhase>[
    BUILD_PHASE_UNSPECIFIED,
    QUEUED,
    PREPARE,
    BUILDING,
    PACKAGING,
    DONE,
    FAILED,
    CANCELLED,
  ];

  static final $core.List<BuildPhase?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static BuildPhase? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BuildPhase._(super.value, super.name);
}

class InstallMode extends $pb.ProtobufEnum {
  static const InstallMode INSTALL_MODE_UNSPECIFIED =
      InstallMode._(0, _omitEnumNames ? '' : 'INSTALL_MODE_UNSPECIFIED');
  static const InstallMode AUTO =
      InstallMode._(1, _omitEnumNames ? '' : 'AUTO');
  static const InstallMode ASK = InstallMode._(2, _omitEnumNames ? '' : 'ASK');
  static const InstallMode OFF = InstallMode._(3, _omitEnumNames ? '' : 'OFF');

  static const $core.List<InstallMode> values = <InstallMode>[
    INSTALL_MODE_UNSPECIFIED,
    AUTO,
    ASK,
    OFF,
  ];

  static final $core.List<InstallMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static InstallMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const InstallMode._(super.value, super.name);
}

class PreviewState extends $pb.ProtobufEnum {
  static const PreviewState PREVIEW_STATE_UNSPECIFIED =
      PreviewState._(0, _omitEnumNames ? '' : 'PREVIEW_STATE_UNSPECIFIED');
  static const PreviewState PREVIEW_STARTING =
      PreviewState._(1, _omitEnumNames ? '' : 'PREVIEW_STARTING');
  static const PreviewState PREVIEW_RUNNING =
      PreviewState._(2, _omitEnumNames ? '' : 'PREVIEW_RUNNING');
  static const PreviewState PREVIEW_STOPPED =
      PreviewState._(3, _omitEnumNames ? '' : 'PREVIEW_STOPPED');
  static const PreviewState PREVIEW_FAILED =
      PreviewState._(4, _omitEnumNames ? '' : 'PREVIEW_FAILED');

  static const $core.List<PreviewState> values = <PreviewState>[
    PREVIEW_STATE_UNSPECIFIED,
    PREVIEW_STARTING,
    PREVIEW_RUNNING,
    PREVIEW_STOPPED,
    PREVIEW_FAILED,
  ];

  static final $core.List<PreviewState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static PreviewState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PreviewState._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
