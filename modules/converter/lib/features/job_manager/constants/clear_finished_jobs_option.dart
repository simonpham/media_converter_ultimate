import 'package:core/core.dart';
import 'package:flutter/widgets.dart';

enum ClearFinishedJobsOption(final int dayCount) {
  everything(0),
  olderThan7Days(7),
  olderThan30Days(30),
  olderThan90Days(90);

  String getLabel(BuildContext context) {
    return switch (this) {
      .everything => context.l10n.clearEverythingLabel,
      _ => context.l10n.clearOlderThanXDaysLabel(dayCount),
    };
  }

  String getSuccessMessage(BuildContext context) {
    return switch (this) {
      .everything => context.l10n.clearEverythingSuccessMessage,
      _ => context.l10n.clearOlderThanXDaysSuccessMessage(dayCount),
    };
  }
}
