import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final files = DirectFileService();
  const bridge = AndroidOutputStorage();
  late Directory temporary;
  final outputs = <String>{};
  final ids = <String>{};
  final prefix = 'MCU_Output_QA_${DateTime.now().microsecondsSinceEpoch}';

  setUpAll(() async {
    temporary = await (await files.getAppCacheDirectory()).createTemp(
      'native_output_qa_',
    );
    expect(await files.getDownloadsDestination(), OutputDestination.downloads);
  });

  tearDownAll(() async {
    for (final uri in outputs) {
      if (await files.isFileExist(uri)) await files.deleteOutput(uri);
    }
    for (final id in ids) {
      await files.acknowledgeExport(id);
    }
    await temporary.delete(recursive: true);
  });

  Future<void> execute(List<String> arguments) async {
    final session = await FFmpegKit.executeWithArguments(arguments);
    expect(
      ReturnCode.isSuccess(await session.getReturnCode()),
      isTrue,
      reason: await session.getAllLogsAsString(),
    );
  }

  Future<ExportedFile> export(File source, String name, String id) async {
    ids.add(id);
    final (output, failure) = await files.exportFile(
      exportId: id,
      source: source.path,
      destination: OutputDestination.downloads,
      name: name,
    );
    expect(failure, isNull);
    expect(output, isNotNull);
    outputs.add(output!.location);
    expect(output.location, startsWith('content://'));
    expect(await files.isFileExist(output.location), isTrue);
    expect(await source.exists(), isTrue);
    return output;
  }

  Future<void> verifyBytes(File source, ExportedFile output) async {
    final readable = await FFmpegKitConfig.getSafParameterForRead(
      output.location,
    );
    expect(readable, isNotNull);
    final copied = '${temporary.path}/roundtrip-${output.name}';
    await execute([
      '-f',
      'data',
      '-i',
      readable!,
      '-map',
      '0',
      '-c',
      'copy',
      '-f',
      'data',
      copied,
    ]);
    expect(await File(copied).readAsBytes(), await source.readAsBytes());
  }

  testWidgets('Downloads audio and video exports preserve exact bytes', (
    _,
  ) async {
    for (final extension in ['wav', 'mp4']) {
      final source = File('${temporary.path}/$prefix.$extension');
      await execute(
        extension == 'wav'
            ? [
                '-f',
                'lavfi',
                '-i',
                'sine=duration=1',
                '-c:a',
                'pcm_s16le',
                source.path,
              ]
            : [
                '-f',
                'lavfi',
                '-i',
                'color=c=blue:s=128x96:d=1',
                '-c:v',
                'libx264',
                '-pix_fmt',
                'yuv420p',
                source.path,
              ],
      );
      final id = '$prefix-$extension';
      final output = await export(source, '$prefix.$extension', id);
      await verifyBytes(source, output);
      await files.acknowledgeExport(id);
    }
  });

  testWidgets('failed streaming removes its pending row and can retry safely', (
    _,
  ) async {
    final source = await File('${temporary.path}/blocked.txt')
        .writeAsString('retained after failed stream');
    final id = '$prefix-blocked';
    final name = '$prefix-blocked.txt';
    ids.add(id);
    expect(
      (await Process.run('/system/bin/chmod', ['000', source.path])).exitCode,
      0,
    );
    try {
      final (output, failure) = await files.exportFile(
        exportId: id,
        source: source.path,
        destination: OutputDestination.downloads,
        name: name,
      );
      expect(output, isNull);
      expect(failure, isA<OutputExportFailure>());
      expect(await bridge.recover(id), isNull);
    } finally {
      expect(
        (await Process.run('/system/bin/chmod', ['600', source.path])).exitCode,
        0,
      );
    }
    expect(await source.readAsString(), 'retained after failed stream');
    final output = await export(source, name, id);
    expect(output.name, name);
    await verifyBytes(source, output);
    await files.acknowledgeExport(id);
  });

  testWidgets(
    'log export and replay recover one published URI without duplicates',
    (_) async {
      final source = await File('${temporary.path}/log.txt')
          .writeAsString('Full log: Việt\nline two\n');
      final id = '$prefix-log';
      final output = await export(source, '$prefix.log.txt', id);
      final replay = await export(source, '$prefix.log.txt', id);
      expect(replay.location, output.location);
      final recovered = await bridge.recover(id);
      expect(recovered!.location, output.location);
      await verifyBytes(source, output);
      await files.acknowledgeExport(id);
      expect(await bridge.recover(id), isNull);
      final (_, collision) = await files.exportFile(
        exportId: '$id-collision',
        source: source.path,
        destination: OutputDestination.downloads,
        name: '$prefix.log.txt',
      );
      expect(collision, isA<OutputFileAlreadyExistsFailure>());
      expect(await source.readAsString(), 'Full log: Việt\nline two\n');
      await files.deleteOutput(output.location);
      expect(await files.isFileExist(output.location), isFalse);
    },
  );
}
