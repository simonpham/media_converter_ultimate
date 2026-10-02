import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';
import 'package:utils/utils.dart';

extension BuildContextToastExtension on BuildContext {
  void toastSuccess(String message) {
    toast(message, type: MessageType.success);
  }

  void toastFailure(Failure failure) {
    toastError(failure.localized(this));
  }
}

extension FailureExtension on Failure {
  String localized(BuildContext context) {
    final localizedMessage = switch (this) {
      DirectoryNotWritableFailure _ => context.l10n.failureDirectoryNotWritable,
      InvalidStatusFailure _ => context.l10n.failureInvalidStatus,
      NoFilesSelectedFailure _ => context.l10n.failureNoFileSelected,
      NoOutputFormatFailure _ => context.l10n.failureNoOutputFormat,
      NoOutputConfigFailure _ => context.l10n.failureNoOutputConfig,
      NoOutputFolderFailure _ => context.l10n.failureNoOutputFolder,
      InvalidTrimTimestampFailure _ => context.l10n.trimInvalidTime,
      InvalidTrimRangeFailure _ => context.l10n.trimInvalidRange,
      InvalidTrimBoundsFailure _ => context.l10n.trimInvalidBounds,
      EmptyTrimRangeFailure f => context.l10n.trimRangeOutsideMedia(
        basename(f.path),
      ),
      FileNameIsNotSetFailure f => context.l10n.failureFileNameIsNotSet(
        basename(f.path),
      ),
      InputFileNotExistFailure f => context.l10n.failureInputFileNotExist(
        basename(f.path),
      ),
      DuplicatedFilePathFailure f => context.l10n.failureDuplicatedFilePath(
        f.path,
      ),
      OutputFileAlreadyExistsFailure f =>
        context.l10n.failureOutputFileAlreadyExists(f.path),
      FileDeleteFailure f => context.l10n.failureFileDelete(f.path),
      FailedToClearJobsFailure _ => context.l10n.failureFailedToClearJobs,
      _ => null,
    };

    if (localizedMessage == null) {
      printLog(
        '⚠️ [FailureExtension]: Failure [$runtimeType] is not localized',
      );
    }

    return localizedMessage ?? context.l10n.failureUnknown;
  }
}
