import 'package:core/core.dart';
import 'package:flutter/material.dart';

extension JobStatusExtension on JobStatus {
  bool get isQueued => this == JobStatus.pending;

  bool get isProcessing =>
      this == JobStatus.running ||
      this == JobStatus.preparing ||
      this == JobStatus.ready;

  bool get isDone =>
      this == JobStatus.completed ||
      this == JobStatus.failed ||
      this == JobStatus.cancelled;
}

enum JobStatus {
  pending, // Just created.
  preparing, // Getting media info.
  ready, // Done getting media info.
  running, // FFmpeg session is running.
  completed, // FFmpeg session is completed.
  cancelled, // FFmpeg session is cancelled.
  failed; // FFmpeg session is failed.

  Color getColor() {
    return switch (this) {
      JobStatus.running => Colors.blue,
      JobStatus.preparing => Colors.orange,
      JobStatus.ready => Colors.green,
      JobStatus.pending => Colors.grey,
      JobStatus.completed => Colors.green,
      JobStatus.cancelled => Colors.red,
      JobStatus.failed => Colors.red,
    };
  }

  String getLabel(BuildContext context) {
    return switch (this) {
      JobStatus.running => context.l10n.runningStatus,
      JobStatus.preparing => context.l10n.preparingStatus,
      JobStatus.ready => context.l10n.readyStatus,
      JobStatus.pending => context.l10n.pendingStatus,
      JobStatus.completed => context.l10n.completedStatus,
      JobStatus.cancelled => context.l10n.cancelledStatus,
      JobStatus.failed => context.l10n.failedStatus,
    };
  }
}
