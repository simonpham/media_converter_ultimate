import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart' hide context;
import 'package:sofluffy_ui/sofluffy_ui.dart';

String outputDestinationLabel(BuildContext context, String? value) {
  if (value == null) return context.l10n.selectFolder;
  final destination = OutputDestination.parse(value);
  return switch (destination.kind) {
    .downloads => '${context.l10n.outputDownloads} › MediaConverterPro',
    .appStorage => context.l10n.outputAppStorage,
    .tree =>
      destination.label ??
          Uri.decodeComponent(
            Uri.parse(destination.location).pathSegments.last,
          ),
    .directory =>
      destination.location
          .replaceAll(
            '/storage/emulated/0/',
            '${context.l10n.outputInternalStorage} › ',
          )
          .replaceAll('/', ' › '),
  };
}

/// Shared destination choices for setup, Settings, recovery and log export.
class OutputDestinationPicker {
  static Future<String?> show(
    BuildContext context, {
    String? initialPath,
  }) async {
    final (value, failure) = await injector<FileService>().chooseSavePath(
      context,
      initialPath: initialPath,
    );
    if (!context.mounted || value != null || failure == null) {
      return value;
    }
    if (!Platform.isAndroid) {
      context.toastFailure(failure);
      return null;
    }
    return showAdaptiveSheet<String>(
      context,
      builder: (_) =>
          _DestinationSheet(initialPath: initialPath, initialFailure: failure),
    );
  }
}

class const _DestinationSheet({
  final String? initialPath,
  final Failure? initialFailure,
}) extends StatefulWidget {
  @override
  State<_DestinationSheet> createState() => _DestinationSheetState();
}

class _DestinationSheetState extends State<_DestinationSheet> {
  final ScrollController _scroll = .new();
  String? _downloads;
  Failure? _failure;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _failure = widget.initialFailure;
    unawaited(_loadDownloads());
  }

  Future<void> _loadDownloads() async {
    try {
      final value = await injector<FileService>().getDownloadsDestination();
      if (mounted) setState(() => _downloads = value);
    } catch (error, trace) {
      printError(error, trace);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _choice(
    String title,
    String? subtitle,
    VoidCallback? onTap, {
    bool selected = false,
  }) => ListItem(
    leading: ImageView(
      Assets.folder01,
      size: Spacing.d24,
      color: context.theme.colorScheme.primary,
    ),
    title: title,
    subtitle: subtitle,
    trailing: selected
        ? ImageView(
            Assets.tick02,
            size: Spacing.d24,
            color: context.theme.colorScheme.primary,
          )
        : null,
    onTap: onTap,
  );

  Future<void> _pickFolder() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _failure = null;
    });
    final (value, failure) = await injector<FileService>().chooseSavePath(
      context,
      initialPath: widget.initialPath,
    );
    if (!mounted) return;
    setState(() {
      _picking = false;
      _failure = failure;
    });
    if (value != null) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: .only(
            left: Spacing.d16,
            right: Spacing.d16,
            bottom: Spacing.d16,
          ),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              SectionTitle(context.l10n.outputSaveTo, padding: .zero),
              Spacing.v8,
              if (widget.initialPath != null) ...[
                Text(
                  outputDestinationLabel(context, widget.initialPath),
                  style: context.theme.textTheme.bodyMedium,
                ),
                Spacing.v8,
              ],
              _choice(
                context.l10n.selectFolder,
                context.l10n.outputChooseFolderHint,
                _picking ? null : _pickFolder,
              ),
              if (_failure != null)
                Padding(
                  padding: .all(Spacing.d8),
                  child: Text(
                    _failure!.localized(context),
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.error,
                    ),
                  ),
                ),
              const Divider(),
              if (_downloads != null)
                _choice(
                  '${context.l10n.outputDownloads} › MediaConverterPro',
                  context.l10n.outputDownloadsHint,
                  _picking ? null : () => Navigator.of(context).pop(_downloads),
                  selected: widget.initialPath == _downloads,
                ),
              _choice(
                context.l10n.outputAppStorage,
                context.l10n.outputAppStorageHint,
                _picking
                    ? null
                    : () =>
                          Navigator.of(context)
                              .pop(OutputDestination.appStorage),
                selected: widget.initialPath == OutputDestination.appStorage,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
