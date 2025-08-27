import 'package:core/core.dart';
import 'package:platform_utils/platform_utils.dart';

extension FfmpegSessionStateMapper on SessionState {
  JobStatus toJobStatus() {
    return switch (this) {
      SessionState.created => JobStatus.ready,
      SessionState.running => JobStatus.running,
      SessionState.failed => JobStatus.failed,
      SessionState.completed => JobStatus.cleaning,
    };
  }
}
