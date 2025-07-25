import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:utils/utils.dart' as utils;

/// Utility class for building FFmpeg command arguments and full command strings.
class CommandBuilder {
  /// Builds the list of FFmpeg arguments for a given file, format entry, and selected config state.
  static List<String> buildArgs({
    required String inputFilePath,
    required FormatEntry formatEntry,
    required Map<String, String> selectedValues,
    required String outputFilePath,
    required Map<String, List<String>> supportedCodec,
  }) {
    final args = <String>[];

    // Add dynamic config args from selectedConfigState
    // selectedValues.forEach((groupName, value) {
    //   if (value is String) {
    //     args.add(groupName);
    //     args.add(value);
    //   } else if (value is List) {
    //     for (final v in value) {
    //       args.add(v.toString());
    //     }
    //   }
    // });

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
    required Map<String, List<String>> supportedCodec,
  }) {
    final args = buildArgs(
      inputFilePath: inputFilePath,
      formatEntry: formatEntry,
      selectedValues: selectedValues,
      outputFilePath: outputFilePath,
      supportedCodec: supportedCodec,
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
}
