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
  final String path;

  const DirectoryNotWritableFailure(this.path)
    : super('Directory is not writable: $path');
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

@immutable
class FileNameIsNotSetFailure extends Failure {
  final String path;

  const FileNameIsNotSetFailure(this.path)
    : super('File name is not set for $path.');
}

@immutable
class InputFileNotExistFailure extends Failure {
  final String path;

  const InputFileNotExistFailure(this.path)
    : super('Input file not exist: $path.');
}

@immutable
class DuplicatedFilePathFailure extends Failure {
  final String path;

  const DuplicatedFilePathFailure(this.path)
    : super('Duplicated file path: $path.');
}

@immutable
class OutputFileAlreadyExistsFailure extends Failure {
  final String path;

  const OutputFileAlreadyExistsFailure(this.path)
    : super('Output file already exists: $path.');
}

@immutable
class FileDeleteFailure extends Failure {
  final String path;

  const FileDeleteFailure(this.path) : super('Failed to delete file at $path.');
}

@immutable
class FailedToClearJobsFailure extends Failure {
  const FailedToClearJobsFailure() : super('Failed to clear finished jobs.');
}
