import 'dart:async';

import 'package:core/core.dart';

abstract class ConvertJobStorage {
  const ConvertJobStorage();

  FutureOr<List<ConvertJob>> getJobs(Pagination pagination);
}
