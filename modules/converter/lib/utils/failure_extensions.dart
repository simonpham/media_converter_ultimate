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
      _ => context.l10n.failureUnknown,
    };
  }
}
