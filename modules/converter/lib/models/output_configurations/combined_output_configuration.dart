import 'package:converter/models/output_configurations/audio_output_configuration.dart';
import 'package:converter/models/output_configurations/base_output_configuration.dart';
import 'package:converter/models/output_configurations/video_output_configuration.dart';
import 'package:utils/some.dart';

/// Combines video and audio output configurations for files that have both streams.
class CombinedOutputConfiguration extends BaseOutputConfiguration {
  final VideoOutputConfiguration? videoConfig;
  final AudioOutputConfiguration? audioConfig;

  const CombinedOutputConfiguration({
    super.overwrite,
    super.startTime,
    super.duration,
    super.extraArgs,
    this.videoConfig,
    this.audioConfig,
  });

  @override
  CombinedOutputConfiguration copyWith({
    Some<bool>? overwrite,
    Some<String?>? startTime,
    Some<String?>? duration,
    Some<List<String>>? extraArgs,
    Some<VideoOutputConfiguration?>? videoConfig,
    Some<AudioOutputConfiguration?>? audioConfig,
  }) {
    return CombinedOutputConfiguration(
      overwrite: overwrite != null ? overwrite.value : this.overwrite,
      startTime: startTime != null ? startTime.value : this.startTime,
      duration: duration != null ? duration.value : this.duration,
      extraArgs: extraArgs != null ? extraArgs.value : this.extraArgs,
      videoConfig: videoConfig != null ? videoConfig.value : this.videoConfig,
      audioConfig: audioConfig != null ? audioConfig.value : this.audioConfig,
    );
  }

  @override
  List<String> toArgs() {
    final args = super.toArgs();
    if (videoConfig != null) args.addAll(videoConfig!.toArgs());
    if (audioConfig != null) args.addAll(audioConfig!.toArgs());
    return args;
  }
}