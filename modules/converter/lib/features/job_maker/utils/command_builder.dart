import 'package:converter/converter.dart';
import 'package:utils/utils.dart' as utils;

/// Utility class for building FFmpeg command arguments and full command strings.
class CommandBuilder {
  /// Builds the list of FFmpeg arguments for a given file, output format, and configuration.
  static List<String> buildArgs({
    required String inputFilePath,
    required OutputFormat outputFormat,
    required BaseOutputConfiguration outputConfig,
    required String outputFilePath,
  }) {
    final recommendedArgs = <String>[];

    // Helper functions to check if codecs/trim are set in config
    bool hasAudioCodec() =>
        outputConfig is AudioOutputConfiguration &&
        (outputConfig.audioCodec != null &&
            outputConfig.audioCodec!.isNotEmpty);
    bool hasTrimSilence() =>
        outputConfig is AudioOutputConfiguration && outputConfig.trimSilence;
    bool hasVideoCodec() =>
        outputConfig is VideoOutputConfiguration &&
        (outputConfig.videoCodec != null &&
            outputConfig.videoCodec!.isNotEmpty);
    bool hasCombinedAudioCodec() =>
        outputConfig is CombinedOutputConfiguration &&
        outputConfig.audioConfig != null &&
        outputConfig.audioConfig!.audioCodec != null &&
        outputConfig.audioConfig!.audioCodec!.isNotEmpty;
    bool hasCombinedTrimSilence() =>
        outputConfig is CombinedOutputConfiguration &&
        outputConfig.audioConfig != null &&
        outputConfig.audioConfig!.trimSilence;
    bool hasCombinedVideoCodec() =>
        outputConfig is CombinedOutputConfiguration &&
        outputConfig.videoConfig != null &&
        outputConfig.videoConfig!.videoCodec != null &&
        outputConfig.videoConfig!.videoCodec!.isNotEmpty;

    // Add recommended args based on output type, avoiding redundancy
    if (outputFormat.type == OutputFormatType.audio) {
      recommendedArgs.addAll([
        '-hide_banner',
        '-map_metadata 0:g',
        '-map 0:a',
      ]);
      // Add correct default codec for each audio format if not set
      if (!hasAudioCodec() && !hasCombinedAudioCodec()) {
        switch (outputFormat) {
          case OutputFormat.mp3:
            recommendedArgs.addAll(['-c:a', 'libmp3lame']);
            break;
          case OutputFormat.wav:
            recommendedArgs.addAll(['-c:a', 'pcm_s16le']);
            break;
          case OutputFormat.aac:
            recommendedArgs.addAll(['-c:a', 'aac']);
            break;
          case OutputFormat.flac:
            recommendedArgs.addAll(['-c:a', 'flac']);
            break;
          case OutputFormat.ogg:
            recommendedArgs.addAll(['-c:a', 'libvorbis']);
            break;
          default:
            break;
        }
      }
      if (!hasTrimSilence() && !hasCombinedTrimSilence()) {
        recommendedArgs.addAll(['-af', 'silenceremove=1:0:-50dB:1:1:-50dB']);
      }
    } else if (outputFormat.type == OutputFormatType.video) {
      recommendedArgs.addAll([
        '-hide_banner',
        '-map_metadata 0:g',
        '-map 0:v',
        "-map '0:a?'",
        "-map '0:s?'",
      ]);
      // Add correct default codec for each video format if not set
      if (!hasVideoCodec() && !hasCombinedVideoCodec()) {
        switch (outputFormat) {
          case OutputFormat.mp4:
            recommendedArgs.addAll(['-c:v', 'libx264']);
            break;
          case OutputFormat.mov:
            recommendedArgs.addAll(['-c:v', 'prores']);
            break;
          case OutputFormat.mkv:
            recommendedArgs.addAll(['-c:v', 'libx264']);
            break;
          case OutputFormat.webm:
            recommendedArgs.addAll(['-c:v', 'vp9']);
            break;
          case OutputFormat.avi:
            recommendedArgs.addAll(['-c:v', 'mpeg4']);
            break;
          default:
            break;
        }
      }
      // Add default audio codec for video if not set
      if (!hasAudioCodec() && !hasCombinedAudioCodec()) {
        switch (outputFormat) {
          case OutputFormat.mp4:
          case OutputFormat.mov:
          case OutputFormat.mkv:
          case OutputFormat.avi:
            recommendedArgs.addAll(['-c:a', 'aac']);
            break;
          case OutputFormat.webm:
            recommendedArgs.addAll(['-c:a', 'libvorbis']);
            break;
          default:
            break;
        }
      }
      // Subtitle codec is rarely set in config, so it's safe to add
      recommendedArgs.addAll(['-c:s', 'srt']);
    }

    return [
      '-i',
      '"$inputFilePath"',
      ...recommendedArgs,
      outputFormat.getCommand(),
      ...outputConfig.toArgs(),
      '"$outputFilePath"',
    ];
  }

  /// Builds the full FFmpeg command string for a given file, output format, and configuration.
  static String buildCommand({
    required String inputFilePath,
    required OutputFormat outputFormat,
    required BaseOutputConfiguration outputConfig,
    required String outputFilePath,
  }) {
    final args = buildArgs(
      inputFilePath: inputFilePath,
      outputFormat: outputFormat,
      outputConfig: outputConfig,
      outputFilePath: outputFilePath,
    );
    return args.join(' ');
  }

  /// Utility to get the output file name for a given input file and format.
  static String getOutputFileName({
    required String inputFilePath,
    required OutputFormat outputFormat,
    String? overrideFileName,
  }) {
    final base = utils
        .basenameWithoutExtension(inputFilePath)
        .replaceAll(RegExp(r'\s+'), '_');
    final ext = outputFormat.fileExtension;
    return '$base.$ext';
  }

  static String getOutputFilePath({
    required String inputFilePath,
    required OutputFormat outputFormat,
    required String outputDirectoryPath,
    String? overrideFileName,
  }) {
    return utils.join(
      outputDirectoryPath,
      getOutputFileName(
        inputFilePath: inputFilePath,
        outputFormat: outputFormat,
        overrideFileName: overrideFileName,
      ),
    );
  }
}
