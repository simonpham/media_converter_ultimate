import 'dart:async';

import 'package:core/core.dart';

abstract interface class BaseStorage<T> {
  const BaseStorage();

  FutureOr<Failure?> add(T item);

  FutureOr<Failure?> addAll(List<T> items);

  FutureOr<Failure?> update(T item);

  FutureOr<List<T>> list(Pagination pagination);

  FutureOr<Failure?> delete(String id);
}
