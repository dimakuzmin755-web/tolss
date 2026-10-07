import 'dart:io';

import 'package:flutter/services.dart';

class InstalledAppInfo {
  const InstalledAppInfo({required this.packageName, required this.label});

  final String packageName;
  final String label;
}

class DestructiveActionService {
  static const MethodChannel _channel =
      MethodChannel('onerule/destructive_actions');

  Future<List<InstalledAppInfo>> listUserApps() async {
    if (!Platform.isAndroid) return const <InstalledAppInfo>[];
    final raw = await _channel.invokeMethod<List<dynamic>>('listUserApps');
    return (raw ?? const <dynamic>[]).map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return InstalledAppInfo(
        packageName: map['packageName'] as String,
        label: map['label'] as String,
      );
    }).toList();
  }

  Future<bool> requestUninstall(String packageName) async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>(
          'requestUninstall',
          <String, dynamic>{'packageName': packageName},
        ) ??
        false;
  }

  Future<bool> requestSelfUninstall() => requestUninstall('com.fidevelopment.onerule');

  Future<List<String>> deleteFiles(Iterable<String> paths) async {
    final failed = <String>[];
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        failed.add(path);
      }
    }
    return failed;
  }
}
