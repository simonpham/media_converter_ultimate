import 'package:converter/converter.dart';
import 'package:platform_utils/platform_utils.dart';

extension FfmpegSessionStateMapper on SessionState {
  JobStatus toJobStatus() {
    return switch (this) {
      SessionState.created => JobStatus.pending,
      SessionState.running => JobStatus.running,
      SessionState.failed => JobStatus.failed,
      SessionState.completed => JobStatus.completed
    };
  }
}