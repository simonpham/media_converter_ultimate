import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class const JobLog({
  required final String jobId,
  required final String message,
}) {

  @override
  String toString() {
    return '[JobLog]: ${jsonEncode(toJson())}';
  }

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'message': message,
  };
}
