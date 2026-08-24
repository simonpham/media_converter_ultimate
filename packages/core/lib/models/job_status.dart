import 'package:core/core.dart';
import 'package:flutter/material.dart';

extension JobStatusExtension on JobStatus {
  bool get isQueued => this == .pending;

  bool get isProcessing =>
      this == .running ||
      this == .preparing ||
      this == .ready ||
      this == .cleaning;

  bool get isDone =>
      this == .completed ||
      this == .failed ||
      this == .cancelled;

  bool get isFailure => this == .failed || this == .cancelled;
}

enum JobStatus {
  pending, // Just created.
  preparing, // Getting media info.
  ready, // Done getting media info.
  running, // FFmpeg session is running.
  cleaning, // FFmpeg session is completed.
  cancelled, // FFmpeg session is cancelled.
  failed, // FFmpeg session is failed.
  actionRequired, // Conversion success, but needs user action to finalize.
  completed // Conversion job is completed.
  ;

  Color getColor() {
    return switch (this) {
      .pending => Colors.grey,
      .preparing => Colors.lightBlue,
      .ready => Colors.green,
      .running => Colors.blue,
      .cancelled => Colors.red,
      .failed => Colors.red,
      .cleaning => Colors.lightBlue,
      .completed => Colors.green,
      .actionRequired => Colors.amber,
    };
  }

  String getLabel(BuildContext context) {
    return switch (this) {
      .pending => context.l10n.jobStatusPending,
      .preparing => context.l10n.jobStatusPreparing,
      .ready => context.l10n.jobStatusReady,
      .running => context.l10n.jobStatusRunning,
      .cancelled => context.l10n.jobStatusCancelled,
      .failed => context.l10n.jobStatusFailed,
      .cleaning => context.l10n.jobStatusCleaning,
      .actionRequired => context.l10n.jobStatusActionRequired,
      .completed => context.l10n.jobStatusCompleted,
    };
  }
}
