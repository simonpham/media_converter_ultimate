/// Persisted destination identifier. Plain paths remain valid for existing jobs.
enum OutputDestinationKind { directory, downloads, appStorage, tree }

class const OutputDestination({
  required final OutputDestinationKind kind,
  required final String location,
  final String? label,
}) {
  static const downloads = 'mcu-output://downloads';
  static const appStorage = 'mcu-output://app';

  factory OutputDestination.parse(String value) {
    if (value == downloads) {
      return const .new(kind: .downloads, location: 'downloads');
    }
    if (value == appStorage) {
      return const .new(kind: .appStorage, location: appStorage);
    }
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'mcu-output' && uri?.host == 'tree') {
      final tree = uri!.queryParameters['uri'];
      if (tree == null || Uri.tryParse(tree)?.scheme != 'content') {
        throw const FormatException('Invalid output folder URI');
      }
      return .new(
        kind: .tree,
        location: tree,
        label: uri.queryParameters['label'],
      );
    }
    // Accept previously stored tree URIs as well as the labelled identifiers.
    if (uri?.scheme == 'content') {
      return .new(kind: .tree, location: value);
    }
    if (uri?.scheme == 'mcu-output') {
      throw const FormatException('Unknown output destination');
    }
    return .new(kind: .directory, location: value);
  }

  static String tree(String uri, String label) => Uri(
    scheme: 'mcu-output',
    host: 'tree',
    queryParameters: {'uri': uri, 'label': label},
  ).toString();
}

/// Actual provider name and location, which may differ from the requested name.
class const ExportedFile({
  required final String location,
  required final String name,
});
