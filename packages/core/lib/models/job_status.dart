import 'package:core/core.dart';
import 'package:flutter/material.dart';

extension JobStatusExtension on JobStatus {
  bool get isQueued => this == JobStatus.pending;

  bool get isProcessing =>
      this == JobStatus.running ||
      this == JobStatus.preparing ||
      this == JobStatus.ready ||
      this == JobStatus.cleaning;

  bool get isDone =>
      this == JobStatus.completed ||
      this == JobStatus.failed ||
      this == JobStatus.cancelled;

  bool get isFailure => this == JobStatus.failed || this == JobStatus.cancelled;
}

enum JobStatus {
  pending, // Just created.
  preparing, // Getting media info.
  ready, // Done getting media info.
  running, // FFmpeg session is running.
  cleaning, // FFmpeg session is completed.
  cancelled, // FFmpeg session is cancelled.
  failed, // FFmpeg session is failed.
  completed // Conversion job is completed.
  ;

  Color getColor() {
    return switch (this) {
      JobStatus.pending => Colors.grey,
      JobStatus.preparing => Colors.orange,
      JobStatus.ready => Colors.green,
      JobStatus.running => Colors.blue,
      JobStatus.cancelled => Colors.red,
      JobStatus.failed => Colors.red,
      JobStatus.cleaning => Colors.orange,
      JobStatus.completed => Colors.green,
    };
  }

  String getLabel(BuildContext context) {
    return switch (this) {
      JobStatus.pending => context.l10n.pendingStatus,
      JobStatus.preparing => context.l10n.preparingStatus,
      JobStatus.ready => context.l10n.readyStatus,
      JobStatus.running => context.l10n.runningStatus,
      JobStatus.cancelled => context.l10n.cancelledStatus,
      JobStatus.failed => context.l10n.failedStatus,
      JobStatus.cleaning => context.l10n.cleaningStatus,
      JobStatus.completed => context.l10n.completedStatus,
    };
  }
}
