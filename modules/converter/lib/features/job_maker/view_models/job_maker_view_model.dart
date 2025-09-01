import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

class JobMakerViewModel extends ChangeNotifier {
  final FormatConfigModel formatConfigModel;
  final Map<String, String?> translations;

  JobMakerViewModel({
    required this.formatConfigModel,
    required this.translations,
  });

  List<File> _selectedFiles = [];
  List<File> get selectedFiles => _selectedFiles;

  /// Map of output file names.
  Map<String, String?> _outputFileNames = const {};
  FormatEntry? _selectedFormatEntry;
  Map<String, List<ConfigControl>> _configControls = const {};
  Map<String, String> _selectedValues = const {};

  String? _outputDirectoryPath = SettingsBox().lastOutputDirectoryPath;

  Map<String, Failure> _errorPaths = {};
  Map<String, Failure> get errorPaths => _errorPaths;

  FormatEntry? get selectedFormatEntry => _selectedFormatEntry;

  bool _shouldRememberConfigs = false;
  bool get shouldRememberConfigs => _shouldRememberConfigs;
  void setRememberConfigs(bool value) {
    _shouldRememberConfigs = value;
    notifyListeners();
  }

  bool _shouldRememberOutputFolder = false;
  bool get shouldRememberOutputFolder => _shouldRememberOutputFolder;
  void setRememberOutputFolder(bool value) {
    _shouldRememberOutputFolder = value;
    notifyListeners();
  }

  Map<String, List<ConfigControl>> get configControls => _configControls;
  Map<String, String> get selectedValues => _selectedValues;

  String? get outputDirectoryPath => _outputDirectoryPath;
  Map<String, String?> get outputFileNames => _outputFileNames;

  void setSelectedValue(String name, String value) {
    final clone = {..._selectedValues};
    clone[name] = value;
    _selectedValues = clone;
    notifyListeners();
  }

  void setOutputDirectoryPath(String? path) {
    _outputDirectoryPath = path;
    notifyListeners();

    refreshOutputFileNames();
  }

  void addFiles(final List<File> files) {
    final clone = [
      ..._selectedFiles,
    ];
    final List<String> selectedPaths = clone.map((e) => e.path).toList();
    for (final file in files) {
      if (selectedPaths.contains(file.path)) {
        continue;
      }
      clone.add(file);
    }
    _selectedFiles = clone;
    notifyListeners();
    refreshOutputFileNames();
  }

  void removeFile(File file) {
    final clone = [
      ..._selectedFiles,
    ];
    clone.removeWhere((e) => e.path == file.path);
    _selectedFiles = clone;
    notifyListeners();
    refreshOutputFileNames();
  }

  void refreshOutputFileNames() {
    final formatEntry = _selectedFormatEntry;
    if (formatEntry == null) {
      return;
    }

    for (final file in _selectedFiles) {
      final filePath = file.path;
      if (_outputFileNames.containsKey(filePath)) {
        continue;
      }
      final outputFileName = CommandBuilder.getOutputFileName(
        inputFilePath: filePath,
        formatEntry: formatEntry,
      );
      _outputFileNames[filePath] = outputFileName;
    }

    final clone = {
      ..._outputFileNames,
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
    _outputFileNames = clone;
    notifyListeners();

    _validateSelectedPaths();
  }

  Future<void> _validateSelectedPaths() async {
    final selectedPaths = {..._outputFileNames};
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
    if (formatEntry == null) {
      return;
    }

    // Clear all file names.
    final outputFileNames = {..._outputFileNames};
    for (final key in outputFileNames.keys) {
      outputFileNames[key] = null;
    }
    _outputFileNames = outputFileNames;

    // Initialize selected config state to defaults.
    // Then overwrite with last known configurations.
    _selectedValues = {
      ..._getDefaultConfigValue(
        _configControls,
        formatEntry,
      ),
      ...formatEntry.lastKnownConfigurations,
    };
    notifyListeners();
  }

  void resetConfigurations() {
    final formatEntry = _selectedFormatEntry;
    if (formatEntry == null) {
      return;
    }
    _selectedValues = {
      ..._getDefaultConfigValue(
        _configControls,
        formatEntry,
      ),
    };
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

    if (formatEntry == null) {
      throw const NoOutputFormatFailure();
    }

    if (outputDirectoryPath == null) {
      throw const NoOutputFolderFailure();
    }

    final convertTempFolder = await FileUtils.getConvertTemporaryDirectory(
      null,
    );
    final outputFileNames = {..._outputFileNames};
    final errorPaths = await findInvalidPaths(
      selectedPaths: outputFileNames,
      outputDirectoryPath: outputDirectoryPath,
    );
    if (errorPaths.isNotEmpty) {
      throw errorPaths.values.first;
    }

    final List<ConvertJob> result = [];
    for (final inputFilePath in outputFileNames.keys) {
      final jobId = kUuid.v4();
      final fileName = outputFileNames[inputFilePath];
      if (fileName == null) {
        throw FileNameIsNotSetFailure(inputFilePath);
      }

      final newInputFilePath = await FileUtils.movePickedFileToInputFolder(
        jobId: jobId,
        inputFilePath: inputFilePath,
      );

      if (newInputFilePath == null) {
        throw InputFileNotExistFailure(inputFilePath);
      }

      final outputFilePath = CommandBuilder.getOutputFilePath(
        inputFilePath: newInputFilePath,
        formatEntry: formatEntry,
        outputDirectoryPath: join(convertTempFolder.path, jobId),
        overrideFileName: fileName,
      );
      final command = CommandBuilder.buildCommand(
        inputFilePath: newInputFilePath,
        formatEntry: formatEntry,
        selectedValues: selectedValues,
        availableControls: availableControls,
        outputFilePath: outputFilePath,
      );

      final now = DateTime.now();
      final job = ConvertJob(
        id: jobId,
        inputFilePath: newInputFilePath,
        outputFileName: fileName,
        outputExtension: formatEntry.outputExtension,
        outputDirectoryPath: outputDirectoryPath,
        command: command,
        convertedFilePath: outputFilePath,
        createdAt: now,
        updatedAt: now,
      );
      result.add(job);
    }

    if (shouldRememberConfigs) {
      formatEntry.setLastKnownConfigurations(selectedValues);
    }
    if (shouldRememberOutputFolder) {
      SettingsBox().lastOutputDirectoryPath = outputDirectoryPath;
    }

    return result;
  }

  Future<Map<String, Failure>> findInvalidPaths({
    required Map<String, String?> selectedPaths,
    required String outputDirectoryPath,
  }) async {
    final Map<String, Failure> errorPaths = {};
    final Set<String> outputPaths = {};
    for (final entry in selectedPaths.entries) {
      final filePath = entry.key;
      final fileName = entry.value;

      /// Check if file name is set.
      if (fileName == null) {
        throw Exception('File name is null');
      }

      /// Check for input file existence.
      if (!await FileUtils.isFileExist(filePath)) {
        errorPaths[filePath] = InputFileNotExistFailure(filePath);
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
          errorPaths[filePath] = DuplicatedFilePathFailure(outputFilePath);
          printLog(
            '[JobMakerViewModel]: Duplicated file path: $outputFilePath',
          );
          continue;
        }
        outputPaths.add(outputFilePath);

        /// Check if output file already exists.
        if (await FileUtils.isFileExist(outputFilePath)) {
          errorPaths[filePath] = OutputFileAlreadyExistsFailure(outputFilePath);
          printLog(
            '[JobMakerViewModel]: Output file already exists: $outputFilePath',
          );
          continue;
        }
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
    if (_selectedFiles.isEmpty) {
      return const NoFilesSelectedFailure();
    }

    return null;
  }

  Failure? _checkOutputFormatError() {
    if (_selectedFormatEntry == null) {
      return const NoOutputFormatFailure();
    }

    return null;
  }

  Failure? _checkOutputConfigError() {
    if (_selectedValues.isEmpty) {
      return const NoOutputConfigFailure();
    }

    return null;
  }

  Failure? _checkPreviewError() {
    if (_outputDirectoryPath == null) {
      return const NoOutputFolderFailure();
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

    printLog('selectedValues: $selectedValues');
    printLog('Config controls: ${configControls.keys}');
    printLog('Keys: $keys');

    final List<ConfigControl> controls = [];
    for (final key in keys) {
      final controlsOfKey = configControls[key];
      if (controlsOfKey is! List<ConfigControl>) {
        continue;
      }
      for (final control in controlsOfKey) {
        printLog('Adding control 1: ${control.name} of key: $key');
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

          printLog('Adding control 2: ${control.name} of key: $value');
          controls.addAll(controlOfValue);
        }
      }
    }

    printLog('Controls: ${controls.map((e) => e.name)}');

    return controls;
  }

  void reorderFile(int oldIndex, int newIndex) {
    final clone = [..._selectedFiles];
    final file = clone.removeAt(oldIndex);
    clone.insert(newIndex, file);
    _selectedFiles = clone;
    notifyListeners();
  }

  void setOutputFileName(String path, String newName) {
    final clone = {..._outputFileNames};
    clone[path] = newName;
    _outputFileNames = clone;
    notifyListeners();
    _validateSelectedPaths();
  }

  void loadPreviousConfigurations() {
    final formatEntry = _selectedFormatEntry;
    if (formatEntry == null) {
      return;
    }
    _selectedValues = {
      ..._getDefaultConfigValue(
        _configControls,
        formatEntry,
      ),
      ...formatEntry.lastKnownConfigurations,
    };
    notifyListeners();
  }
}
