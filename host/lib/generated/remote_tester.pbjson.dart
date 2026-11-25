// This is a generated file - do not edit.
//
// Generated from remote_tester.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use projectTemplateDescriptor instead')
const ProjectTemplate$json = {
  '1': 'ProjectTemplate',
  '2': [
    {'1': 'PROJECT_TEMPLATE_UNSPECIFIED', '2': 0},
    {'1': 'EXISTING_FOLDER', '2': 1},
    {'1': 'EMPTY_FOLDER', '2': 2},
    {'1': 'FLUTTER_APP', '2': 3},
  ],
};

/// Descriptor for `ProjectTemplate`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List projectTemplateDescriptor = $convert.base64Decode(
    'Cg9Qcm9qZWN0VGVtcGxhdGUSIAocUFJPSkVDVF9URU1QTEFURV9VTlNQRUNJRklFRBAAEhMKD0'
    'VYSVNUSU5HX0ZPTERFUhABEhAKDEVNUFRZX0ZPTERFUhACEg8KC0ZMVVRURVJfQVBQEAM=');

@$core.Deprecated('Use projectKindDescriptor instead')
const ProjectKind$json = {
  '1': 'ProjectKind',
  '2': [
    {'1': 'PROJECT_KIND_UNSPECIFIED', '2': 0},
    {'1': 'OTHER', '2': 1},
    {'1': 'FLUTTER', '2': 2},
    {'1': 'ANDROID_GRADLE', '2': 3},
    {'1': 'REACT_NATIVE', '2': 4},
    {'1': 'CAPACITOR', '2': 5},
  ],
};

/// Descriptor for `ProjectKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List projectKindDescriptor = $convert.base64Decode(
    'CgtQcm9qZWN0S2luZBIcChhQUk9KRUNUX0tJTkRfVU5TUEVDSUZJRUQQABIJCgVPVEhFUhABEg'
    'sKB0ZMVVRURVIQAhISCg5BTkRST0lEX0dSQURMRRADEhAKDFJFQUNUX05BVElWRRAEEg0KCUNB'
    'UEFDSVRPUhAF');

@$core.Deprecated('Use buildPhaseDescriptor instead')
const BuildPhase$json = {
  '1': 'BuildPhase',
  '2': [
    {'1': 'BUILD_PHASE_UNSPECIFIED', '2': 0},
    {'1': 'QUEUED', '2': 1},
    {'1': 'PREPARE', '2': 2},
    {'1': 'BUILDING', '2': 3},
    {'1': 'PACKAGING', '2': 4},
    {'1': 'DONE', '2': 5},
    {'1': 'FAILED', '2': 6},
    {'1': 'CANCELLED', '2': 7},
  ],
};

/// Descriptor for `BuildPhase`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List buildPhaseDescriptor = $convert.base64Decode(
    'CgpCdWlsZFBoYXNlEhsKF0JVSUxEX1BIQVNFX1VOU1BFQ0lGSUVEEAASCgoGUVVFVUVEEAESCw'
    'oHUFJFUEFSRRACEgwKCEJVSUxESU5HEAMSDQoJUEFDS0FHSU5HEAQSCAoERE9ORRAFEgoKBkZB'
    'SUxFRBAGEg0KCUNBTkNFTExFRBAH');

@$core.Deprecated('Use installModeDescriptor instead')
const InstallMode$json = {
  '1': 'InstallMode',
  '2': [
    {'1': 'INSTALL_MODE_UNSPECIFIED', '2': 0},
    {'1': 'AUTO', '2': 1},
    {'1': 'ASK', '2': 2},
    {'1': 'OFF', '2': 3},
  ],
};

/// Descriptor for `InstallMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List installModeDescriptor = $convert.base64Decode(
    'CgtJbnN0YWxsTW9kZRIcChhJTlNUQUxMX01PREVfVU5TUEVDSUZJRUQQABIICgRBVVRPEAESBw'
    'oDQVNLEAISBwoDT0ZGEAM=');

@$core.Deprecated('Use previewStateDescriptor instead')
const PreviewState$json = {
  '1': 'PreviewState',
  '2': [
    {'1': 'PREVIEW_STATE_UNSPECIFIED', '2': 0},
    {'1': 'PREVIEW_STARTING', '2': 1},
    {'1': 'PREVIEW_RUNNING', '2': 2},
    {'1': 'PREVIEW_STOPPED', '2': 3},
    {'1': 'PREVIEW_FAILED', '2': 4},
  ],
};

/// Descriptor for `PreviewState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List previewStateDescriptor = $convert.base64Decode(
    'CgxQcmV2aWV3U3RhdGUSHQoZUFJFVklFV19TVEFURV9VTlNQRUNJRklFRBAAEhQKEFBSRVZJRV'
    'dfU1RBUlRJTkcQARITCg9QUkVWSUVXX1JVTk5JTkcQAhITCg9QUkVWSUVXX1NUT1BQRUQQAxIS'
    'Cg5QUkVWSUVXX0ZBSUxFRBAE');

@$core.Deprecated('Use folderListDescriptor instead')
const FolderList$json = {
  '1': 'FolderList',
  '2': [
    {
      '1': 'folders',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.remotetester.v1.AvailableFolder',
      '10': 'folders'
    },
    {'1': 'adding_allowed', '3': 2, '4': 1, '5': 8, '10': 'addingAllowed'},
  ],
};

/// Descriptor for `FolderList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List folderListDescriptor = $convert.base64Decode(
    'CgpGb2xkZXJMaXN0EjoKB2ZvbGRlcnMYASADKAsyIC5yZW1vdGV0ZXN0ZXIudjEuQXZhaWxhYm'
    'xlRm9sZGVyUgdmb2xkZXJzEiUKDmFkZGluZ19hbGxvd2VkGAIgASgIUg1hZGRpbmdBbGxvd2Vk');

@$core.Deprecated('Use availableFolderDescriptor instead')
const AvailableFolder$json = {
  '1': 'AvailableFolder',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.remotetester.v1.ProjectKind',
      '10': 'kind'
    },
  ],
};

/// Descriptor for `AvailableFolder`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List availableFolderDescriptor = $convert.base64Decode(
    'Cg9BdmFpbGFibGVGb2xkZXISEgoEbmFtZRgBIAEoCVIEbmFtZRIwCgRraW5kGAIgASgOMhwucm'
    'Vtb3RldGVzdGVyLnYxLlByb2plY3RLaW5kUgRraW5k');

@$core.Deprecated('Use createProjectRequestDescriptor instead')
const CreateProjectRequest$json = {
  '1': 'CreateProjectRequest',
  '2': [
    {'1': 'folder_name', '3': 1, '4': 1, '5': 9, '10': 'folderName'},
    {
      '1': 'template',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.remotetester.v1.ProjectTemplate',
      '10': 'template'
    },
  ],
};

/// Descriptor for `CreateProjectRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createProjectRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVQcm9qZWN0UmVxdWVzdBIfCgtmb2xkZXJfbmFtZRgBIAEoCVIKZm9sZGVyTmFtZR'
    'I8Cgh0ZW1wbGF0ZRgCIAEoDjIgLnJlbW90ZXRlc3Rlci52MS5Qcm9qZWN0VGVtcGxhdGVSCHRl'
    'bXBsYXRl');

@$core.Deprecated('Use emptyDescriptor instead')
const Empty$json = {
  '1': 'Empty',
};

/// Descriptor for `Empty`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyDescriptor =
    $convert.base64Decode('CgVFbXB0eQ==');

@$core.Deprecated('Use pongDescriptor instead')
const Pong$json = {
  '1': 'Pong',
  '2': [
    {
      '1': 'server_time_unix_ms',
      '3': 1,
      '4': 1,
      '5': 3,
      '10': 'serverTimeUnixMs'
    },
    {'1': 'host_version', '3': 2, '4': 1, '5': 9, '10': 'hostVersion'},
  ],
};

/// Descriptor for `Pong`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pongDescriptor = $convert.base64Decode(
    'CgRQb25nEi0KE3NlcnZlcl90aW1lX3VuaXhfbXMYASABKANSEHNlcnZlclRpbWVVbml4TXMSIQ'
    'oMaG9zdF92ZXJzaW9uGAIgASgJUgtob3N0VmVyc2lvbg==');

@$core.Deprecated('Use projectDescriptor instead')
const Project$json = {
  '1': 'Project',
  '2': [
    {'1': 'project_id', '3': 1, '4': 1, '5': 9, '10': 'projectId'},
    {'1': 'display_name', '3': 2, '4': 1, '5': 9, '10': 'displayName'},
    {
      '1': 'kind',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.remotetester.v1.ProjectKind',
      '10': 'kind'
    },
    {
      '1': 'installable_on_phone',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'installableOnPhone'
    },
    {'1': 'profiles', '3': 5, '4': 3, '5': 9, '10': 'profiles'},
    {'1': 'default_profile', '3': 6, '4': 1, '5': 9, '10': 'defaultProfile'},
    {'1': 'spec_error', '3': 7, '4': 1, '5': 9, '10': 'specError'},
    {
      '1': 'phone_trigger_allowed',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'phoneTriggerAllowed'
    },
    {
      '1': 'launch_after_install',
      '3': 9,
      '4': 1,
      '5': 8,
      '10': 'launchAfterInstall'
    },
    {'1': 'building', '3': 10, '4': 1, '5': 8, '10': 'building'},
    {
      '1': 'last_phase',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.remotetester.v1.BuildPhase',
      '10': 'lastPhase'
    },
    {
      '1': 'last_build_unix_ms',
      '3': 12,
      '4': 1,
      '5': 3,
      '10': 'lastBuildUnixMs'
    },
    {'1': 'active_build_id', '3': 13, '4': 1, '5': 9, '10': 'activeBuildId'},
    {
      '1': 'last_artifact_build_id',
      '3': 14,
      '4': 1,
      '5': 9,
      '10': 'lastArtifactBuildId'
    },
    {'1': 'progress_percent', '3': 15, '4': 1, '5': 5, '10': 'progressPercent'},
    {'1': 'changes_pending', '3': 16, '4': 1, '5': 8, '10': 'changesPending'},
    {'1': 'agent_note', '3': 17, '4': 1, '5': 9, '10': 'agentNote'},
    {
      '1': 'agent_note_unix_ms',
      '3': 18,
      '4': 1,
      '5': 3,
      '10': 'agentNoteUnixMs'
    },
    {
      '1': 'agent_build_allowed',
      '3': 19,
      '4': 1,
      '5': 8,
      '10': 'agentBuildAllowed'
    },
    {
      '1': 'install_mode',
      '3': 20,
      '4': 1,
      '5': 14,
      '6': '.remotetester.v1.InstallMode',
      '10': 'installMode'
    },
    {
      '1': 'delivers_to_this_phone',
      '3': 21,
      '4': 1,
      '5': 8,
      '10': 'deliversToThisPhone'
    },
    {
      '1': 'agent_push_allowed',
      '3': 22,
      '4': 1,
      '5': 8,
      '10': 'agentPushAllowed'
    },
    {
      '1': 'preview_available',
      '3': 23,
      '4': 1,
      '5': 8,
      '10': 'previewAvailable'
    },
    {'1': 'preview_kind', '3': 24, '4': 1, '5': 9, '10': 'previewKind'},
    {'1': 'preview_running', '3': 25, '4': 1, '5': 8, '10': 'previewRunning'},
  ],
};

/// Descriptor for `Project`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List projectDescriptor = $convert.base64Decode(
    'CgdQcm9qZWN0Eh0KCnByb2plY3RfaWQYASABKAlSCXByb2plY3RJZBIhCgxkaXNwbGF5X25hbW'
    'UYAiABKAlSC2Rpc3BsYXlOYW1lEjAKBGtpbmQYAyABKA4yHC5yZW1vdGV0ZXN0ZXIudjEuUHJv'
    'amVjdEtpbmRSBGtpbmQSMAoUaW5zdGFsbGFibGVfb25fcGhvbmUYBCABKAhSEmluc3RhbGxhYm'
    'xlT25QaG9uZRIaCghwcm9maWxlcxgFIAMoCVIIcHJvZmlsZXMSJwoPZGVmYXVsdF9wcm9maWxl'
    'GAYgASgJUg5kZWZhdWx0UHJvZmlsZRIdCgpzcGVjX2Vycm9yGAcgASgJUglzcGVjRXJyb3ISMg'
    'oVcGhvbmVfdHJpZ2dlcl9hbGxvd2VkGAggASgIUhNwaG9uZVRyaWdnZXJBbGxvd2VkEjAKFGxh'
    'dW5jaF9hZnRlcl9pbnN0YWxsGAkgASgIUhJsYXVuY2hBZnRlckluc3RhbGwSGgoIYnVpbGRpbm'
    'cYCiABKAhSCGJ1aWxkaW5nEjoKCmxhc3RfcGhhc2UYCyABKA4yGy5yZW1vdGV0ZXN0ZXIudjEu'
    'QnVpbGRQaGFzZVIJbGFzdFBoYXNlEisKEmxhc3RfYnVpbGRfdW5peF9tcxgMIAEoA1IPbGFzdE'
    'J1aWxkVW5peE1zEiYKD2FjdGl2ZV9idWlsZF9pZBgNIAEoCVINYWN0aXZlQnVpbGRJZBIzChZs'
    'YXN0X2FydGlmYWN0X2J1aWxkX2lkGA4gASgJUhNsYXN0QXJ0aWZhY3RCdWlsZElkEikKEHByb2'
    'dyZXNzX3BlcmNlbnQYDyABKAVSD3Byb2dyZXNzUGVyY2VudBInCg9jaGFuZ2VzX3BlbmRpbmcY'
    'ECABKAhSDmNoYW5nZXNQZW5kaW5nEh0KCmFnZW50X25vdGUYESABKAlSCWFnZW50Tm90ZRIrCh'
    'JhZ2VudF9ub3RlX3VuaXhfbXMYEiABKANSD2FnZW50Tm90ZVVuaXhNcxIuChNhZ2VudF9idWls'
    'ZF9hbGxvd2VkGBMgASgIUhFhZ2VudEJ1aWxkQWxsb3dlZBI/CgxpbnN0YWxsX21vZGUYFCABKA'
    '4yHC5yZW1vdGV0ZXN0ZXIudjEuSW5zdGFsbE1vZGVSC2luc3RhbGxNb2RlEjMKFmRlbGl2ZXJz'
    'X3RvX3RoaXNfcGhvbmUYFSABKAhSE2RlbGl2ZXJzVG9UaGlzUGhvbmUSLAoSYWdlbnRfcHVzaF'
    '9hbGxvd2VkGBYgASgIUhBhZ2VudFB1c2hBbGxvd2VkEisKEXByZXZpZXdfYXZhaWxhYmxlGBcg'
    'ASgIUhBwcmV2aWV3QXZhaWxhYmxlEiEKDHByZXZpZXdfa2luZBgYIAEoCVILcHJldmlld0tpbm'
    'QSJwoPcHJldmlld19ydW5uaW5nGBkgASgIUg5wcmV2aWV3UnVubmluZw==');

@$core.Deprecated('Use secretRotationDescriptor instead')
const SecretRotation$json = {
  '1': 'SecretRotation',
  '2': [
    {'1': 'new_secret', '3': 1, '4': 1, '5': 9, '10': 'newSecret'},
  ],
};

/// Descriptor for `SecretRotation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List secretRotationDescriptor = $convert.base64Decode(
    'Cg5TZWNyZXRSb3RhdGlvbhIdCgpuZXdfc2VjcmV0GAEgASgJUgluZXdTZWNyZXQ=');

@$core.Deprecated('Use projectOptionsUpdateDescriptor instead')
const ProjectOptionsUpdate$json = {
  '1': 'ProjectOptionsUpdate',
  '2': [
    {'1': 'project_id', '3': 1, '4': 1, '5': 9, '10': 'projectId'},
    {
      '1': 'launch_after_install',
      '3': 2,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'launchAfterInstall',
      '17': true
    },
    {
      '1': 'install_mode',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.remotetester.v1.InstallMode',
      '9': 1,
      '10': 'installMode',
      '17': true
    },
    {
      '1': 'agent_build_allowed',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'agentBuildAllowed',
      '17': true
    },
    {
      '1': 'deliver_to_this_phone',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'deliverToThisPhone',
      '17': true
    },
    {
      '1': 'agent_push_allowed',
      '3': 6,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'agentPushAllowed',
      '17': true
    },
  ],
  '8': [
    {'1': '_launch_after_install'},
    {'1': '_install_mode'},
    {'1': '_agent_build_allowed'},
    {'1': '_deliver_to_this_phone'},
    {'1': '_agent_push_allowed'},
  ],
};

/// Descriptor for `ProjectOptionsUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List projectOptionsUpdateDescriptor = $convert.base64Decode(
    'ChRQcm9qZWN0T3B0aW9uc1VwZGF0ZRIdCgpwcm9qZWN0X2lkGAEgASgJUglwcm9qZWN0SWQSNQ'
    'oUbGF1bmNoX2FmdGVyX2luc3RhbGwYAiABKAhIAFISbGF1bmNoQWZ0ZXJJbnN0YWxsiAEBEkQK'
    'DGluc3RhbGxfbW9kZRgDIAEoDjIcLnJlbW90ZXRlc3Rlci52MS5JbnN0YWxsTW9kZUgBUgtpbn'
    'N0YWxsTW9kZYgBARIzChNhZ2VudF9idWlsZF9hbGxvd2VkGAQgASgISAJSEWFnZW50QnVpbGRB'
    'bGxvd2VkiAEBEjYKFWRlbGl2ZXJfdG9fdGhpc19waG9uZRgFIAEoCEgDUhJkZWxpdmVyVG9UaG'
    'lzUGhvbmWIAQESMQoSYWdlbnRfcHVzaF9hbGxvd2VkGAYgASgISARSEGFnZW50UHVzaEFsbG93'
    'ZWSIAQFCFwoVX2xhdW5jaF9hZnRlcl9pbnN0YWxsQg8KDV9pbnN0YWxsX21vZGVCFgoUX2FnZW'
    '50X2J1aWxkX2FsbG93ZWRCGAoWX2RlbGl2ZXJfdG9fdGhpc19waG9uZUIVChNfYWdlbnRfcHVz'
    'aF9hbGxvd2Vk');

@$core.Deprecated('Use projectListDescriptor instead')
const ProjectList$json = {
  '1': 'ProjectList',
  '2': [
    {
      '1': 'projects',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.remotetester.v1.Project',
      '10': 'projects'
    },
  ],
};

/// Descriptor for `ProjectList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List projectListDescriptor = $convert.base64Decode(
    'CgtQcm9qZWN0TGlzdBI0Cghwcm9qZWN0cxgBIAMoCzIYLnJlbW90ZXRlc3Rlci52MS5Qcm9qZW'
    'N0Ughwcm9qZWN0cw==');

@$core.Deprecated('Use buildRequestDescriptor instead')
const BuildRequest$json = {
  '1': 'BuildRequest',
  '2': [
    {'1': 'project_id', '3': 1, '4': 1, '5': 9, '10': 'projectId'},
    {'1': 'profile', '3': 2, '4': 1, '5': 9, '10': 'profile'},
  ],
};

/// Descriptor for `BuildRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buildRequestDescriptor = $convert.base64Decode(
    'CgxCdWlsZFJlcXVlc3QSHQoKcHJvamVjdF9pZBgBIAEoCVIJcHJvamVjdElkEhgKB3Byb2ZpbG'
    'UYAiABKAlSB3Byb2ZpbGU=');

@$core.Deprecated('Use buildEventDescriptor instead')
const BuildEvent$json = {
  '1': 'BuildEvent',
  '2': [
    {'1': 'build_id', '3': 1, '4': 1, '5': 9, '10': 'buildId'},
    {
      '1': 'phase',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.remotetester.v1.BuildPhase',
      '10': 'phase'
    },
    {'1': 'log_line', '3': 3, '4': 1, '5': 9, '10': 'logLine'},
    {'1': 'progress_percent', '3': 4, '4': 1, '5': 5, '10': 'progressPercent'},
    {'1': 'queue_position', '3': 5, '4': 1, '5': 5, '10': 'queuePosition'},
  ],
};

/// Descriptor for `BuildEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buildEventDescriptor = $convert.base64Decode(
    'CgpCdWlsZEV2ZW50EhkKCGJ1aWxkX2lkGAEgASgJUgdidWlsZElkEjEKBXBoYXNlGAIgASgOMh'
    'sucmVtb3RldGVzdGVyLnYxLkJ1aWxkUGhhc2VSBXBoYXNlEhkKCGxvZ19saW5lGAMgASgJUgds'
    'b2dMaW5lEikKEHByb2dyZXNzX3BlcmNlbnQYBCABKAVSD3Byb2dyZXNzUGVyY2VudBIlCg5xdW'
    'V1ZV9wb3NpdGlvbhgFIAEoBVINcXVldWVQb3NpdGlvbg==');

@$core.Deprecated('Use buildIdDescriptor instead')
const BuildId$json = {
  '1': 'BuildId',
  '2': [
    {'1': 'build_id', '3': 1, '4': 1, '5': 9, '10': 'buildId'},
  ],
};

/// Descriptor for `BuildId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buildIdDescriptor =
    $convert.base64Decode('CgdCdWlsZElkEhkKCGJ1aWxkX2lkGAEgASgJUgdidWlsZElk');

@$core.Deprecated('Use ackDescriptor instead')
const Ack$json = {
  '1': 'Ack',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `Ack`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ackDescriptor = $convert.base64Decode(
    'CgNBY2sSGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCgdtZXNzYWdlGAIgASgJUgdtZXNzYW'
    'dl');

@$core.Deprecated('Use artifactRequestDescriptor instead')
const ArtifactRequest$json = {
  '1': 'ArtifactRequest',
  '2': [
    {'1': 'build_id', '3': 1, '4': 1, '5': 9, '10': 'buildId'},
    {
      '1': 'resume_from_byte_offset',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'resumeFromByteOffset'
    },
  ],
};

/// Descriptor for `ArtifactRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List artifactRequestDescriptor = $convert.base64Decode(
    'Cg9BcnRpZmFjdFJlcXVlc3QSGQoIYnVpbGRfaWQYASABKAlSB2J1aWxkSWQSNQoXcmVzdW1lX2'
    'Zyb21fYnl0ZV9vZmZzZXQYAiABKANSFHJlc3VtZUZyb21CeXRlT2Zmc2V0');

@$core.Deprecated('Use deltaRequestDescriptor instead')
const DeltaRequest$json = {
  '1': 'DeltaRequest',
  '2': [
    {'1': 'build_id', '3': 1, '4': 1, '5': 9, '10': 'buildId'},
    {'1': 'base_sha256', '3': 2, '4': 1, '5': 9, '10': 'baseSha256'},
    {
      '1': 'resume_from_byte_offset',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'resumeFromByteOffset'
    },
  ],
};

/// Descriptor for `DeltaRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deltaRequestDescriptor = $convert.base64Decode(
    'CgxEZWx0YVJlcXVlc3QSGQoIYnVpbGRfaWQYASABKAlSB2J1aWxkSWQSHwoLYmFzZV9zaGEyNT'
    'YYAiABKAlSCmJhc2VTaGEyNTYSNQoXcmVzdW1lX2Zyb21fYnl0ZV9vZmZzZXQYAyABKANSFHJl'
    'c3VtZUZyb21CeXRlT2Zmc2V0');

@$core.Deprecated('Use chunkDescriptor instead')
const Chunk$json = {
  '1': 'Chunk',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {'1': 'offset', '3': 2, '4': 1, '5': 3, '10': 'offset'},
    {'1': 'is_last', '3': 3, '4': 1, '5': 8, '10': 'isLast'},
    {'1': 'sha256_full_file', '3': 4, '4': 1, '5': 9, '10': 'sha256FullFile'},
    {'1': 'total_size', '3': 5, '4': 1, '5': 3, '10': 'totalSize'},
    {'1': 'target_sha256', '3': 6, '4': 1, '5': 9, '10': 'targetSha256'},
    {'1': 'target_size', '3': 7, '4': 1, '5': 3, '10': 'targetSize'},
  ],
};

/// Descriptor for `Chunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chunkDescriptor = $convert.base64Decode(
    'CgVDaHVuaxISCgRkYXRhGAEgASgMUgRkYXRhEhYKBm9mZnNldBgCIAEoA1IGb2Zmc2V0EhcKB2'
    'lzX2xhc3QYAyABKAhSBmlzTGFzdBIoChBzaGEyNTZfZnVsbF9maWxlGAQgASgJUg5zaGEyNTZG'
    'dWxsRmlsZRIdCgp0b3RhbF9zaXplGAUgASgDUgl0b3RhbFNpemUSIwoNdGFyZ2V0X3NoYTI1Nh'
    'gGIAEoCVIMdGFyZ2V0U2hhMjU2Eh8KC3RhcmdldF9zaXplGAcgASgDUgp0YXJnZXRTaXpl');

@$core.Deprecated('Use deliveryDescriptor instead')
const Delivery$json = {
  '1': 'Delivery',
  '2': [
    {'1': 'build_id', '3': 1, '4': 1, '5': 9, '10': 'buildId'},
    {'1': 'project_id', '3': 2, '4': 1, '5': 9, '10': 'projectId'},
    {'1': 'project_name', '3': 3, '4': 1, '5': 9, '10': 'projectName'},
    {'1': 'size_bytes', '3': 4, '4': 1, '5': 3, '10': 'sizeBytes'},
    {'1': 'sha256', '3': 5, '4': 1, '5': 9, '10': 'sha256'},
    {
      '1': 'install',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.remotetester.v1.InstallMode',
      '10': 'install'
    },
    {'1': 'launch', '3': 7, '4': 1, '5': 8, '10': 'launch'},
    {'1': 'built_unix_ms', '3': 8, '4': 1, '5': 3, '10': 'builtUnixMs'},
    {'1': 'method_id', '3': 9, '4': 1, '5': 9, '10': 'methodId'},
  ],
};

/// Descriptor for `Delivery`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deliveryDescriptor = $convert.base64Decode(
    'CghEZWxpdmVyeRIZCghidWlsZF9pZBgBIAEoCVIHYnVpbGRJZBIdCgpwcm9qZWN0X2lkGAIgAS'
    'gJUglwcm9qZWN0SWQSIQoMcHJvamVjdF9uYW1lGAMgASgJUgtwcm9qZWN0TmFtZRIdCgpzaXpl'
    'X2J5dGVzGAQgASgDUglzaXplQnl0ZXMSFgoGc2hhMjU2GAUgASgJUgZzaGEyNTYSNgoHaW5zdG'
    'FsbBgGIAEoDjIcLnJlbW90ZXRlc3Rlci52MS5JbnN0YWxsTW9kZVIHaW5zdGFsbBIWCgZsYXVu'
    'Y2gYByABKAhSBmxhdW5jaBIiCg1idWlsdF91bml4X21zGAggASgDUgtidWlsdFVuaXhNcxIbCg'
    'ltZXRob2RfaWQYCSABKAlSCG1ldGhvZElk');

@$core.Deprecated('Use deliveryEventDescriptor instead')
const DeliveryEvent$json = {
  '1': 'DeliveryEvent',
  '2': [
    {
      '1': 'delivery',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.remotetester.v1.Delivery',
      '9': 0,
      '10': 'delivery'
    },
    {
      '1': 'heartbeat_unix_ms',
      '3': 2,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'heartbeatUnixMs'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `DeliveryEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deliveryEventDescriptor = $convert.base64Decode(
    'Cg1EZWxpdmVyeUV2ZW50EjcKCGRlbGl2ZXJ5GAEgASgLMhkucmVtb3RldGVzdGVyLnYxLkRlbG'
    'l2ZXJ5SABSCGRlbGl2ZXJ5EiwKEWhlYXJ0YmVhdF91bml4X21zGAIgASgDSABSD2hlYXJ0YmVh'
    'dFVuaXhNc0IHCgVldmVudA==');

@$core.Deprecated('Use previewRequestDescriptor instead')
const PreviewRequest$json = {
  '1': 'PreviewRequest',
  '2': [
    {'1': 'project_id', '3': 1, '4': 1, '5': 9, '10': 'projectId'},
  ],
};

/// Descriptor for `PreviewRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List previewRequestDescriptor = $convert.base64Decode(
    'Cg5QcmV2aWV3UmVxdWVzdBIdCgpwcm9qZWN0X2lkGAEgASgJUglwcm9qZWN0SWQ=');

@$core.Deprecated('Use previewEventDescriptor instead')
const PreviewEvent$json = {
  '1': 'PreviewEvent',
  '2': [
    {
      '1': 'state',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.remotetester.v1.PreviewState',
      '10': 'state'
    },
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'log_line', '3': 3, '4': 1, '5': 9, '10': 'logLine'},
    {'1': 'reload', '3': 4, '4': 1, '5': 8, '10': 'reload'},
    {'1': 'message', '3': 5, '4': 1, '5': 9, '10': 'message'},
    {'1': 'pinned_tls', '3': 6, '4': 1, '5': 8, '10': 'pinnedTls'},
  ],
};

/// Descriptor for `PreviewEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List previewEventDescriptor = $convert.base64Decode(
    'CgxQcmV2aWV3RXZlbnQSMwoFc3RhdGUYASABKA4yHS5yZW1vdGV0ZXN0ZXIudjEuUHJldmlld1'
    'N0YXRlUgVzdGF0ZRIQCgN1cmwYAiABKAlSA3VybBIZCghsb2dfbGluZRgDIAEoCVIHbG9nTGlu'
    'ZRIWCgZyZWxvYWQYBCABKAhSBnJlbG9hZBIYCgdtZXNzYWdlGAUgASgJUgdtZXNzYWdlEh0KCn'
    'Bpbm5lZF90bHMYBiABKAhSCXBpbm5lZFRscw==');

@$core.Deprecated('Use previewIssueDescriptor instead')
const PreviewIssue$json = {
  '1': 'PreviewIssue',
  '2': [
    {'1': 'project_id', '3': 1, '4': 1, '5': 9, '10': 'projectId'},
    {'1': 'note', '3': 2, '4': 1, '5': 9, '10': 'note'},
    {'1': 'page_url', '3': 3, '4': 1, '5': 9, '10': 'pageUrl'},
    {'1': 'console', '3': 4, '4': 3, '5': 9, '10': 'console'},
    {'1': 'user_agent', '3': 5, '4': 1, '5': 9, '10': 'userAgent'},
    {'1': 'viewport_width', '3': 6, '4': 1, '5': 5, '10': 'viewportWidth'},
    {'1': 'viewport_height', '3': 7, '4': 1, '5': 5, '10': 'viewportHeight'},
  ],
};

/// Descriptor for `PreviewIssue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List previewIssueDescriptor = $convert.base64Decode(
    'CgxQcmV2aWV3SXNzdWUSHQoKcHJvamVjdF9pZBgBIAEoCVIJcHJvamVjdElkEhIKBG5vdGUYAi'
    'ABKAlSBG5vdGUSGQoIcGFnZV91cmwYAyABKAlSB3BhZ2VVcmwSGAoHY29uc29sZRgEIAMoCVIH'
    'Y29uc29sZRIdCgp1c2VyX2FnZW50GAUgASgJUgl1c2VyQWdlbnQSJQoOdmlld3BvcnRfd2lkdG'
    'gYBiABKAVSDXZpZXdwb3J0V2lkdGgSJwoPdmlld3BvcnRfaGVpZ2h0GAcgASgFUg52aWV3cG9y'
    'dEhlaWdodA==');
