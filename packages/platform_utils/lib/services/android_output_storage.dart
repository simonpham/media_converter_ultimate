import 'package:core/core.dart';
import 'package:flutter/services.dart';

import 'package:platform_utils/services/output_destination.dart';

class const AndroidOutputStorage() {
  static const channel = MethodChannel('io.sofluffy.mcu/output_storage');

  Future<bool> supportsDownloads() async {
    final result = await channel.invokeMapMethod<String, dynamic>(
      'capabilities',
    );
    return result?['downloads'] == true;
  }

  Future<String?> pickTree(String? initialUri) async {
    final result = await channel.invokeMapMethod<String, dynamic>(
      'pickTree',
      {'initialUri': initialUri},
    );
    if (result == null) return null;
    return OutputDestination.tree(
      result['uri'] as String,
      result['label'] as String,
    );
  }

  Future<ExportedFile> export({
    required String id,
    required String source,
    required String name,
    required String destination,
    String? mime,
  }) async {
    final result = await channel.invokeMapMethod<String, dynamic>('export', {
      'id': id,
      'source': source,
      'name': name,
      'destination': destination,
      'mime': mime,
    });
    if (result == null) throw const FormatException('Missing exported file');
    return .new(
      location: result['uri'] as String,
      name: result['name'] as String,
    );
  }

  Future<ExportedFile?> recover(String id) async {
    final result = await channel.invokeMapMethod<String, dynamic>('recover', {
      'id': id,
    });
    return result == null
        ? null
        : ExportedFile(
            location: result['uri'] as String,
            name: result['name'] as String,
          );
  }

  Future<void> acknowledge(String id) =>
      channel.invokeMethod('acknowledge', {'id': id});
  Future<bool> exists(String uri) async =>
      await channel.invokeMethod<bool>('exists', {'uri': uri}) ?? false;
  Future<bool> contains(String destination, String name) async =>
      await channel.invokeMethod<bool>('contains', {
        'destination': destination,
        'name': name,
      }) ??
      false;
  Future<void> validateTree(String uri) =>
      channel.invokeMethod('validateTree', {'uri': uri});
  Future<void> delete(String uri) =>
      channel.invokeMethod('delete', {'uri': uri});
  Future<void> open(String uri) => channel.invokeMethod('open', {'uri': uri});
  Future<void> share(String uri) => channel.invokeMethod('share', {'uri': uri});

  static Failure failure(PlatformException error, String location) =>
      switch (error.code) {
        'picker_unavailable' => const OutputFolderPickerUnavailableFailure(),
        'access_expired' => const OutputFolderAccessExpiredFailure(),
        'not_writable' => DirectoryNotWritableFailure(location),
        'already_exists' => OutputFileAlreadyExistsFailure(location),
        _ => const OutputExportFailure(),
      };
}
