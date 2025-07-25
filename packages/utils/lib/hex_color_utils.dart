import 'dart:ui';

/// Utility for parsing hex color strings to [Color].
class HexColorUtils {
  /// Parses a hex color string (e.g., "#fc5c7d" or "#FC5C7D") to a [Color].
  /// Adds alpha channel if missing (defaults to opaque).
  static Color parse(String hex) {
    var hexColor = hex.replaceFirst('#', '');
    if (hexColor.length == 6) {
      hexColor = 'ff$hexColor'; // add alpha if missing
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
