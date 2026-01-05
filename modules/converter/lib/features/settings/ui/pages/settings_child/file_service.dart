part of '../settings_child.dart';

class FileServiceSettingsChild extends SettingsChild {
  const FileServiceSettingsChild({super.key});

  @override
  SettingsPageItem get settings => SettingsPageItem.fileService;

  @override
  Widget builder(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          RadioListTile<bool>(
            title: const Text('Android SAF (Storage Access Framework)'),
            subtitle: const Text(
              'Recommended for modern Android versions. Requires fewer permissions but may be slower. '
              'Files will be automatically named.',
            ),
            value: true,
            groupValue: SettingsBox().useSafFileService,
            onChanged: (value) {
              if (value != null) {
                SettingsBox().useSafFileService = value;
              }
            },
          ),
          RadioListTile<bool>(
            title: const Text('Direct File Access'),
            subtitle: const Text(
              'Traditional file access. Faster but requires more permissions. '
              'May not work on Android 11+ for some folders.',
            ),
            value: false,
            groupValue: SettingsBox().useSafFileService,
            onChanged: (value) {
              if (value != null) {
                SettingsBox().useSafFileService = value;
              }
            },
          ),
        ],
      ),
    );
  }
}
