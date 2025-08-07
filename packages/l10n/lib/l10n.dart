library;

import 'package:flutter/widgets.dart';
import 'package:l10n/l10n.dart';

export 'package:flutter_localizations/flutter_localizations.dart';
export 'generated/l10n/app_localizations.dart';

extension L10nBuildContextExt on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
