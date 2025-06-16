import 'package:flutter/foundation.dart';

@immutable
class RxStatus<T> {
  final bool isLoading;
  final T? data;
  final String? error;

  const RxStatus({
    this.isLoading = false,
    this.data,
    this.error,
  });

  factory RxStatus.loading() {
    return const RxStatus(isLoading: true);
  }

  factory RxStatus.error(String error) {
    return RxStatus(error: error);
  }

  factory RxStatus.data(T data) {
    return RxStatus(data: data);
  }
}
