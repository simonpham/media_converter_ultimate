import 'package:converter/models/output_configurations/base_output_configuration.dart';
import 'package:utils/utils.dart';

/// Video-specific FFmpeg output configuration.
class VideoOutputConfiguration extends BaseOutputConfiguration {
  final String? videoCodec;
  final String? videoBitrate;
  final double? videoFrameRate;
  final String? videoResolution;
  final String? videoPreset;
  final int? videoCrf;
  final String? videoAspectRatio;
  final String? videoPixelFormat;

  const VideoOutputConfiguration({
    super.overwrite,
    super.startTime,
    super.duration,
    super.extraArgs,
    this.videoCodec,
    this.videoBitrate,
    this.videoFrameRate,
    this.videoResolution,
    this.videoPreset,
    this.videoCrf,
    this.videoAspectRatio,
    this.videoPixelFormat,
  });

  @override
  VideoOutputConfiguration copyWith({
    Some<String?>? videoCodec,
    Some<String?>? videoBitrate,
    Some<double?>? videoFrameRate,
    Some<String?>? videoResolution,
    Some<String?>? videoPreset,
    Some<int?>? videoCrf,
    Some<String?>? videoAspectRatio,
    Some<String?>? videoPixelFormat,
    Some<bool>? overwrite,
    Some<String?>? startTime,
    Some<String?>? duration,
    Some<List<String>>? extraArgs,
  }) {
    return VideoOutputConfiguration(
      videoCodec: videoCodec != null ? videoCodec.value : this.videoCodec,
      videoBitrate: videoBitrate != null
          ? videoBitrate.value
          : this.videoBitrate,
      videoFrameRate: videoFrameRate != null
          ? videoFrameRate.value
          : this.videoFrameRate,
      videoResolution: videoResolution != null
          ? videoResolution.value
          : this.videoResolution,
      videoPreset: videoPreset != null ? videoPreset.value : this.videoPreset,
      videoCrf: videoCrf != null ? videoCrf.value : this.videoCrf,
      videoAspectRatio: videoAspectRatio != null
          ? videoAspectRatio.value
          : this.videoAspectRatio,
      videoPixelFormat: videoPixelFormat != null
          ? videoPixelFormat.value
          : this.videoPixelFormat,
      overwrite: overwrite != null ? overwrite.value : super.overwrite,
      startTime: startTime != null ? startTime.value : super.startTime,
      duration: duration != null ? duration.value : super.duration,
      extraArgs: extraArgs != null ? extraArgs.value : super.extraArgs,
    );
  }

  @override
  List<String> toArgs() {
    final args = super.toArgs();
    if (videoCodec != null) args.addAll(['-c:v', videoCodec!]);
    if (videoBitrate != null) args.addAll(['-b:v', videoBitrate!]);
    if (videoFrameRate != null) args.addAll(['-r', videoFrameRate.toString()]);
    if (videoResolution != null) args.addAll(['-s', videoResolution!]);
    if (videoPreset != null) args.addAll(['-preset', videoPreset!]);
    if (videoCrf != null) args.addAll(['-crf', videoCrf.toString()]);
    if (videoAspectRatio != null) args.addAll(['-aspect', videoAspectRatio!]);
    if (videoPixelFormat != null) args.addAll(['-pix_fmt', videoPixelFormat!]);
    return args;
  }
}
