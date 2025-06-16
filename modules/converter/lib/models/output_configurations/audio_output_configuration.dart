import 'package:converter/models/output_configurations/base_output_configuration.dart';
import 'package:utils/some.dart';

/// Audio-specific FFmpeg output configuration.
class AudioOutputConfiguration extends BaseOutputConfiguration {
  final String? audioCodec;
  final String? audioBitrate;
  final int? audioSampleRate;
  final int? audioChannels;
  final double? audioVolume;
  final bool trimSilence;

  const AudioOutputConfiguration({
    super.overwrite,
    super.startTime,
    super.duration,
    super.extraArgs,
    this.audioCodec,
    this.audioBitrate,
    this.audioSampleRate,
    this.audioChannels,
    this.audioVolume,
    this.trimSilence = false,
  });

  @override
  AudioOutputConfiguration copyWith({
    Some<String?>? audioCodec,
    Some<String?>? audioBitrate,
    Some<int?>? audioSampleRate,
    Some<int?>? audioChannels,
    Some<double?>? audioVolume,
    Some<bool?>? trimSilence,
    Some<bool?>? overwrite,
    Some<String?>? startTime,
    Some<String?>? duration,
    Some<List<String>>? extraArgs,
  }) {
    return AudioOutputConfiguration(
      overwrite: overwrite != null
          ? overwrite.value ?? this.overwrite
          : this.overwrite,
      startTime: startTime != null ? startTime.value : this.startTime,
      duration: duration != null ? duration.value : this.duration,
      extraArgs: extraArgs != null ? extraArgs.value : this.extraArgs,
      audioCodec: audioCodec != null ? audioCodec.value : this.audioCodec,
      audioBitrate: audioBitrate != null
          ? audioBitrate.value
          : this.audioBitrate,
      audioSampleRate: audioSampleRate != null
          ? audioSampleRate.value
          : this.audioSampleRate,
      audioChannels: audioChannels != null
          ? audioChannels.value
          : this.audioChannels,
      audioVolume: audioVolume != null ? audioVolume.value : this.audioVolume,
      trimSilence: trimSilence != null
          ? (trimSilence.value ?? this.trimSilence)
          : this.trimSilence,
    );
  }

  @override
  List<String> toArgs() {
    final args = super.toArgs();
    if (audioCodec != null) args.addAll(['-c:a', audioCodec!]);
    if (audioBitrate != null) args.addAll(['-b:a', audioBitrate!]);
    if (audioSampleRate != null) {
      args.addAll(['-ar', audioSampleRate.toString()]);
    }
    if (audioChannels != null) args.addAll(['-ac', audioChannels.toString()]);
    if (audioVolume != null) {
      args.addAll(['-filter:a', 'volume=$audioVolume']);
    }
    if (trimSilence) args.addAll(['-af', 'silenceremove=1:0:-50dB:1:1:-50dB']);
    return args;
  }
}
