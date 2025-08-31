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
      JobStatus.preparing => Colors.lightBlue,
      JobStatus.ready => Colors.green,
      JobStatus.running => Colors.blue,
      JobStatus.cancelled => Colors.red,
      JobStatus.failed => Colors.red,
      JobStatus.cleaning => Colors.lightBlue,
      JobStatus.completed => Colors.green,
    };
  }

  String getLabel(BuildContext context) {
    return switch (this) {
      JobStatus.pending => context.l10n.jobStatusPending,
      JobStatus.preparing => context.l10n.jobStatusPreparing,
      JobStatus.ready => context.l10n.jobStatusReady,
      JobStatus.running => context.l10n.jobStatusRunning,
      JobStatus.cancelled => context.l10n.jobStatusCancelled,
      JobStatus.failed => context.l10n.jobStatusFailed,
      JobStatus.cleaning => context.l10n.jobStatusCleaning,
      JobStatus.completed => context.l10n.jobStatusCompleted,
    };
  }
}
