import 'dart:convert';

import 'package:core/core.dart';

/// Resolves only the branches selected by their own parent controls.
abstract final class ConfigurationSelection {
  static List<ConfigControlOption> selectedOptions(
    ConfigControl control,
    String? value,
  ) {
    final selected = control.type == .multiChoice
        ? _array(value) ?? const <String>[]
        : [value];
    return control.options
        .where((option) => selected.contains(option.value))
        .toList();
  }

  static List<ConfigControl> resolveControls({
    required Map<String, List<ConfigControl>> groups,
    required Iterable<String> roots,
    required Map<String, String> selectedValues,
  }) {
    return _walk(
      groups: groups,
      roots: roots,
      valueFor: (control) =>
          selectedValues[control.name] ?? control.defaultValue,
    );
  }

  /// Retains known preferences and repairs invalid selections in active groups.
  static Map<String, String> normalizeValues({
    required Map<String, List<ConfigControl>> groups,
    required Iterable<String> roots,
    Map<String, String> overrides = const {},
  }) {
    final controls = groups.values.expand((group) => group).toList();
    final knownNames = controls.map((control) => control.name).toSet();
    final values = <String, String>{};
    for (final control in controls) {
      if (control.defaultValue case final String value) {
        values.putIfAbsent(control.name, () => value);
      }
    }
    values.addAll({
      for (final entry in overrides.entries)
        if (knownNames.contains(entry.key)) entry.key: entry.value,
    });
    _walk(
      groups: groups,
      roots: roots,
      valueFor: (control) {
        final value = _normalize(control, values[control.name]);
        values[control.name] = value;
        return value;
      },
    );
    return values;
  }

  static List<ConfigControl> _walk({
    required Map<String, List<ConfigControl>> groups,
    required Iterable<String> roots,
    required String? Function(ConfigControl) valueFor,
  }) {
    final controls = <ConfigControl>[];
    final visitedGroups = <String>{};
    final visitedControls = <String>{};
    void visit(String key) {
      if (!visitedGroups.add(key)) {
        return;
      }
      for (final control in groups[key] ?? const <ConfigControl>[]) {
        if (!visitedControls.add(control.name)) {
          continue;
        }
        controls.add(control);
        final value = valueFor(control);
        final selected = control.type == .multiChoice
            ? _array(value) ?? const <String>[]
            : [value];
        for (final option in control.options) {
          if (selected.contains(option.value) &&
              groups.containsKey(option.value)) {
            visit(option.value);
          }
        }
      }
    }

    for (final root in roots) {
      visit(root);
    }
    return controls;
  }

  static String _normalize(ConfigControl control, String? value) {
    final allowed = control.options.map((option) => option.value).toSet();
    if (control.type == .multiChoice) {
      final selected =
          _array(value) ??
          (allowed.contains(value) ? [value!] : _array(control.defaultValue)) ??
          const <String>[];
      return jsonEncode(selected.where(allowed.contains).toSet().toList());
    }
    if (allowed.contains(value)) {
      return value!;
    }
    if (allowed.contains(control.defaultValue)) {
      return control.defaultValue!;
    }
    return control.options.firstOrNull?.value ?? '';
  }

  static List<String>? _array(String? value) {
    if (value == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is List && decoded.every((value) => value is String)) {
        return decoded.cast<String>();
      }
    } catch (_) {}
    return null;
  }
}
