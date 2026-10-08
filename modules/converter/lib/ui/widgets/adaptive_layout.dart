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
/// dialog on large screens, where a full-width sheet would stretch too far.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final screenSize = context.read<ScreenSizeNotifier>().screenSize;
  return switch (screenSize) {
    .small || .normal => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: builder,
    ),
    .large || .larger || .extraLarge => showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: FluffyColors.barrier,
      transitionDuration: FluffyDurations.dialogTransition,
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
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
