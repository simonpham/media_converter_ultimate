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

  static String convertToWebHex(Color color) {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b$a';
  }
}

extension HexColorUtilsExt on Color {
  /// Converts a [Color] to a hex string (e.g., "#fc5c7d" or "#FC5C7D").
  String toWebHex() => HexColorUtils.convertToWebHex(this);
}
