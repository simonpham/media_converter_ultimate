import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final files = DirectFileService();
  const bridge = AndroidOutputStorage();
  late Directory temporary;
  late File output;
  late String readUri;
  final prefix = 'MCU_Open_QA_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> execute(List<String> arguments) async {
    final session = await FFmpegKit.executeWithArguments(arguments);
    expect(
      ReturnCode.isSuccess(await session.getReturnCode()),
      isTrue,
      reason: await session.getAllLogsAsString(),
    );
  }

  setUpAll(() async {
    temporary = await (await files.getAppCacheDirectory()).createTemp(prefix);
    final source = File('${temporary.path}/source.wav');
    await execute([
      '-f',
      'lavfi',
      '-i',
      'sine=duration=1',
      '-c:a',
      'pcm_s16le',
      source.path,
    ]);
    final (exported, failure) = await files.exportFile(
      exportId: prefix,
      source: source.path,
      destination: OutputDestination.appStorage,
      name: '$prefix Việt.wav',
    );
    expect(failure, isNull);
    output = File(exported!.location);
  });

  tearDownAll(() async {
    if (await output.exists()) await output.delete();
    await temporary.delete(recursive: true);
  });

  testWidgets(
    'app-stored output shares a readable exact-file URI without a cache copy',
    (_) async {
      final shareCache = Directory(
        '${(await files.getAppCacheDirectory()).path}/share_plus',
      );
      final cacheExisted = await shareCache.exists();
      readUri = (await bridge.share(output.path))!;
      final uri = Uri.parse(readUri);
      expect(uri.scheme, 'content');
      expect(uri.host, endsWith('.output_files'));
      expect(uri.pathSegments.last, output.uri.pathSegments.last);
      expect(await bridge.share(output.path), readUri);
      expect(await bridge.exists(readUri), isTrue);
      final unknownName = uri.replace(
        pathSegments: [uri.pathSegments.first, 'other.wav'],
      );
      expect(await bridge.exists(unknownName.toString()), isFalse);
      final readable = await FFmpegKitConfig.getSafParameterForRead(readUri);
      expect(readable, isNotNull);
      final copied = File('${temporary.path}/roundtrip.wav');
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
        copied.path,
      ]);
      expect(await copied.readAsBytes(), await output.readAsBytes());
      expect(await shareCache.exists(), cacheExisted);
    },
  );

  testWidgets(
    'attempting a SAF write leaves the registered output unchanged',
    (_) async {
      final original = await output.readAsBytes();
      final writable = await FFmpegKitConfig.getSafParameterForWrite(readUri);
      expect(writable, isNotNull);
      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'sine=duration=0.1',
        '-c:a',
        'pcm_s16le',
        '-f',
        'wav',
        writable!,
      ]);
      await session.getReturnCode();
      // The bundled SAF adapter catches descriptor-open failures and returns 0,
      // so an FFmpeg return code alone does not prove that a write succeeded.
      expect(await output.readAsBytes(), original);
    },
  );

  testWidgets('Open launches a local text output with a readable content URI', (
    _,
  ) async {
    final text = await File('${temporary.path}/$prefix Việt.txt')
        .writeAsString('Owned output actions QA fixture: Việt\n');
    final uri = await bridge.open(text.path);
    expect(uri, isNotNull);
    expect(Uri.parse(uri!).host, endsWith('.output_files'));
    expect(await bridge.exists(uri), isTrue);
    expect(
      await text.readAsString(),
      'Owned output actions QA fixture: Việt\n',
    );
    await text.delete();
    expect(await bridge.exists(uri), isFalse);
  });

  testWidgets('missing files cannot be registered or opened', (_) async {
    await expectLater(
      bridge.open('${temporary.path}/missing.wav'),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      bridge.share('${temporary.path}/missing.wav'),
      throwsA(isA<PlatformException>()),
    );
    await output.delete();
    expect(await files.isFileExist(output.path), isFalse);
    await expectLater(
      bridge.open(output.path),
      throwsA(isA<PlatformException>()),
    );
  });
}
