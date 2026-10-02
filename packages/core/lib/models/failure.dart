import 'package:flutter/foundation.dart';

@immutable
class const Failure(final String message) {
  @override
  String toString() => message;
}

@immutable
class const DirectoryNotWritableFailure(final String path) extends Failure {
  this : super('Directory is not writable: $path');
}

@immutable
class const InvalidStatusFailure() extends Failure {
  this : super('Invalid status.');
}

@immutable
class const NoFilesSelectedFailure() extends Failure {
  this : super('No files selected.');
}

@immutable
class const NoOutputFormatFailure() extends Failure {
  this : super('No output format selected.');
}

@immutable
class const NoOutputConfigFailure() extends Failure {
  this : super('No output config selected.');
}

@immutable
class const NoOutputFolderFailure() extends Failure {
  this : super('No output folder selected.');
}

@immutable
class const InvalidTrimTimestampFailure() extends Failure {
  this : super('Invalid trim timestamp.');
}

@immutable
class const InvalidTrimRangeFailure() extends Failure {
  this : super('Trim end must be after its start.');
}

@immutable
class const InvalidTrimBoundsFailure() extends Failure {
  this : super('Trim range must be within this file duration.');
}

@immutable
class const EmptyTrimRangeFailure(final String path) extends Failure {
  this : super('The trim range contains no media: $path');
}

@immutable
class const FileNameIsNotSetFailure(final String path) extends Failure {
  this : super('File name is not set for $path.');
}

@immutable
class const InputFileNotExistFailure(final String path) extends Failure {
  this : super('Input file not exist: $path.');
}

@immutable
class const DuplicatedFilePathFailure(final String path) extends Failure {
  this : super('Duplicated file path: $path.');
}

@immutable
class const OutputFileAlreadyExistsFailure(final String path) extends Failure {
  this : super('Output file already exists: $path.');
}

@immutable
class const FileDeleteFailure(final String path) extends Failure {
  this : super('Failed to delete file at $path.');
}

@immutable
class const FailedToClearJobsFailure() extends Failure {
  this : super('Failed to clear finished jobs.');
}
