import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart' show FileService;

Directory findRepository() {
  var directory = Directory.current;
  while (directory.path != directory.parent.path) {
    if (File('${directory.path}/apps/mcu/assets/configs/format.json')
        .existsSync()) {
      return directory;
    }
    directory = directory.parent;
  }
  throw StateError('Could not locate the application assets');
}

FormatConfigModel loadShippedFormats() => FormatConfigModel.fromJson(
  jsonDecode(
    File('${findRepository().path}/apps/mcu/assets/configs/format.json')
        .readAsStringSync(),
  ),
);

void installShippedAssetHandler({
  Future<void> Function(String)? beforeLoad,
}) {
  rootBundle.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        await beforeLoad?.call(key);
        final root = findRepository().path;
        final path = key.startsWith('packages/icons/')
            ? '$root/packages/icons/${key.substring('packages/icons/'.length)}'
            : '$root/apps/mcu/$key';
        final assetPath = key.startsWith('packages/sofluffy_ui/')
            ? '$root/packages/sofluffy_ui/${key.substring('packages/sofluffy_ui/'.length)}'
            : path;
        final file = File(assetPath);
        if (!file.existsSync()) return null;
        return ByteData.sublistView(file.readAsBytesSync());
      });
}

void clearShippedAssetHandler() {
  rootBundle.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}

class MemorySettings implements SettingsBox {
  final values = <dynamic, dynamic>{};

  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryConfigurations implements JobConfigurationData {
  final values = <dynamic, dynamic>{};

  @override
  Future<void> onDispose() async {}

  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestMediaFiles implements FileService {
  @override
  Future<bool> isMediaFile(File file) async => true;

  @override
  Future<String?> getFileMimeType(File file) async => 'audio/wav';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
