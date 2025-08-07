import 'package:core/core.dart';
import 'package:flutter/material.dart';

enum JobStatus {
  running,
  preparing,
  ready,
  pending,
  completed,
  failed;

  Color getColor() {
    return switch (this) {
      JobStatus.running => Colors.blue,
      JobStatus.preparing => Colors.orange,
      JobStatus.ready => Colors.green,
      JobStatus.pending => Colors.grey,
      JobStatus.completed => Colors.green,
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
      JobStatus.failed => context.l10n.failedStatus,
    };
  }
}
