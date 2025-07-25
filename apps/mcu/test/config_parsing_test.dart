import 'dart:convert';
import 'dart:io';

import 'package:core/models/config/config_control.dart';

import 'package:core/models/config/format_config_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Config Parsing', () {
    test('Parse format.json with FormatConfigModel', () async {
      // Load format.json
      final formatFile = File('assets/configs/format.json');
      expect(
        await formatFile.exists(),
        isTrue,
        reason: 'format.json must exist',
      );
      final formatJson =
          jsonDecode(await formatFile.readAsString()) as Map<String, dynamic>;

      // Parse using FormatConfigModel
      final formatConfigModel = FormatConfigModel.fromJson(formatJson);

      // Check formats
      expect(formatConfigModel.formats, isA<List>());
      expect(formatConfigModel.formats.length, greaterThan(0));
      for (final entry in formatConfigModel.formats) {
        expect(entry.name, isNotEmpty);
        expect(entry.outputExtension, isNotEmpty);
        expect(entry.outputType, isNotEmpty);
      }

      // Check supportedCodec
      expect(formatConfigModel.supportedCodec, isA<Map>());
      expect(formatConfigModel.supportedCodec.keys.length, greaterThan(0));
      for (final codecs in formatConfigModel.supportedCodec.values) {
        expect(codecs, isA<List>());
      }

      // Check uiGradients
      expect(formatConfigModel.uiGradients, isA<Map>());
      expect(formatConfigModel.uiGradients.keys.length, greaterThan(0));
      for (final gradient in formatConfigModel.uiGradients.values) {
        expect(gradient, isNotNull);
        expect(gradient.colors.length, greaterThan(1));
      }
    });

    test('Parse mp3.json and common.json configurations', () async {
      // Try parsing a configuration file for one format (e.g., mp3)
      final mp3ConfigFile = File(
        'assets/configs/supported_configurations/mp3.json',
      );
      expect(
        await mp3ConfigFile.exists(),
        isTrue,
        reason: 'mp3.json must exist',
      );
      final mp3ConfigJson =
          jsonDecode(await mp3ConfigFile.readAsString())
              as Map<String, dynamic>;

      // Parse using ConfigModel
      final mp3ConfigModel = ConfigControl.fromJson(mp3ConfigJson);
      expect(mp3ConfigModel.key, equals('mp3'));
      expect(mp3ConfigModel.groups, isA<List<ConfigOptionGroup>>());
      expect(mp3ConfigModel.groups.length, greaterThan(0));

      // Check that each group has options
      for (final group in mp3ConfigModel.groups) {
        expect(group.options, isA<List>());
        expect(group.options.length, greaterThan(0));
        // Check that each option has a label
        for (final option in group.options) {
          expect(option.label, isNotEmpty);
        }
      }

      // Try parsing the common configuration
      final commonConfigFile = File(
        'assets/configs/supported_configurations/common.json',
      );
      expect(
        await commonConfigFile.exists(),
        isTrue,
        reason: 'common.json must exist',
      );
      final commonConfigJson =
          jsonDecode(await commonConfigFile.readAsString())
              as Map<String, dynamic>;
      final commonConfigModel = ConfigControl.fromJson(commonConfigJson);
      expect(commonConfigModel.key, equals('common'));
      expect(commonConfigModel.groups, isA<List<ConfigOptionGroup>>());
      expect(commonConfigModel.groups.length, greaterThan(0));
    });
  });
}
