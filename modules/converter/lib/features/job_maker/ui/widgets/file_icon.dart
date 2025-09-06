import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';

class FileIcon extends StatelessWidget {
  final File file;

  const FileIcon(
    this.file, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final type = FileContentType.fromFile(file);
    return ImageView(
      getFileIcon(type),
      size: Spacing.d24,
      color: getFileIconColor(context, type),
    );
  }

  String getFileIcon(FileContentType type) {
    return switch (type) {
      FileContentType.audio => Assets.hugeicons.stroke.filesFolders.fileAudio,
      FileContentType.video => Assets.hugeicons.stroke.filesFolders.fileVideo,
      _ => Assets.hugeicons.stroke.filesFolders.file02,
    };
  }

  Color getFileIconColor(BuildContext context, FileContentType type) {
    return switch (type) {
      FileContentType.audio => Colors.green,
      FileContentType.video => Colors.blue,
      _ => context.theme.colorScheme.onSurface,
    };
  }
}
