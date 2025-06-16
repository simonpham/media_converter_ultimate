import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';
import 'package:utils/utils.dart';

@immutable
class ConvertJob {
  final String id;
  final String outputFileName;
  final String inputFilePath;
  final String outputDirectoryPath;
  final String command;

  final int? sessionId;
  final JobStatus status;
  final int? progress;
  final int? duration;

  const ConvertJob({
    required this.id,
    required this.inputFilePath,
    required this.outputFileName,
    required this.outputDirectoryPath,
    required this.command,
    this.sessionId,
    this.status = JobStatus.pending,
    this.progress,
    this.duration,
  });

  @override
  String toString() {
    return '[ConvertJob]: ${jsonEncode(toJson())}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inputFilePath': inputFilePath,
    'outputFileName': outputFileName,
    'outputDirectoryPath': outputDirectoryPath,
    'command': command,
    'sessionId': sessionId,
    'status': status.name,
    'progress': progress,
    'duration': duration,
  };

  ConvertJob copyWith({
    Some<String>? id,
    Some<String>? inputFilePath,
    Some<String>? outputFileName,
    Some<String>? outputDirectoryPath,
    Some<String>? command,
    Some<int?>? sessionId,
    Some<JobStatus>? status,
    Some<int?>? progress,
    Some<int?>? duration,
  }) => ConvertJob(
    id: id != null ? id.value : this.id,
    inputFilePath: inputFilePath != null
        ? inputFilePath.value
        : this.inputFilePath,
    outputFileName: outputFileName != null
        ? outputFileName.value
        : this.outputFileName,
    outputDirectoryPath: outputDirectoryPath != null
        ? outputDirectoryPath.value
        : this.outputDirectoryPath,
    command: command != null ? command.value : this.command,
    sessionId: sessionId != null ? sessionId.value : this.sessionId,
    status: status != null ? status.value : this.status,
    progress: progress != null ? progress.value : this.progress,
    duration: duration != null ? duration.value : this.duration,
  );
}
