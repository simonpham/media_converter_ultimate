import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart';

class const FileIcon(
  final File file, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final FileContentType type = .fromFile(file);
    return ImageView(
      getFileIcon(type),
      size: Spacing.d24,
      color: getFileIconColor(context, type),
    );
  }

  String getFileIcon(FileContentType type) {
    return switch (type) {
      .audio => Assets.fileAudio,
      .video => Assets.fileVideo,
      _ => Assets.file02,
    };
  }

  Color getFileIconColor(BuildContext context, FileContentType type) {
    return switch (type) {
      .audio => Colors.green,
      .video => Colors.blue,
      _ => context.theme.colorScheme.onSurface,
    };
  }
}
