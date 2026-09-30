import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/services/direct_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporaryDirectory;
  late DirectFileService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'mcu-file-test-',
    );
    service = DirectFileService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temporaryDirectory.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'failed exports can save and reuse a recovery copy without losing bytes',
    () async {
      final original = File('${temporaryDirectory.path}/song.mp3');
      final bytes = List<int>.generate(4096, (index) => index % 256);
      await original.writeAsBytes(bytes);
      final (recoveryPath, failure) = await service
          .copyTempOutputFileToConverted(
            jobId: 'first',
            convertedFilePath: original.path,
          );
      expect(failure, isNull);
      expect(recoveryPath, isNotNull);
      expect(await original.readAsBytes(), bytes);
      expect(await File(recoveryPath!).readAsBytes(), bytes);

      final (reusedPath, retryFailure) = await service
          .copyTempOutputFileToConverted(
            jobId: 'first',
            convertedFilePath: recoveryPath,
          );
      expect(retryFailure, isNull);
      expect(reusedPath, recoveryPath);
      expect(await File(recoveryPath).readAsBytes(), bytes);
    },
  );

  test(
    'export collisions preserve both the existing output and the conversion',
    () async {
      final converted = File('${temporaryDirectory.path}/converted.mp3');
      final output = File('${temporaryDirectory.path}/output/song.mp3');
      await output.parent.create(recursive: true);
      await converted.writeAsString('new-conversion');
      await output.writeAsString('existing-output');
      final failure = await service.moveConvertedFileToPath(
        convertedFilePath: converted.path,
        outputFileName: 'song.mp3',
        outputFilePath: output.parent.path,
      );
      expect(failure, isA<OutputFileAlreadyExistsFailure>());
      expect(await converted.readAsString(), 'new-conversion');
      expect(await output.readAsString(), 'existing-output');
    },
  );

  test('a recovery copy can be exported to another writable folder', () async {
    final original = File('${temporaryDirectory.path}/song.mp3');
    await original.writeAsString('converted-audio');
    final (recoveryPath, _) = await service.copyTempOutputFileToConverted(
      jobId: 'first',
      convertedFilePath: original.path,
    );
    final outputDirectory = Directory('${temporaryDirectory.path}/output');
    final failure = await service.moveConvertedFileToPath(
      convertedFilePath: recoveryPath!,
      outputFileName: 'renamed.mp3',
      outputFilePath: outputDirectory.path,
    );
    expect(failure, isNull);
    expect(
      await File('${outputDirectory.path}/renamed.mp3').readAsString(),
      'converted-audio',
    );
    expect(await File(recoveryPath).exists(), isFalse);
  });
}
