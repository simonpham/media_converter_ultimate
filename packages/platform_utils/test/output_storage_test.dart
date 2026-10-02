import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temporary;
  late File source;
  late DirectFileService files;
  final calls = <MethodCall>[];

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('mcu-output-test-');
    source = await File('${temporary.path}/source.wav')
        .writeAsString('converted bytes');
    files = DirectFileService(isAndroid: true);
    calls.clear();
    messenger.setMockMethodCallHandler(AndroidOutputStorage.channel, (
      call,
    ) async {
      calls.add(call);
      return switch (call.method) {
        'capabilities' => {'downloads': true},
        'pickTree' => null,
        'export' => {
          'uri': 'content://media/external/downloads/42',
          'name': 'actual.wav',
        },
        'exists' => true,
        'contains' => false,
        _ => null,
      };
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(AndroidOutputStorage.channel, null);
    await temporary.delete(recursive: true);
  });

  test('labelled tree identifiers preserve opaque URIs and Unicode names', () {
    const uri = 'content://provider/tree/primary%3AMusic%2FVi%E1%BB%87t';
    final value = OutputDestination.tree(uri, 'Music & Việt');
    final decoded = OutputDestination.parse(value);
    expect(decoded.kind, OutputDestinationKind.tree);
    expect(decoded.location, uri);
    expect(decoded.label, 'Music & Việt');
    expect(
      OutputDestination.parse('/old/output').kind,
      OutputDestinationKind.directory,
    );
    expect(
      OutputDestination.parse(OutputDestination.downloads).location,
      'downloads',
    );
    expect(
      () => OutputDestination.parse('mcu-output://tree?uri=/fake/path'),
      throwsFormatException,
    );
  });

  test('modern Downloads does not require a filesystem directory', () async {
    expect(await files.getDownloadsDestination(), OutputDestination.downloads);
    expect(calls.single.method, 'capabilities');
  });

  test('cancellation is distinct from an unavailable picker', () async {
    expect(await files.chooseSavePath(null), (null, null));
    messenger.setMockMethodCallHandler(AndroidOutputStorage.channel, (_) async {
      throw PlatformException(code: 'picker_unavailable');
    });
    final (selected, failure) = await files.chooseSavePath(null);
    expect(selected, isNull);
    expect(failure, isA<OutputFolderPickerUnavailableFailure>());
  });

  test('tree URI is used for initial folder and collision checks', () async {
    const uri = 'content://provider/tree/music';
    final destination = OutputDestination.tree(uri, 'Music');
    await files.chooseSavePath(null, initialPath: destination);
    expect(calls.last.arguments, {'initialUri': uri});
    expect(await files.outputExists(destination, 'song.wav'), isFalse);
    expect(calls.last.arguments, {'destination': uri, 'name': 'song.wav'});
  });

  test('successful export retains source until the caller commits', () async {
    final (exported, failure) = await files.exportFile(
      exportId: 'job-42',
      source: source.path,
      destination: OutputDestination.downloads,
      name: 'requested.wav',
    );
    expect(failure, isNull);
    expect(exported!.location, 'content://media/external/downloads/42');
    expect(exported.name, 'actual.wav');
    expect(await source.readAsString(), 'converted bytes');
    expect(calls.map((call) => call.method), ['export']);
    await files.acknowledgeExport('job-42');
    expect(calls.last.arguments, {'id': 'job-42'});
  });

  test(
    'revoked access preserves conversion and provides a specific failure',
    () async {
      messenger.setMockMethodCallHandler(AndroidOutputStorage.channel, (
        _,
      ) async {
        throw PlatformException(code: 'access_expired');
      });
      final (exported, failure) = await files.exportFile(
        exportId: 'job',
        source: source.path,
        destination: OutputDestination.tree(
          'content://provider/tree/music',
          'Music',
        ),
        name: 'song.wav',
      );
      expect(exported, isNull);
      expect(failure, isA<OutputFolderAccessExpiredFailure>());
      expect(await source.readAsString(), 'converted bytes');
      expect(
        () => files.outputExists(
          OutputDestination.tree('content://provider/tree/music', 'Music'),
          'song.wav',
        ),
        throwsA(isA<OutputFolderAccessExpiredFailure>()),
      );
    },
  );

  test(
    'provider outputs use URI-aware exists, delete and share operations',
    () async {
      const uri = 'content://media/external/downloads/42';
      expect(await files.isFileExist(uri), isTrue);
      await files.openOutput(uri);
      await files.shareOutput(uri);
      await files.deleteOutput(uri);
      expect(calls.map((call) => call.method), [
        'exists',
        'open',
        'share',
        'delete',
      ]);
      expect(
        calls.every((call) => (call.arguments as Map)['uri'] == uri),
        isTrue,
      );
    },
  );

  test(
    'legacy directory export preserves stage and refuses overwrite',
    () async {
      final local = DirectFileService(isAndroid: false);
      final (exported, failure) = await local.exportFile(
        exportId: 'legacy',
        source: source.path,
        destination: '${temporary.path}/output',
        name: 'song.wav',
      );
      expect(failure, isNull);
      expect(await source.exists(), isTrue);
      expect(await File(exported!.location).readAsString(), 'converted bytes');
      await source.writeAsString('new bytes');
      final (_, collision) = await local.exportFile(
        exportId: 'collision',
        source: source.path,
        destination: '${temporary.path}/output',
        name: 'song.wav',
      );
      expect(collision, isA<OutputFileAlreadyExistsFailure>());
      expect(await File(exported.location).readAsString(), 'converted bytes');
      expect(await source.readAsString(), 'new bytes');
    },
  );

  test(
    'Android file actions grant native URI access for local output paths',
    () async {
      await files.openOutput(source.path);
      await files.shareOutput(source.path);
      expect(calls.map((call) => call.method), ['open', 'share']);
      expect(calls.map((call) => (call.arguments as Map)['uri']), [
        source.path,
        source.path,
      ]);
      expect(await source.readAsString(), 'converted bytes');
    },
  );
}
