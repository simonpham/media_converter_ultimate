import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class JobLog {
  final String jobId;
  final String message;

  const JobLog({
    required this.jobId,
    required this.message,
  });

  @override
  String toString() {
    return '[JobLog]: ${jsonEncode(toJson())}';
  }

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'message': message,
  };
}
