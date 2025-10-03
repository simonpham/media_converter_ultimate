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
    required int threadCount,
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
      if (formatEntry.shouldAddToArgs) '-f ${formatEntry.name}',
      ?switch (threadCount) {
        final int count when count > 0 => '-threads $threadCount',
        _ => null,
      },
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
    required int threadCount,
  }) {
    final args = buildArgs(
      inputFilePath: inputFilePath,
      formatEntry: formatEntry,
      selectedValues: selectedValues,
      availableControls: availableControls,
      threadCount: threadCount,
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
    try {
      final valueAsList = List<String>.from(jsonDecode(value));
      args.addAll(valueAsList);
      return;
    } catch (_) {}

    args.add(value);
  }
}
