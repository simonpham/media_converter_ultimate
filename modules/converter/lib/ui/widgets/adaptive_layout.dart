import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// Centers [child] and caps its width on large screens.
///
/// The widget tree stays the same across screen sizes, so resizing the
/// window keeps the state of everything below it.
class const AdaptiveContent({
  super.key,
  required final Widget child,
  final double? maxWidth,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: .topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: switch (context.screenSize) {
          .small || .normal => double.infinity,
          .large ||
          .larger ||
          .extraLarge => maxWidth ?? ScreenSize.large.breakpoint.toDouble(),
        },
      ),
      child: child,
    ),
  );
}

/// Shows [builder] as a bottom sheet on handheld screens and as a centered
/// dialog on large, tall screens, where a full-width sheet would stretch too far.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return switch (_usesDialog(context)) {
    false => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: builder,
    ),
    true => showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: FluffyColors.barrier,
      transitionDuration: FluffyDurations.dialogTransition,
      transitionBuilder: _dialogTransition,
      pageBuilder: (context, _, _) => DialogCard(
        maxWidth: ScreenSize.normal.breakpoint.toDouble(),
        content: Material(
          type: .transparency,
          child: Builder(builder: builder),
        ),
      ),
    ),
  };
}

/// Pushes [builder] as a full page on handheld screens and shows it as a
/// large dialog on large, tall screens, keeping the current page in view.
Future<T?> showAdaptivePage<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return switch (_usesDialog(context)) {
    false => context.navigator.push<T>(
      MaterialPageRoute(builder: builder),
    ),
    true => showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: FluffyColors.barrier,
      transitionDuration: FluffyDurations.dialogTransition,
      transitionBuilder: _dialogTransition,
      // Lift the dialog above the keyboard instead of letting the page inside
      // shrink by the full keyboard height.
      pageBuilder: (context, _, _) => AnimatedPadding(
        padding: MediaQuery.viewInsetsOf(context),
        duration: Durations.short4,
        curve: Curves.easeOut,
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: SafeArea(
            child: Padding(
              padding: .all(Spacing.d32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: ScreenSize.large.breakpoint.toDouble(),
                  ),
                  child: ClipRSuperellipse(
                    borderRadius: Spacing.r12,
                    child: Builder(builder: builder),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  };
}

/// Dialogs suit screens that are both wide and tall. A phone in landscape is
/// wide but too short, so it keeps the handheld presentation.
bool _usesDialog(BuildContext context) {
  final screenSize = context.read<ScreenSizeNotifier>().screenSize;
  final isTall =
      MediaQuery.sizeOf(context).height >= ScreenSize.normal.breakpoint;
  return switch (screenSize) {
    .small || .normal => false,
    .large || .larger || .extraLarge => isTall,
  };
}

Widget _dialogTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => FadeTransition(
  opacity: animation,
  child: ScaleTransition(
    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    ),
    child: child,
  ),
);
