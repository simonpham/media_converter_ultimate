import 'dart:convert';

import 'package:converter/features/job_maker/utils/conversion_trim.dart';
import 'package:core/core.dart';
import 'package:platform_utils/platform_utils.dart' show FFmpegKitConfig;
import 'package:utils/utils.dart' as utils;

/// Builds literal FFmpeg arguments and persists them without losing filenames.
class CommandBuilder {
  /// Builds the list of FFmpeg arguments for a given file, format entry, and selected config state.
  static List<String> buildArgs({
    required String inputFilePath,
    required FormatEntry formatEntry,
    required List<ConfigControl> availableControls,
    required Map<String, String> selectedValues,
    required String outputFilePath,
    required int threadCount,
    Set<String> configurationKeys = const {},
    ConversionTrim? trim,
  }) {
    final args = <String>[];

    for (final control in availableControls) {
      if (!control.shouldAddToArgs) {
        continue;
      }

      final selectedValue =
          selectedValues[control.name] ?? control.defaultValue;
      if (selectedValue == null || selectedValue.isEmpty) {
        continue;
      }

      final selectedOptions = control.type == .multiChoice
          ? _decodeArray(selectedValue) ?? const <String>[]
          : [selectedValue];
      for (final option in control.options) {
        if (!selectedOptions.contains(option.value)) {
          continue;
        }
        if (option.ffmpegArg case final String argument) {
          _addValue(args, argument);
        } else if (control.ffmpegFlag case final String flag) {
          if (_decodeArray(option.value) != null) {
            _addValue(args, option.value);
          } else {
            args.addAll([flag, option.value]);
          }
        } else if (!configurationKeys.contains(option.value)) {
          _addValue(args, option.value);
        }
      }
    }

    return [
      ...?trim?.inputArguments,
      '-i',
      inputFilePath,
      '-hide_banner',
      ...?trim?.outputArguments,
      ...args,
      if (formatEntry.shouldAddToArgs) ...['-f', formatEntry.name],
      if (threadCount > 0) ...['-threads', '$threadCount'],
      outputFilePath,
    ];
  }

  /// Serializes arguments so quotes, spaces, and Unicode paths survive storage.
  static String buildCommand({
    required String inputFilePath,
    required FormatEntry formatEntry,
    required Map<String, String> selectedValues,
    required String outputFilePath,
    required List<ConfigControl> availableControls,
    required int threadCount,
    Set<String> configurationKeys = const {},
    ConversionTrim? trim,
  }) {
    final args = buildArgs(
      inputFilePath: inputFilePath,
      formatEntry: formatEntry,
      selectedValues: selectedValues,
      availableControls: availableControls,
      threadCount: threadCount,
      outputFilePath: outputFilePath,
      configurationKeys: configurationKeys,
      trim: trim,
    );
    return jsonEncode(args);
  }

  /// Reads new argument arrays and legacy commands from existing job history.
  static List<String> parseCommand(String command) {
    if (command.trimLeft().startsWith('[')) {
      final decoded = jsonDecode(command);
      if (decoded is! List || decoded.any((value) => value is! String)) {
        throw const FormatException('Invalid conversion arguments');
      }
      return decoded.cast<String>();
    }
    return FFmpegKitConfig.parseArguments(command);
  }

  /// Utility to get the output file name for a given input file and format entry.
  static String getOutputFileName({
    required String inputFilePath,
    required FormatEntry formatEntry,
    String? overrideFileName,
  }) {
    if (overrideFileName != null) {
      return overrideFileName;
    }
    final base = utils.basenameWithoutExtension(inputFilePath);
    final ext = formatEntry.outputExtension;
    return '$base.$ext';
  }

  static String getOutputFilePath({
    required String inputFilePath,
    required FormatEntry formatEntry,
    required String outputDirectoryPath,
    String? overrideFileName,
  }) {
    return utils.join(
      outputDirectoryPath,
      getOutputFileName(
        inputFilePath: inputFilePath,
        formatEntry: formatEntry,
        overrideFileName: overrideFileName,
      ),
    );
  }

  static void _addValue(List<String> args, String value) {
    final values = _decodeArray(value) ?? [value];
    for (final argument in values) {
      args.addAll(FFmpegKitConfig.parseArguments(argument));
    }
  }

  static List<String>? _decodeArray(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List && decoded.every((element) => element is String)) {
        return decoded.cast<String>();
      }
    } catch (_) {}
    return null;
  }
}
