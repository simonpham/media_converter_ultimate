library;

/// Utility functions for parsing config JSON models safely and cleanly.

/// Checks if a key exists and is not null in a map, and returns the value as T.
/// Throws [FormatException] if the key is missing or the value is not of type T.
T requireField<T>(Map<String, dynamic> map, String key) {
  if (!map.containsKey(key) || map[key] == null) {
    throw FormatException('Missing required field: $key');
  }
  final value = map[key];
  if (value is T) {
    return value;
  }
  throw FormatException('Field "$key" is not of expected type $T');
}

/// Checks if a key exists in a map and returns the value as T, or null if missing or null.
/// Throws [FormatException] if the value is present but not of type T.
T? optionalField<T>(Map<String, dynamic> map, String key) {
  if (!map.containsKey(key) || map[key] == null) {
    return null;
  }
  final value = map[key];
  if (value is T) {
    return value;
  }
  throw FormatException('Field "$key" is not of expected type $T');
}

/// Parses a list of items from a map, using the provided item parser.
/// Throws [FormatException] if the field is missing or not a List.
List<T> parseList<T>(
  Map<String, dynamic> map,
  String key,
  T Function(dynamic) itemParser,
) {
  final rawList = requireField<List<dynamic>>(map, key);
  return rawList.map(itemParser).toList();
}

/// Parses an optional list of items from a map, using the provided item parser.
/// Returns null if the field is missing or null.
List<T>? parseOptionalList<T>(
  Map<String, dynamic> map,
  String key,
  T Function(dynamic) itemParser,
) {
  final rawList = optionalField<List<dynamic>>(map, key);
  if (rawList == null) return null;
  return rawList.map(itemParser).toList();
}

/// Parses a map of items from a map, using the provided value parser.
/// Throws [FormatException] if the field is missing or not a Map.
Map<String, T> parseMap<T>(
  Map<String, dynamic> map,
  String key,
  T Function(dynamic) valueParser,
) {
  final rawMap = requireField<Map<String, dynamic>>(map, key);
  return rawMap.map((k, v) => MapEntry(k, valueParser(v)));
}

/// Parses an optional map of items from a map, using the provided value parser.
/// Returns null if the field is missing or null.
Map<String, T>? parseOptionalMap<T>(
  Map<String, dynamic> map,
  String key,
  T Function(dynamic) valueParser,
) {
  final rawMap = optionalField<Map<String, dynamic>>(map, key);
  if (rawMap == null) return null;
  return rawMap.map((k, v) => MapEntry(k, valueParser(v)));
}

/// Parses an enum value from a string, using the provided values.
/// Throws [FormatException] if the value is missing or not valid.
T parseEnum<T>(Map<String, dynamic> map, String key, List<T> values) {
  final rawValue = requireField<String>(map, key);
  for (final v in values) {
    if (v.toString().split('.').last == rawValue) {
      return v;
    }
  }
  throw FormatException('Invalid enum value "$rawValue" for key "$key"');
}

/// Parses an optional enum value from a string, using the provided values.
/// Returns null if the field is missing or null.
T? parseOptionalEnum<T>(Map<String, dynamic> map, String key, List<T> values) {
  final rawValue = optionalField<String>(map, key);
  if (rawValue == null) return null;
  for (final v in values) {
    if (v.toString().split('.').last == rawValue) {
      return v;
    }
  }
  throw FormatException('Invalid enum value "$rawValue" for key "$key"');
}
