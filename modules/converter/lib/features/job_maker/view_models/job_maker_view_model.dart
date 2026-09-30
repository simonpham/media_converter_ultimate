import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

class JobMakerViewModel({
  required final FormatConfigModel formatConfigModel,
  required final Map<String, String?> translations,
}) extends ChangeNotifier {
  FileService get _fileService => injector<FileService>();

  List<File> _selectedFiles = [];
  List<File> get selectedFiles => _selectedFiles;

  List<File> _excludedFiles = [];
  List<File> get excludedFiles => _excludedFiles;

  /// Map of output file names.
  Map<String, String?> _outputFileNames = const {};
  FormatEntry? _selectedFormatEntry;
  Map<String, List<ConfigControl>> _configControls = const {};
  Map<String, String> _selectedValues = const {};

  String? _outputDirectoryPath = SettingsBox().lastOutputDirectoryPath;

  Map<String, Failure> _errorPaths = {};
  Map<String, Failure> get errorPaths => _errorPaths;
  int _pathValidationRevision = 0;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _pathValidationRevision++;
    super.dispose();
  }

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
    _selectedValues = ConfigurationSelection.normalizeValues(
      groups: _configControls,
      roots: _rootConfigKeys,
      overrides: clone,
    );
    notifyListeners();
  }

  void setOutputDirectoryPath(String? path) {
    _outputDirectoryPath = path;
    notifyListeners();

    refreshOutputFileNames();
  }

  void clearExcludedFiles() {
    _excludedFiles = [];
    notifyListeners();
  }

  Future<void> addFiles(List<File> files) async {
    final shouldExcludeNonMediaFiles = SettingsBox().shouldExcludeNonMediaFiles;
    final isCheckingCustomExtensions = shouldExcludeNonMediaFiles == false;
    final excludedFileExtensions = SettingsBox().excludedFileExtensions;
    final clone = [
      ..._selectedFiles,
    ];
    final List<File> excludedFilesClone = [
      ..._excludedFiles,
    ];
    final selectedPaths = clone.map((e) => e.path).toSet();
    for (final file in files) {
      if (selectedPaths.contains(file.path)) {
        continue;
      }
      final fileExtension = file.fileExtension;

      /// Check file mime type for non-media files.
      if (shouldExcludeNonMediaFiles &&
          !(await _fileService.isMediaFile(file))) {
        printLog(
          '[FilePicker]: File ${file.path} mime type is not media: $fileExtension. Skipping.',
        );
        excludedFilesClone.add(file);
        continue;
      }

      /// Check if file extension is excluded.
      if (isCheckingCustomExtensions &&
          excludedFileExtensions.contains(fileExtension)) {
        printLog(
          '[FilePicker]: File ${file.path} extension is excluded: $fileExtension. Skipping.',
        );
        excludedFilesClone.add(file);
        continue;
      }

      selectedPaths.add(file.path);
      clone.add(file);
    }
    if (_isDisposed) {
      return;
    }
    _selectedFiles = clone;
    _excludedFiles = excludedFilesClone;
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
    _outputFileNames = {
      for (final file in _selectedFiles)
        file.path:
            _outputFileNames[file.path] ??
            (formatEntry == null
                ? null
                : CommandBuilder.getOutputFileName(
                    inputFilePath: file.path,
                    formatEntry: formatEntry,
                  )),
    };
    notifyListeners();
    unawaited(_validateSelectedPaths());
  }

  Future<void> _validateSelectedPaths() async {
    final revision = ++_pathValidationRevision;
    final selectedPaths = {..._outputFileNames};
    final formatEntry = _selectedFormatEntry;
    final outputDirectoryPath = _outputDirectoryPath;
    if (formatEntry == null || outputDirectoryPath == null) {
      _errorPaths = {};
      notifyListeners();
      return;
    }
    final errorPaths = await findInvalidPaths(
      selectedPaths: selectedPaths,
      outputDirectoryPath: outputDirectoryPath,
    );
    if (_isDisposed || revision != _pathValidationRevision) {
      return;
    }
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
    if (_isDisposed || _selectedFormatEntry != formatEntry) {
      return;
    }
    _initOutputConfig();
    refreshOutputFileNames();
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
    _selectedValues = ConfigurationSelection.normalizeValues(
      groups: _configControls,
      roots: _rootConfigKeys,
      overrides: formatEntry.lastKnownConfigurations,
    );
    notifyListeners();
  }

  void resetConfigurations() {
    final formatEntry = _selectedFormatEntry;
    if (formatEntry == null) {
      return;
    }
    _selectedValues = ConfigurationSelection.normalizeValues(
      groups: _configControls,
      roots: _rootConfigKeys,
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
    if (_isDisposed || _selectedFormatEntry != formatEntry) {
      return;
    }
    _configControls = configControls;
    notifyListeners();
  }

  Future<List<ConvertJob>> cook() async {
    final formatEntry = _selectedFormatEntry;
    final selectedValues = {..._selectedValues};
    final outputDirectoryPath = _outputDirectoryPath;
    final controls = availableControls;
    final outputFileNames = {
      for (final file in _selectedFiles) file.path: _outputFileNames[file.path],
    };

    if (outputFileNames.isEmpty) {
      throw const NoFilesSelectedFailure();
    }

    if (formatEntry == null) {
      throw const NoOutputFormatFailure();
    }

    if (outputDirectoryPath == null) {
      throw const NoOutputFolderFailure();
    }

    final convertTempFolder = await _fileService.getConvertTemporaryDirectory(
      null,
    );
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

      final appCachedDir = await getApplicationCacheDirectory();
      final newInputFilePath = await _fileService.movePickedFileToInputFolder(
        jobId: jobId,
        inputFilePath: inputFilePath,
        appCachedPath: appCachedDir.path,
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
        availableControls: controls,
        outputFilePath: outputFilePath,
        threadCount: SettingsBox().threadCount,
        configurationKeys: _configControls.keys.toSet(),
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
        errorPaths[filePath] = FileNameIsNotSetFailure(filePath);
        continue;
      }

      /// Check for input file existence.
      if (!await _fileService.isFileExist(filePath)) {
        errorPaths[filePath] = InputFileNotExistFailure(filePath);
        printLog('[JobMakerViewModel]: File not exist: $filePath');
        continue;
      }

      /// Check for output file existence.
      final formatEntry = _selectedFormatEntry;
      if (formatEntry != null) {
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
        if (await _fileService.isFileExist(outputFilePath)) {
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

  List<String> get _rootConfigKeys {
    final selectedFormat = _selectedFormatEntry;
    if (selectedFormat == null) {
      return const [];
    }
    final shouldAddCommonConfigs = !kSingleStreamFormats.contains(
      selectedFormat.name,
    );
    return [
      selectedFormat.name,
      if (shouldAddCommonConfigs)
        ...switch (selectedFormat.outputType) {
          OutputType.audio => [kCommonAudioKey],
          OutputType.video => [kCommonVideoKey],
          _ => const <String>[],
        },
    ];
  }

  List<ConfigControl> get availableControls =>
      ConfigurationSelection.resolveControls(
        groups: _configControls,
        roots: _rootConfigKeys,
        selectedValues: _selectedValues,
      );

  void reorderFile(int oldIndex, int newIndex) {
    final clone = [..._selectedFiles];
    final file = clone.removeAt(oldIndex);
    clone.insert(newIndex, file);
    _selectedFiles = clone;
    refreshOutputFileNames();
  }

  void setOutputFileName(String path, String newName) {
    if (!_selectedFiles.any((file) => file.path == path)) {
      return;
    }
    final clone = {..._outputFileNames};
    clone[path] = newName;
    _outputFileNames = clone;
    notifyListeners();
    unawaited(_validateSelectedPaths());
  }

  void loadPreviousConfigurations() {
    final formatEntry = _selectedFormatEntry;
    if (formatEntry == null) {
      return;
    }
    _selectedValues = ConfigurationSelection.normalizeValues(
      groups: _configControls,
      roots: _rootConfigKeys,
      overrides: formatEntry.lastKnownConfigurations,
    );
    notifyListeners();
  }
}
