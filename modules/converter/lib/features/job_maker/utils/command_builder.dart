import 'dart:convert';

import 'package:core/core.dart';
import 'package:utils/utils.dart' as utils;

/// Utility class for building FFmpeg command arguments and full command strings.
class CommandBuilder {
  /// Builds the list of FFmpeg arguments for a given file, format entry, and selected config state.
  static List<String> buildArgs({
    required String inputFilePath,
    required FormatEntry formatEntry,
    required List<ConfigControl> availableControls,
    required Map<String, String> selectedValues,
    required String outputFilePath,
  }) {
    final args = <String>[];

    for (final control in availableControls) {
      if (!control.shouldAddToArgs) {
        continue;
      }

      final selectedValue = selectedValues[control.name];
      if (selectedValue == null || selectedValue.isEmpty) {
        continue;
      }

      final ffmpegFlag = control.ffmpegFlag;
      if (ffmpegFlag == null) {
        printLog(
          '[CommandBuilder]: FFmpeg flag not found. Adding arg directly: $args',
        );
        _addValue(args, selectedValue);
        continue;
      }

      printLog(
        '[CommandBuilder]: Adding flag and arg: $ffmpegFlag $selectedValue',
      );
      args.add(ffmpegFlag);
      _addValue(args, selectedValue);
      continue;
    }

    return [
      '-i',
      '"$inputFilePath"',
      ...args,
      '-f ${formatEntry.name}',
      '"$outputFilePath"',
    ];
  }

  /// Builds the full FFmpeg command string for a given file, format entry, and selected config state.
  static String buildCommand({
    required String inputFilePath,
    required FormatEntry formatEntry,
    required Map<String, String> selectedValues,
    required String outputFilePath,
    required List<ConfigControl> availableControls,
  }) {
    final args = buildArgs(
      inputFilePath: inputFilePath,
      formatEntry: formatEntry,
      selectedValues: selectedValues,
      availableControls: availableControls,
      outputFilePath: outputFilePath,
    );
    return args.join(' ');
  }

  /// Utility to get the output file name for a given input file and format entry.
  static String getOutputFileName({
    required String inputFilePath,
    required FormatEntry formatEntry,
    String? overrideFileName,
  }) {
    final base = utils
        .basenameWithoutExtension(inputFilePath)
        .replaceAll(RegExp(r'\s+'), '_');
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
    try {
      final valueAsList = List<String>.from(jsonDecode(value));
      args.addAll(valueAsList);
      return;
    } catch (_) {}

    args.add(value);
  }
}
