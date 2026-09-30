/// Resolves attached pictures from probe metadata before native execution.
/// Some bundled engines silently fail disposition-based stream selection.
class AudioArtworkMapping {
  static List<String> resolve(
    List<String> arguments, {
    required Iterable<int> attachedPictureIndexes,
  }) {
    final indexes = attachedPictureIndexes.where((index) => index >= 0).toSet();
    final resolved = <String>[];
    for (var index = 0; index < arguments.length; index++) {
      if (arguments[index] == '-map' &&
          index + 1 < arguments.length &&
          arguments[index + 1] == '0:v:disp:attached_pic?') {
        for (final picture in indexes) {
          resolved.addAll(['-map', '0:$picture']);
        }
        index++;
      } else {
        resolved.add(arguments[index]);
      }
    }
    return resolved;
  }
}
