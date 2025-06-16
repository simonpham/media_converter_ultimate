import 'package:utils/some.dart';

/// Base class for common FFmpeg output arguments.
class BaseOutputConfiguration {
  /// Overwrite output files without asking.
  final bool overwrite;

  /// Start time offset (in seconds or time string).
  final String? startTime;

  /// Duration of output (in seconds or time string).
  final String? duration;

  /// Additional custom FFmpeg arguments.
  final List<String> extraArgs;

  const BaseOutputConfiguration({
    this.overwrite = true,
    this.startTime,
    this.duration,
    this.extraArgs = const [],
  });

  BaseOutputConfiguration copyWith({
    Some<bool>? overwrite,
    Some<String?>? startTime,
    Some<String?>? duration,
    Some<List<String>>? extraArgs,
  }) {
    return BaseOutputConfiguration(
      overwrite: overwrite != null ? overwrite.value : this.overwrite,
      startTime: startTime != null ? startTime.value : this.startTime,
      duration: duration != null ? duration.value : this.duration,
      extraArgs: extraArgs != null ? extraArgs.value : this.extraArgs,
    );
  }

  /// Generates FFmpeg command-line arguments for base configuration.
  List<String> toArgs() {
    final args = <String>[];
    if (overwrite) args.add('-y');
    if (startTime != null) args.addAll(['-ss', startTime!]);
    if (duration != null) args.addAll(['-t', duration!]);
    args.addAll(extraArgs);
    return args;
  }
}