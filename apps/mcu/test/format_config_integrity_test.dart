import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _findConfigsDir() {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final candidate = Directory('${dir.path}/apps/mcu/assets/configs');
    if (candidate.existsSync()) return candidate;
    final candidateDirect = Directory('${dir.path}/assets/configs');
    if (candidateDirect.existsSync()) return candidateDirect;
    dir = dir.parent;
  }
  throw Exception('Could not locate assets/configs');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Asset Configurations Integrity', () {
    late Directory configsDir;
    late File formatJsonFile;
    late Directory supportedConfigsDir;
    late Directory l10nDir;

    setUpAll(() {
      configsDir = _findConfigsDir();
      formatJsonFile = File('${configsDir.path}/format.json');
      supportedConfigsDir = Directory(
        '${configsDir.path}/supported_configurations',
      );
      l10nDir = Directory('${configsDir.path}/l10n');
    });

    test('format.json contains all 25 formats and valid gradients', () {
      expect(formatJsonFile.existsSync(), isTrue);

      final formatJson =
          jsonDecode(formatJsonFile.readAsStringSync()) as Map<String, dynamic>;
      final formats = (formatJson['format'] as List)
          .cast<Map<String, dynamic>>();
      final gradients = formatJson['ui_gradients'] as Map<String, dynamic>;

      expect(formats.length, 25);
      expect(gradients.length, 25);

      for (final fmt in formats) {
        final name = fmt['name'] as String;
        expect(fmt['output_extension'], isNotEmpty);
        expect(fmt['output_type'], anyOf('audio', 'video'));
        expect(
          gradients.containsKey(name),
          isTrue,
          reason: 'Missing gradient for $name',
        );
      }
    });

    test('all 25 format config files exist in supported_configurations', () {
      final formatJson =
          jsonDecode(formatJsonFile.readAsStringSync()) as Map<String, dynamic>;
      final formats = (formatJson['format'] as List)
          .cast<Map<String, dynamic>>();

      for (final fmt in formats) {
        final name = fmt['name'] as String;
        final configFile = File('${supportedConfigsDir.path}/$name.json');
        expect(
          configFile.existsSync(),
          isTrue,
          reason: 'Missing config file for format: $name.json',
        );

        final configJson =
            jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
        expect(
          configJson.containsKey(name),
          isTrue,
          reason: 'Config file $name.json missing root key "$name"',
        );
      }
    });

    test('all 11 localization files exist and have equal key counts', () {
      final expectedLangs = [
        'de',
        'en',
        'es',
        'id',
        'it',
        'ja',
        'pt',
        'tr',
        'vi',
        'zh',
        'zh_TW',
      ];

      final enJsonFile = File('${l10nDir.path}/en.json');
      expect(enJsonFile.existsSync(), isTrue);
      final enKeys = (jsonDecode(
        enJsonFile.readAsStringSync(),
      ) as Map<String, dynamic>).keys.toSet();

      for (final lang in expectedLangs) {
        final l10nFile = File('${l10nDir.path}/$lang.json');
        expect(
          l10nFile.existsSync(),
          isTrue,
          reason: 'Missing l10n file for $lang.json',
        );

        final langJson =
            jsonDecode(l10nFile.readAsStringSync()) as Map<String, dynamic>;
        final langKeys = langJson.keys.toSet();

        final missingKeys = enKeys.difference(langKeys);
        expect(
          missingKeys,
          isEmpty,
          reason: '$lang.json is missing keys: $missingKeys',
        );
      }
    });
  });
}
