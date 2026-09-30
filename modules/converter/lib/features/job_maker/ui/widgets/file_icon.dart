import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const FileIcon(
  final FileContentType type, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ImageView(
      getFileIcon(type),
      size: Spacing.d24,
      color: context.theme.colorScheme.onSurface,
    );
  }

  String getFileIcon(FileContentType type) {
    return switch (type) {
      .audio => Assets.fileAudio,
      .video => Assets.fileVideo,
      _ => Assets.file02,
    };
  }
}
