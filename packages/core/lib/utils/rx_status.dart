import 'package:flutter/foundation.dart';

@immutable
class const RxStatus<T>({
  final bool isLoading = false,
  final T? data,
  final String? error,
}) {
  factory RxStatus.loading() {
    return const .new(isLoading: true);
  }

  factory RxStatus.error(String error) {
    return .new(error: error);
  }

  factory RxStatus.data(T data) {
    return .new(data: data);
  }
}
