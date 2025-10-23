import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';

/// Simplified MCU configs validator.
///
/// Usage:
///   dart run mcu_configs /path/to/schemas_dir
///
/// This program expects exactly one positional argument: a directory that
/// contains the two schema files:
///   - format.schema.json
///   - supported_configurations.schema.json
///
/// It will load those schemas from the provided directory and validate:
///   - apps/mcu/assets/configs/format.json against format.schema.json
///   - each file in apps/mcu/assets/configs/supported_configurations/ against supported_configurations.schema.json
///
/// The program performs the same cross-file heuristics/checks as before.
///
/// Exit codes:
///   0 - success (no schema or cross-file errors)
///   1 - validation or cross-file errors found
///   2 - usage error or missing files (schemas / configs)
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsageAndExit();
  }

  final schemasDirPath = args[0];
  final schemasDir = Directory(schemasDirPath);

  if (!schemasDir.existsSync()) {
    stderr.writeln('Schemas directory not found: $schemasDirPath');
    _printUsageAndExit(code: 2);
  }

  final formatSchemaFile = File('${schemasDir.path}${Platform.pathSeparator}format.schema.json');
  final supportedSchemaFile =
      File('${schemasDir.path}${Platform.pathSeparator}supported_configurations.schema.json');

  final formatSchema = await _loadJsonSchemaFromFile(formatSchemaFile);
  final supportedSchema = await _loadJsonSchemaFromFile(supportedSchemaFile);

  if (formatSchema == null || supportedSchema == null) {
    stderr.writeln('Failed to load one or more schema files from: ${schemasDir.path}');
    exit(2);
  }

  // Locate configs directory (unchanged behavior): require repository layout at runtime.
  final configsDir = _findConfigsDir();
  if (configsDir == null) {
    stderr.writeln('Could not find apps/mcu/assets/configs from current directory ${Directory.current.path}');
    stderr.writeln('Please run this script from somewhere within the repository.');
    exit(2);
  }

  final formatJsonFile = File('${configsDir.path}${Platform.pathSeparator}format.json');
  final supportedConfigsDir = Directory('${configsDir.path}${Platform.pathSeparator}supported_configurations');

  if (!formatJsonFile.existsSync()) {
    stderr.writeln('Missing file: ${formatJsonFile.path}');
    exit(2);
  }
  if (!supportedConfigsDir.existsSync()) {
    stderr.writeln('Missing directory: ${supportedConfigsDir.path}');
    exit(2);
  }

  var hadErrors = false;

  // Validate format.json
  dynamic formatJson;
  try {
    formatJson = jsonDecode(formatJsonFile.readAsStringSync());
  } catch (e) {
    stderr.writeln('ERROR: Failed to parse ${formatJsonFile.path} as JSON: $e');
    exit(1);
  }

  final formatValid = formatSchema.validate(formatJson);
  if (formatValid.isValid) {
    stdout.writeln('OK: format.json conforms to format.schema.json');
  } else {
    hadErrors = true;
    stderr.writeln('ERROR: format.json does NOT conform to format.schema.json');
    stderr.writeln('  (json_schema.validate returned invalid)');
  }

  // Extract declared formats
  final declaredFormats = <String>{};
  try {
    if (formatJson is Map && formatJson['format'] is List) {
      for (final entry in formatJson['format'] as List) {
        if (entry is Map && entry['name'] is String) {
          declaredFormats.add(entry['name'] as String);
        }
      }
    }
  } catch (_) {
    // best-effort; schema failure already recorded
  }

  // Validate supported configurations
  final supportedFiles = supportedConfigsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final supportedFileNames = <String>{};
  for (final file in supportedFiles) {
    final baseName = file.uri.pathSegments.last;
    supportedFileNames.add(baseName);

    dynamic parsed;
    try {
      parsed = jsonDecode(file.readAsStringSync());
    } catch (e) {
      hadErrors = true;
      stderr.writeln('ERROR: ${file.path} is not valid JSON: $e');
      continue;
    }

    final valid = supportedSchema.validate(parsed);
    if (valid.isValid) {
      stdout.writeln('OK: ${file.path} conforms to supported_configurations.schema.json');
    } else {
      hadErrors = true;
      stderr.writeln('ERROR: ${file.path} does NOT conform to supported_configurations.schema.json');
      stderr.writeln('  (json_schema.validate returned invalid)');
    }

    // Additional heuristic checks (same as before)
    if (parsed is Map<String, dynamic>) {
      final topLevelKeys = parsed.keys.toSet();
      final fileErrors = <String>[];

      parsed.forEach((topKey, listValue) {
        if (listValue is! List) return;
        for (final cfg in listValue) {
          if (cfg is! Map) continue;
          final opts = cfg['options'];
          if (opts is List) {
            for (final opt in opts) {
              if (opt is Map) {
                final v = opt['value'];
                if (v is String) {
                  // if value equals a top-level trigger key that's okay, otherwise nothing
                  if (topLevelKeys.contains(v)) {
                    // explicit nested trigger
                  }
                }
              }
            }
          }

          final def = cfg['default'];
          if (def is String && opts is List) {
            List<String>? defList;
            try {
              final maybe = jsonDecode(def);
              if (maybe is List) defList = maybe.whereType<String>().toList();
            } catch (_) {
              // not JSON array string
            }

            if (defList != null) {
              for (final token in defList) {
                final found = opts.any((o) {
                  if (o is! Map) return false;
                  return (o['value'] == token) || (o['ffmpeg_arg'] == token);
                });
                if (!found) {
                  fileErrors.add('default element "$token" (in "$topKey") not found in options');
                }
              }
            } else {
              final foundSingle = opts.any((o) {
                if (o is! Map) return false;
                return (o['value'] == def) || (o['ffmpeg_arg'] == def);
              });
              if (!foundSingle && !topLevelKeys.contains(def)) {
                fileErrors.add('default "$def" (in "$topKey") not found in options and not a top-level trigger key');
              }
            }
          } else if (def is List && opts is List) {
            for (final token in def) {
              final found = opts.any((o) {
                if (o is! Map) return false;
                return (o['value'] == token) || (o['ffmpeg_arg'] == token);
              });
              if (!found) {
                fileErrors.add('default element "$token" (in "$topKey") not found in options');
              }
            }
          }
        }
      });

      if (fileErrors.isNotEmpty) {
        hadErrors = true;
        stderr.writeln('ERROR(s) in ${file.path}:');
        for (final e in fileErrors) stderr.writeln('  - $e');
      }
    }
  }

  // Cross-file checks
  final missingSupported = <String>[];
  for (final fmt in declaredFormats) {
    final expected = '$fmt.json';
    if (!supportedFileNames.contains(expected)) missingSupported.add(fmt);
  }
  if (missingSupported.isNotEmpty) {
    hadErrors = true;
    stderr.writeln('ERROR: The following formats are declared in format.json but missing in supported_configurations/:');
    for (final m in missingSupported) stderr.writeln('  - $m (expected file: $m.json)');
  } else {
    stdout.writeln('OK: All declared formats in format.json have a supported_configurations JSON file.');
  }

  final extraFiles = <String>[];
  const ignoredExtras = {'common_audio.json', 'common_video.json'};
  for (final fname in supportedFileNames) {
    if (ignoredExtras.contains(fname)) continue;
    final nameOnly = fname.replaceAll(RegExp(r'\.json$'), '');
    if (!declaredFormats.contains(nameOnly)) extraFiles.add(fname);
  }
  if (extraFiles.isNotEmpty) {
    stdout.writeln('WARNING: The following supported_configurations files are not referenced in format.json:');
    for (final f in extraFiles) stdout.writeln('  - $f');
  }

  final uiGradients = <String, dynamic>{};
  try {
    if (formatJson is Map && formatJson['ui_gradients'] is Map) {
      final map = formatJson['ui_gradients'] as Map;
      map.forEach((k, v) {
        uiGradients[k.toString()] = v;
      });
    }
  } catch (_) {}
  final missingGradients = <String>[];
  for (final fmt in declaredFormats) {
    if (!uiGradients.containsKey(fmt)) missingGradients.add(fmt);
  }
  if (missingGradients.isNotEmpty) {
    stdout.writeln('WARNING: ui_gradients missing entries for formats: ${missingGradients.join(', ')}');
  } else {
    stdout.writeln('OK: ui_gradients contains entries for all declared formats (or none are missing).');
  }

  if (hadErrors) {
    stderr.writeln('\nValidation finished: ERRORS detected. Fix the errors above.');
    exit(1);
  } else {
    stdout.writeln('\nValidation finished: no schema or cross-file errors detected.');
    exit(0);
  }
}

/// Load a JSON schema from a File and return a JsonSchema, or null on error.
Future<JsonSchema?> _loadJsonSchemaFromFile(File f) async {
  if (!f.existsSync()) {
    stderr.writeln('Schema file not found: ${f.path}');
    return null;
  }
  try {
    final content = await f.readAsString();
    final decoded = jsonDecode(content);
    return JsonSchema.create(decoded);
  } catch (e, st) {
    stderr.writeln('Failed to load/parse schema ${f.path}: $e\n$st');
    return null;
  }
}

/// Walks up from the current working directory to find `apps/mcu/assets/configs`
/// Returns the Directory if found, otherwise null.
Directory? _findConfigsDir() {
  var dir = Directory.current;
  while (true) {
    final candidatePath = '${dir.path}${Platform.pathSeparator}apps${Platform.pathSeparator}mcu${Platform.pathSeparator}assets${Platform.pathSeparator}configs';
    final candidate = Directory(candidatePath);
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break; // reached filesystem root
    dir = parent;
  }
  return null;
}

void _printUsageAndExit({int code = 1}) {
  stdout.writeln('Usage: dart run mcu_configs <schemas-directory>');
  stdout.writeln('');
  stdout.writeln('Provide a single argument pointing to the directory that contains:');
  stdout.writeln('  - format.schema.json');
  stdout.writeln('  - supported_configurations.schema.json');
  exit(code);
}