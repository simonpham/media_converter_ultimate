import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

extension ConvertJobExtension on ConvertJob {
  Directory get outputDirectory => Directory(outputDirectoryPath);

  File get outputFile => File(join(outputDirectoryPath, outputFileName));
}

@immutable
class ConvertJob {
  final String id;
  final String outputFileName;
  final String inputFilePath;
  final String outputExtension;
  final String outputDirectoryPath;
  final String command;
  final String convertedFilePath;

  final DateTime createdAt;
  final DateTime updatedAt;

  final int? sessionId;
  final JobStatus status;
  final int? progress;
  final int? duration;

  const ConvertJob({
    required this.id,
    required this.inputFilePath,
    required this.outputFileName,
    required this.outputExtension,
    required this.outputDirectoryPath,
    required this.command,
    required this.convertedFilePath,
    required this.createdAt,
    required this.updatedAt,
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
    'outputExtension': outputExtension,
    'outputDirectoryPath': outputDirectoryPath,
    'command': command,
    'convertedFilePath': convertedFilePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'sessionId': sessionId,
    'status': status.name,
    'progress': progress,
    'duration': duration,
  };

  ConvertJob copyWith({
    Some<String>? id,
    Some<String>? inputFilePath,
    Some<String>? outputFileName,
    Some<String>? outputExtension,
    Some<String>? outputDirectoryPath,
    Some<String>? command,
    Some<String>? convertedFilePath,
    Some<DateTime>? createdAt,
    Some<DateTime>? updatedAt,
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
    outputExtension: outputExtension != null
        ? outputExtension.value
        : this.outputExtension,
    outputDirectoryPath: outputDirectoryPath != null
        ? outputDirectoryPath.value
        : this.outputDirectoryPath,
    command: command != null ? command.value : this.command,
    convertedFilePath: convertedFilePath != null
        ? convertedFilePath.value
        : this.convertedFilePath,
    createdAt: createdAt != null ? createdAt.value : this.createdAt,
    updatedAt: updatedAt != null ? updatedAt.value : this.updatedAt,
    sessionId: sessionId != null ? sessionId.value : this.sessionId,
    status: status != null ? status.value : this.status,
    progress: progress != null ? progress.value : this.progress,
    duration: duration != null ? duration.value : this.duration,
  );
}
