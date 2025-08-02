import 'package:flutter/foundation.dart';

@immutable
class Failure {
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}

@immutable
class DirectoryNotWritableFailure extends Failure {
  const DirectoryNotWritableFailure() : super('Directory is not writable.');
}
