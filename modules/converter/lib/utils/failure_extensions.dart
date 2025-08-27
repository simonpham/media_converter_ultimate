import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';

extension BuildContextToastExtension on BuildContext {
  void toastFailure(Failure failure) {
    toastError(failure.localized(this));
  }
}

extension FailureExtension on Failure {
  String localized(BuildContext context) {
    return switch (this) {
      DirectoryNotWritableFailure _ => context.l10n.failureDirectoryNotWritable,
      InvalidStatusFailure _ => context.l10n.failureInvalidStatus,
      NoFilesSelectedFailure _ => context.l10n.failureNoFileSelected,
      NoOutputFormatFailure _ => context.l10n.failureNoOutputFormat,
      NoOutputConfigFailure _ => context.l10n.failureNoOutputConfig,
      NoOutputFolderFailure _ => context.l10n.failureNoOutputFolder,
      _ => context.l10n.failureUnknown,
    };
  }
}
