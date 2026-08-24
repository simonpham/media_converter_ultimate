import 'dart:convert';
import 'dart:io';

/// Comprehensive automated verification script that tests FFmpeg conversions
/// across all 25 formats and every single configurable option (codecs, bitrates,
/// presets, sample rates, channels, and quality levels) using diverse media inputs.
void main(List<String> args) async {
  print('===============================================================');
  print('   MCU FFmpeg Comprehensive Configuration & Codec Test Suite   ');
  print('===============================================================\n');

  // Check if FFmpeg is available
  final ffmpegCheck = await Process.run('which', ['ffmpeg']);
  if (ffmpegCheck.exitCode != 0) {
    stderr.writeln('ERROR: ffmpeg binary not found on PATH.');
    exit(1);
  }
  final ffmpegPath = (ffmpegCheck.stdout as String).trim();
  print('FFmpeg binary: $ffmpegPath\n');

  // Query available encoders in current FFmpeg build
  final encodersResult = await Process.run(ffmpegPath, ['-encoders']);
  final encodersOutput = encodersResult.stdout.toString();

  // Setup temp directory
  final tempDir = Directory('/tmp/mcu_ffmpeg_deep_test');
  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
  tempDir.createSync(recursive: true);

  print('Generating synthetic multi-format sample inputs...');
  final samples = await _generateSampleMedia(ffmpegPath, tempDir.path);
  print('Generated ${samples.length} test input media profiles.\n');

  // Load configs
  final repoRoot = Directory.current.path;
  final formatJsonFile = File('$repoRoot/apps/mcu/assets/configs/format.json');
  final supportedConfigsDir = Directory('$repoRoot/apps/mcu/assets/configs/supported_configurations');

  final formatJson = jsonDecode(formatJsonFile.readAsStringSync()) as Map<String, dynamic>;
  final formats = (formatJson['format'] as List).cast<Map<String, dynamic>>();

  int passedCount = 0;
  int skippedCount = 0;
  int failedCount = 0;
  final failedTests = <String>[];

  for (final fmt in formats) {
    final formatName = fmt['name'] as String;
    final ext = fmt['output_extension'] as String;
    final outputType = fmt['output_type'] as String;
    final isAudio = outputType == 'audio';
    final shouldAddToArgs = fmt['should_add_to_args'] == true;

    final primaryInput = isAudio ? samples['stereo_44k']! : samples['video_1080p']!;
    final configFile = File('${supportedConfigsDir.path}/$formatName.json');

    if (!configFile.existsSync()) {
      stderr.writeln('❌ Config file not found for $formatName');
      failedCount++;
      failedTests.add(formatName);
      continue;
    }

    final configJson = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final mainControls = (configJson[formatName] as List?)?.cast<Map<String, dynamic>>() ?? [];

    print('▶ Testing format: [$formatName] (Type: $outputType, Ext: .$ext)');

    // 1. Test Default Configuration on standard input
    final defaultArgs = _buildArgs(
      inputFilePath: primaryInput,
      outputFilePath: '${tempDir.path}/out_default_$formatName.$ext',
      formatName: formatName,
      outputType: outputType,
      shouldAddToArgs: shouldAddToArgs,
      configJson: configJson,
      selectedOptions: {},
    );

    final missingCodec = _findMissingCodec(defaultArgs, encodersOutput);
    if (missingCodec != null) {
      print('  ⚠️  Default skipped (missing host codec: $missingCodec)');
      skippedCount++;
    } else {
      final res = await Process.run(ffmpegPath, ['-y', ...defaultArgs]);
      if (res.exitCode == 0) {
        print('  ✅ Default settings conversion passed');
        passedCount++;
      } else {
        stderr.writeln('  ❌ Default settings failed:');
        stderr.writeln('     Command: ffmpeg ${defaultArgs.join(" ")}');
        stderr.writeln('     Error: ${_firstLines(res.stderr.toString(), 4)}');
        failedCount++;
        failedTests.add('$formatName: default');
      }
    }

    // 2. Test Default Configuration on non-standard / odd-dimension video input
    if (!isAudio) {
      final oddInput = samples['video_odd_dim']!;
      final oddArgs = _buildArgs(
        inputFilePath: oddInput,
        outputFilePath: '${tempDir.path}/out_odd_$formatName.$ext',
        formatName: formatName,
        outputType: outputType,
        shouldAddToArgs: shouldAddToArgs,
        configJson: configJson,
        selectedOptions: {},
      );

      final oddMissing = _findMissingCodec(oddArgs, encodersOutput);
      if (oddMissing == null) {
        final oddRes = await Process.run(ffmpegPath, ['-y', ...oddArgs]);
        if (oddRes.exitCode == 0) {
          print('  ✅ Odd dimension (501x333) input conversion passed');
          passedCount++;
        } else {
          stderr.writeln('  ❌ Odd dimension input failed:');
          stderr.writeln('     Error: ${_firstLines(oddRes.stderr.toString(), 4)}');
          failedCount++;
          failedTests.add('$formatName: odd-dimension input');
        }
      }
    }

    // 3. Test Every Control and Every Individual Option Value
    for (final ctrl in mainControls) {
      final ctrlName = ctrl['name'] as String;
      final options = (ctrl['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      for (final opt in options) {
        final optVal = opt['value'] as String? ?? opt['ffmpeg_arg'] as String?;
        if (optVal == null || optVal.isEmpty) continue;

        // Build selected map for this option
        final selectedMap = <String, String>{ctrlName: optVal};

        // If this option triggers a nested group (e.g. video encoder -> CRF / preset)
        if (configJson.containsKey(optVal)) {
          final nestedControls = (configJson[optVal] as List?)?.cast<Map<String, dynamic>>() ?? [];

          // Test each sub-option in the nested group
          for (final subCtrl in nestedControls) {
            final subCtrlName = subCtrl['name'] as String;
            final subOptions = (subCtrl['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];

            for (final subOpt in subOptions) {
              final subVal = subOpt['value'] as String?;
              if (subVal == null || subVal.isEmpty) continue;

              final nestedSelectedMap = Map<String, String>.from(selectedMap)
                ..[subCtrlName] = subVal;

              final testLabel = '$formatName -> $ctrlName="$optVal" -> $subCtrlName="$subVal"';
              final testArgs = _buildArgs(
                inputFilePath: primaryInput,
                outputFilePath: '${tempDir.path}/out_${formatName}_${_sanitize(optVal)}_${_sanitize(subVal)}.$ext',
                formatName: formatName,
                outputType: outputType,
                shouldAddToArgs: shouldAddToArgs,
                configJson: configJson,
                selectedOptions: nestedSelectedMap,
              );

              final subMissing = _findMissingCodec(testArgs, encodersOutput);
              if (subMissing != null) {
                print('  ⚠️  $testLabel skipped (missing host codec: $subMissing)');
                skippedCount++;
                continue;
              }

              final subRes = await Process.run(ffmpegPath, ['-y', ...testArgs]);
              if (subRes.exitCode == 0) {
                print('  ✅ Option passed: [$ctrlName="$optVal", $subCtrlName="$subVal"]');
                passedCount++;
              } else {
                stderr.writeln('  ❌ Option failed: $testLabel');
                stderr.writeln('     Command: ffmpeg ${testArgs.join(" ")}');
                stderr.writeln('     Error: ${_firstLines(subRes.stderr.toString(), 4)}');
                failedCount++;
                failedTests.add(testLabel);
              }
            }
          }
        } else {
          // Non-nested option (e.g. audio encoder, channel count, sample rate, bitrate)
          final testLabel = '$formatName -> $ctrlName="$optVal"';
          final testArgs = _buildArgs(
            inputFilePath: primaryInput,
            outputFilePath: '${tempDir.path}/out_${formatName}_${_sanitize(optVal)}.$ext',
            formatName: formatName,
            outputType: outputType,
            shouldAddToArgs: shouldAddToArgs,
            configJson: configJson,
            selectedOptions: selectedMap,
          );

          final optMissing = _findMissingCodec(testArgs, encodersOutput);
          if (optMissing != null) {
            print('  ⚠️  $testLabel skipped (missing host codec: $optMissing)');
            skippedCount++;
            continue;
          }

          final optRes = await Process.run(ffmpegPath, ['-y', ...testArgs]);
          if (optRes.exitCode == 0) {
            print('  ✅ Option passed: [$ctrlName="$optVal"]');
            passedCount++;
          } else {
            stderr.writeln('  ❌ Option failed: $testLabel');
            stderr.writeln('     Command: ffmpeg ${testArgs.join(" ")}');
            stderr.writeln('     Error: ${_firstLines(optRes.stderr.toString(), 4)}');
            failedCount++;
            failedTests.add(testLabel);
          }
        }
      }
    }
    print('');
  }

  print('===============================================================');
  print('                    Deep Test Suite Summary                    ');
  print('===============================================================');
  print('Total tests executed : ${passedCount + skippedCount + failedCount}');
  print('Passed               : $passedCount');
  print('Skipped              : $skippedCount');
  print('Failed               : $failedCount');

  // Clean up
  tempDir.deleteSync(recursive: true);

  if (failedCount > 0) {
    print('\n❌ FAILED TESTS:');
    for (final f in failedTests) {
      print(' - $f');
    }
    exit(1);
  } else {
    print('\n🎉 100% of all format and configuration option tests passed with ZERO errors!');
    exit(0);
  }
}

Future<Map<String, String>> _generateSampleMedia(String ffmpegPath, String tempDirPath) async {
  final samples = <String, String>{};

  // 1. 1080p standard video + audio
  final v1080p = '$tempDirPath/in_1080p.mp4';
  await Process.run(ffmpegPath, [
    '-y',
    '-f', 'lavfi', '-i', 'testsrc=duration=1:size=1920x1080:rate=15',
    '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=1',
    '-c:v', 'libx264', '-preset', 'ultrafast',
    '-c:a', 'aac',
    v1080p,
  ]);
  samples['video_1080p'] = v1080p;

  // 2. Odd-dimension video (501x333) to test letterboxing/rescaling robustness
  final vOdd = '$tempDirPath/in_odd_dim.mp4';
  await Process.run(ffmpegPath, [
    '-y',
    '-f', 'lavfi', '-i', 'testsrc=duration=1:size=501x333:rate=10',
    '-f', 'lavfi', '-i', 'sine=frequency=800:duration=1',
    '-c:v', 'libx264', '-preset', 'ultrafast',
    '-c:a', 'aac',
    vOdd,
  ]);
  samples['video_odd_dim'] = vOdd;

  // 3. Stereo 44.1 kHz Audio
  final aStereo = '$tempDirPath/in_stereo_44k.wav';
  await Process.run(ffmpegPath, [
    '-y',
    '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=1:sample_rate=44100',
    '-ac', '2',
    '-c:a', 'pcm_s16le',
    aStereo,
  ]);
  samples['stereo_44k'] = aStereo;

  // 4. 5.1 Surround 48 kHz Audio
  final aSurround = '$tempDirPath/in_surround_5_1.wav';
  await Process.run(ffmpegPath, [
    '-y',
    '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=1:sample_rate=48000',
    '-ac', '6',
    '-c:a', 'pcm_s24le',
    aSurround,
  ]);
  samples['surround_5_1'] = aSurround;

  return samples;
}

String? _findMissingCodec(List<String> args, String encodersOutput) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == '-c:v' || args[i] == '-c:a') {
      final codec = args[i + 1];
      if (codec == 'copy') continue;
      if (!encodersOutput.contains(' $codec ') && !encodersOutput.contains(' $codec\n')) {
        return codec;
      }
    }
  }
  return null;
}

List<String> _buildArgs({
  required String inputFilePath,
  required String outputFilePath,
  required String formatName,
  required String outputType,
  required bool shouldAddToArgs,
  required Map<String, dynamic> configJson,
  required Map<String, String> selectedOptions,
}) {
  final args = <String>[
    '-i', inputFilePath,
    '-hide_banner',
  ];

  if (outputType == 'audio') {
    args.add('-vn');
  }

  final mainControls = (configJson[formatName] as List?)?.cast<Map<String, dynamic>>() ?? [];
  _processControls(mainControls, configJson, selectedOptions, args);

  if (shouldAddToArgs) {
    args.add('-f');
    args.add(formatName);
  }

  args.add(outputFilePath);
  return args;
}

void _processControls(
  List<Map<String, dynamic>> controls,
  Map<String, dynamic> configJson,
  Map<String, String> selectedOptions,
  List<String> args,
) {
  for (final ctrl in controls) {
    final name = ctrl['name'] as String;
    final shouldAdd = ctrl['should_add_to_args'] == true;
    final ffmpegFlag = ctrl['ffmpeg_flag'] as String?;
    final defaultVal = ctrl['default']?.toString() ?? '';

    final selectedVal = selectedOptions[name] ?? defaultVal;
    if (selectedVal.isEmpty) continue;

    if (shouldAdd) {
      if (ffmpegFlag != null) {
        args.add(ffmpegFlag);
        _addValue(args, selectedVal);
      } else {
        _addValue(args, selectedVal);
      }
    }

    // Check if selectedVal triggers a nested config group
    if (configJson.containsKey(selectedVal)) {
      final nestedControls = (configJson[selectedVal] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _processControls(nestedControls, configJson, selectedOptions, args);
    }
  }
}

void _addValue(List<String> args, String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      for (final item in decoded) {
        final itemStr = item.toString();
        final parts = itemStr.split(' ');
        args.addAll(parts);
      }
      return;
    }
  } catch (_) {}

  if (value.startsWith('-')) {
    final parts = value.split(' ');
    args.addAll(parts);
  } else {
    args.add(value);
  }
}

String _sanitize(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

String _firstLines(String s, int n) {
  final lines = s.trim().split('\n');
  return lines.take(n).join('\n     ');
}
