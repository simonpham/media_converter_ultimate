import 'package:core/core.dart';
import 'package:platform_utils/platform_utils.dart';

extension FfmpegSessionStateMapper on SessionState {
  JobStatus toJobStatus({ReturnCode? returnCode}) {
    return switch (this) {
      SessionState.created => JobStatus.ready,
      SessionState.running => JobStatus.running,
      SessionState.failed => JobStatus.failed,
      SessionState.completed when returnCode?.isValueSuccess() == true =>
        JobStatus.cleaning,
      SessionState.completed when returnCode?.isValueCancel() == true =>
        JobStatus.cancelled,
      SessionState.completed => JobStatus.failed,
    };
  }
}
