import 'package:converter/converter.dart';
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
      JobStatus.running => 'Running',
      JobStatus.preparing => 'Preparing',
      JobStatus.ready => 'Ready',
      JobStatus.pending => 'Pending',
      JobStatus.completed => 'Completed',
      JobStatus.failed => 'Failed',
    }.hardcode;
  }
}
