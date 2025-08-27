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

@immutable
class InvalidStatusFailure extends Failure {
  const InvalidStatusFailure() : super('Invalid status.');
}

@immutable
class NoFilesSelectedFailure extends Failure {
  const NoFilesSelectedFailure() : super('No files selected.');
}

@immutable
class NoOutputFormatFailure extends Failure {
  const NoOutputFormatFailure() : super('No output format selected.');
}

@immutable
class NoOutputConfigFailure extends Failure {
  const NoOutputConfigFailure() : super('No output config selected.');
}

@immutable
class NoOutputFolderFailure extends Failure {
  const NoOutputFolderFailure() : super('No output folder selected.');
}
