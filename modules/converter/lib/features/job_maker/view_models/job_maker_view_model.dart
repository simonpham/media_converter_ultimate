import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';

class JobMakerViewModel extends ChangeNotifier {
  final FormatConfigModel formatConfigModel;
  final Map<String, String?> translations;

  JobMakerViewModel({
    required this.formatConfigModel,
    required this.translations,
  });

  /// Map of file path to file name.
  Map<String, String?> _selectedFilePaths = const {};
  FormatEntry? _selectedFormatEntry;
  Map<String, List<ConfigControl>> _configControls = const {};
  Map<String, String> _selectedValues = const {};

  String? _outputDirectoryPath;
  String? _outputDirectoryName;

  Set<String> _errorPaths = {};
  Set<String> get errorPaths => _errorPaths;

  Map<String, String?> get selectedFiles => _selectedFilePaths;
  FormatEntry? get selectedFormatEntry => _selectedFormatEntry;
  Map<String, List<ConfigControl>> get configControls => _configControls;
  Map<String, String> get selectedValues => _selectedValues;

  String? get outputDirectoryPath => _outputDirectoryPath;
  String? get outputDirectoryName => _outputDirectoryName;

  void setSelectedValue(String name, String value) {
    final clone = {..._selectedValues};
    clone[name] = value;
    _selectedValues = clone;
    notifyListeners();
  }

  void setOutputDirectoryPath(String? path, String? name) {
    _outputDirectoryPath = path;
    _outputDirectoryName = name;
    notifyListeners();

    refreshOutputFileNames();
  }

  void addFiles(final List<File> files) {
    final clone = {
      ..._selectedFilePaths,
    };
    for (final file in files) {
      if (clone.containsKey(file.path)) {
        continue;
      }
      clone[file.path] = null;
    }
    _selectedFilePaths = clone;
    notifyListeners();
    refreshOutputFileNames();
  }

  void removeFile(File file) {
    final clone = {
      ..._selectedFilePaths,
    };
    if (clone.containsKey(file.path)) {
      clone.remove(file.path);
    }
    _selectedFilePaths = clone;
    notifyListeners();
    refreshOutputFileNames();
  }

  void refreshOutputFileNames() {
    final formatEntry = _selectedFormatEntry;
    if (formatEntry == null) {
      return;
    }
    final clone = {
      ..._selectedFilePaths,
    };
    for (final entry in clone.entries) {
      final filePath = entry.key;
      final fileName = entry.value;
      if (fileName != null) {
        continue;
      }
      final outputFileName = CommandBuilder.getOutputFileName(
        inputFilePath: filePath,
        formatEntry: formatEntry,
      );
      clone[filePath] = outputFileName;
    }
    _selectedFilePaths = clone;
    notifyListeners();

    _validateSelectedPaths();
  }

  Future<void> _validateSelectedPaths() async {
    final selectedPaths = {..._selectedFilePaths};
    final formatEntry = _selectedFormatEntry;
    final outputDirectoryPath = _outputDirectoryPath;
    if (formatEntry == null || outputDirectoryPath == null) {
      return;
    }
    final errorPaths = await findInvalidPaths(
      selectedPaths: selectedPaths,
      outputDirectoryPath: outputDirectoryPath,
    );
    _errorPaths = errorPaths;
    notifyListeners();
  }

  Future<void> setSelectedFormatEntry(FormatEntry formatEntry) async {
    if (_selectedFormatEntry == formatEntry) {
      return;
    }
    _selectedFormatEntry = formatEntry;
    notifyListeners();
    await _loadConfigModel();
    _initOutputConfig();
  }

  void _initOutputConfig() {
    final formatEntry = _selectedFormatEntry;
    if (formatEntry == null) return;
    final selectedPaths = {..._selectedFilePaths};
    for (final key in selectedPaths.keys) {
      selectedPaths[key] = null;
    }
    _selectedFilePaths = selectedPaths;
    // Initialize selected config state to defaults (if needed)
    _selectedValues = _getDefaultConfigValue(
      _configControls,
      formatEntry,
    );
    notifyListeners();
  }

  Future<void> _loadConfigModel() async {
    final formatEntry = _selectedFormatEntry;
    if (formatEntry == null) {
      return;
    }
    final configControls = await formatConfigModel.loadConfigControls(
      formatEntry,
    );
    _configControls = configControls;
    notifyListeners();
  }

  Future<List<ConvertJob>> cook() async {
    final formatEntry = _selectedFormatEntry;
    final selectedValues = _selectedValues;
    final outputDirectoryPath = _outputDirectoryPath;
    if (formatEntry == null || outputDirectoryPath == null) {
      printLog(
        '[JobMakerViewModel]: Output format or directory is null',
      );
      return [];
    }

    final convertTempFolder = await FileUtils.getConvertTemporaryDirectory();
    final selectedPaths = {..._selectedFilePaths};
    printLog('[JobMakerViewModel]: Finding invalid paths...');
    final errorPaths = await findInvalidPaths(
      selectedPaths: selectedPaths,
      outputDirectoryPath: outputDirectoryPath,
    );
    if (errorPaths.isNotEmpty) {
      printLog('[JobMakerViewModel]: Selected path is invalid: $errorPaths');
      return [];
    }

    return selectedPaths.keys.map((inputFilePath) {
      final fileName = selectedPaths[inputFilePath];
      if (fileName == null) {
        throw Exception('File name is null');
      }
      final outputFilePath = CommandBuilder.getOutputFilePath(
        inputFilePath: inputFilePath,
        formatEntry: formatEntry,
        outputDirectoryPath: convertTempFolder.path,
        overrideFileName: fileName,
      );
      final command = CommandBuilder.buildCommand(
        inputFilePath: inputFilePath,
        formatEntry: formatEntry,
        selectedValues: selectedValues,
        availableControls: availableControls,
        supportedCodec: formatConfigModel.supportedCodec,
        outputFilePath: outputFilePath,
      );

      return ConvertJob(
        id: UniqueKey().toString(),
        inputFilePath: inputFilePath,
        outputFileName: fileName,
        outputDirectoryPath: outputDirectoryPath,
        command: command,
      );
    }).toList();
  }

  Future<Set<String>> findInvalidPaths({
    required Map<String, String?> selectedPaths,
    required String outputDirectoryPath,
  }) async {
    final Set<String> errorPaths = {};
    final Set<String> outputPaths = {};
    for (final entry in selectedPaths.entries) {
      final filePath = entry.key;
      final fileName = entry.value;

      /// Check if file name is set.
      if (fileName == null) {
        throw Exception('File name is null');
      }

      /// Check for file existence.
      if (!await FileUtils.isFileExist(filePath)) {
        errorPaths.add(filePath);
        printLog('[JobMakerViewModel]: File not exist: $filePath');
        continue;
      }

      /// Check for output file existence.
      final formatEntry = _selectedFormatEntry;
      final outputDirectoryPath = _outputDirectoryPath;
      if (formatEntry != null && outputDirectoryPath != null) {
        final outputFilePath = CommandBuilder.getOutputFilePath(
          inputFilePath: filePath,
          formatEntry: formatEntry,
          outputDirectoryPath: outputDirectoryPath,
          overrideFileName: fileName,
        );

        /// Check for duplicated file path.
        if (outputPaths.contains(outputFilePath)) {
          errorPaths.add(filePath);
          printLog(
            '[JobMakerViewModel]: Duplicated file path: $outputFilePath',
          );
          continue;
        }
        outputPaths.add(outputFilePath);

        /// Check if output file exists.
        int retryCount = 0;
        do {
          try {
            if (!await FileUtils.checkOutputWritability(
              outputFolderPath: outputDirectoryPath,
              fileName: fileName,
            )) {
              errorPaths.add(filePath);
              continue;
            }
            break;
          } on AlreadyRunningException catch (_) {
            if (retryCount >= 3) {
              throw Exception('Output writability check failed');
            }
            await Future.delayed(const Duration(milliseconds: 500));
            retryCount++;
            continue;
          } catch (err, trace) {
            printError(err, trace);
            rethrow;
          }
        } while (true);
      }
    }
    return errorPaths;
  }

  Failure? checkError(JobMakerSteps currentStep) {
    return switch (currentStep) {
      JobMakerSteps.pickFiles => _checkPickFilesError(),
      JobMakerSteps.chooseOutputFormat => _checkOutputFormatError(),
      JobMakerSteps.customizeConfigs => _checkOutputConfigError(),
      JobMakerSteps.preview => _checkPreviewError(),
    };
  }

  Failure? _checkPickFilesError() {
    if (_selectedFilePaths.isEmpty) {
      return const Failure('No files selected.');
    }

    return null;
  }

  Failure? _checkOutputFormatError() {
    if (_selectedFormatEntry == null) {
      return const Failure('No output format selected.');
    }

    return null;
  }

  Failure? _checkOutputConfigError() {
    if (_selectedValues.isEmpty) {
      return const Failure('No output config selected.');
    }

    return null;
  }

  Failure? _checkPreviewError() {
    if (_outputDirectoryPath == null) {
      return const Failure('Output directory is null.');
    }

    return null;
  }

  Map<String, String> _getDefaultConfigValue(
    Map<String, List<ConfigControl>> configControls,
    FormatEntry formatEntry,
  ) {
    final Map<String, String> defaultValues = {};
    for (final entry in configControls.entries) {
      final configControls = entry.value;
      for (final configControl in configControls) {
        final defaultValue = configControl.defaultValue;
        if (defaultValue == null) {
          continue;
        }
        defaultValues[configControl.name] = defaultValue;
      }
    }
    return defaultValues;
  }

  List<ConfigControl> get availableControls {
    final selectedFormat = _selectedFormatEntry;
    if (selectedFormat == null) {
      return [];
    }

    final supportedCodec =
        formatConfigModel.supportedCodec[selectedFormat.name];
    if (supportedCodec == null) {
      return [];
    }

    final configControls = _configControls;
    final selectedValues = _selectedValues;
    final List<String> selectedKeys = [];
    for (final value in selectedValues.values) {
      try {
        final valueAsList = List<String>.from(jsonDecode(value));
        selectedKeys.addAll(valueAsList);
        continue;
      } catch (_) {}
      selectedKeys.add(value);
    }
    final List<String> keys = [
      selectedFormat.name,
      ?switch (selectedFormat.outputType) {
        OutputType.audio => kCommonAudioKey,
        OutputType.video => kCommonVideoKey,
        _ => null,
      },
    ];

    final codecControl = selectedFormat.getEncoderPickerControl(supportedCodec);
    final List<ConfigControl> controls = [
      codecControl,
    ];
    for (final key in keys) {
      final controlsOfKey = configControls[key];
      if (controlsOfKey is! List<ConfigControl>) {
        continue;
      }
      for (final control in controlsOfKey) {
        controls.add(control);

        for (final option in control.options) {
          final value = option.value;
          if (!selectedKeys.contains(value)) {
            continue;
          }

          final controlOfValue = configControls[value];
          if (controlOfValue is! List<ConfigControl>) {
            continue;
          }

          controls.addAll(controlOfValue);
        }
      }
    }

    return controls;
  }
}
