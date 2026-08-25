import 'dart:io';

const Map<String, List<String>> kLocaleMapping = {
  'en': ['en-US', 'en-GB', 'en-CA', 'en-AU', 'en-IN'],
  'de': ['de-DE'],
  'es': ['es-ES', 'es-419', 'es-US'],
  'id': ['id-ID', 'id'],
  'it': ['it-IT'],
  'ja': ['ja-JP'],
  'pt': ['pt-BR', 'pt-PT'],
  'tr': ['tr-TR'],
  'vi': ['vi-VN', 'vi'],
  'zh': ['zh-CN'],
  'zh_TW': ['zh-TW', 'zh-HK'],
};

const int kGooglePlayMaxChars = 500;

String cleanHtmlText(String rawHtml) {
  var text = rawHtml
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  // Remove HTML tags
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  // Normalize whitespace
  return text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

List<String> extractReleaseNotes(String content, {String? targetVersion}) {
  final sections = content.split(RegExp(r'<h3[^>]*>', caseSensitive: false));
  final items = <String>[];

  for (final section in sections) {
    if (section.trim().isEmpty) continue;

    final h3Match = RegExp(
      r'^(.*?)</h3\s*>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(section);
    if (h3Match == null) continue;

    final versionStr = cleanHtmlText(h3Match.group(1) ?? '').trim();
    final body = section.substring(h3Match.end);

    if (targetVersion != null &&
        targetVersion.isNotEmpty &&
        targetVersion != versionStr) {
      continue;
    }

    final liMatches = RegExp(
      r'<li[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(body);

    for (final match in liMatches) {
      final rawText = match.group(1) ?? '';
      var cleaned = cleanHtmlText(rawText);
      if (cleaned.isNotEmpty) {
        if (!cleaned.startsWith('-') &&
            !cleaned.startsWith('•') &&
            !cleaned.startsWith('*')) {
          cleaned = '• $cleaned';
        }
        items.add(cleaned);
      }
    }

    if (items.isNotEmpty) break;
  }

  return items;
}

void main(List<String> args) {
  String changelogDirPath = 'apps/mcu/assets/content/changelog';
  String outputDirPath = 'distribution/whatsnew';
  String? targetVersion;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--changelog-dir' && i + 1 < args.length) {
      changelogDirPath = args[++i];
    } else if (arg.startsWith('--changelog-dir=')) {
      changelogDirPath = arg.substring('--changelog-dir='.length);
    } else if (arg == '--output-dir' && i + 1 < args.length) {
      outputDirPath = args[++i];
    } else if (arg.startsWith('--output-dir=')) {
      outputDirPath = arg.substring('--output-dir='.length);
    } else if (arg == '--version' && i + 1 < args.length) {
      targetVersion = args[++i];
    } else if (arg.startsWith('--version=')) {
      targetVersion = arg.substring('--version='.length);
    }
  }

  final changelogDir = Directory(changelogDirPath);
  final outputDir = Directory(outputDirPath);

  if (!changelogDir.existsSync()) {
    stderr.writeln(
      'Error: Changelog directory "$changelogDirPath" does not exist.',
    );
    exit(1);
  }

  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  var processedCount = 0;
  final htmlFiles =
      changelogDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.html'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in htmlFiles) {
    final fileName = file.uri.pathSegments.last;
    final langKey = fileName.substring(0, fileName.lastIndexOf('.'));
    final targetLocales = kLocaleMapping[langKey] ?? [langKey];

    final content = file.readAsStringSync();
    var notes = extractReleaseNotes(content, targetVersion: targetVersion);

    if (notes.isEmpty) {
      notes = extractReleaseNotes(content);
    }

    if (notes.isEmpty) {
      stdout.writeln('⚠️ Warning: No release notes found in $fileName');
      continue;
    }

    var notesText = notes.join('\n');
    if (notesText.length > kGooglePlayMaxChars) {
      stdout.writeln(
        '⚠️ Warning: Release notes for $langKey exceed $kGooglePlayMaxChars chars (${notesText.length}). Truncating.',
      );
      notesText = '${notesText.substring(0, kGooglePlayMaxChars - 3)}...';
    }

    for (final locale in targetLocales) {
      final outFile = File('${outputDir.path}/whatsnew-$locale');
      outFile.writeAsStringSync(notesText);
      stdout.writeln(
        '✅ Generated ${outFile.uri.pathSegments.last} (${notesText.length} chars)',
      );
      processedCount++;
    }
  }

  stdout.writeln(
    '\n🎉 Successfully generated $processedCount whatsnew files in "$outputDirPath".',
  );
}
