import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionReport {
  const PermissionReport({
    required this.camera,
    required this.microphone,
    required this.storage,
    required this.permanentlyDenied,
  });

  final bool camera;
  final bool microphone;
  final bool storage;
  final bool permanentlyDenied;

  bool get allGranted => camera && microphone && storage;
}

class PermissionService {
  int? _androidSdkInt;

  Future<PermissionReport> check() => _evaluate(request: false);

  Future<PermissionReport> request() => _evaluate(request: true);

  Future<bool> openSettings() => openAppSettings();

  Future<Permission?> _storagePermission() async {
    if (!Platform.isAndroid) return null;
    _androidSdkInt ??= (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    return _androidSdkInt! >= 30
        ? Permission.manageExternalStorage
        : Permission.storage;
  }

  Future<PermissionReport> _evaluate({required bool request}) async {
    final storagePermission = await _storagePermission();
    final statuses = <Permission, PermissionStatus>{};

    if (request) {
      statuses.addAll(
        await [Permission.camera, Permission.microphone].request(),
      );
      if (storagePermission != null) {
        statuses[storagePermission] = await storagePermission.request();
      }
    } else {
      for (final permission in [
        Permission.camera,
        Permission.microphone,
        if (storagePermission != null) storagePermission,
      ]) {
        statuses[permission] = await permission.status;
      }
    }

    bool isGranted(Permission? permission) =>
        permission == null || (statuses[permission]?.isGranted ?? false);

    return PermissionReport(
      camera: isGranted(Permission.camera),
      microphone: isGranted(Permission.microphone),
      storage: isGranted(storagePermission),
      permanentlyDenied: statuses.values.any((s) => s.isPermanentlyDenied),
    );
  }
}
