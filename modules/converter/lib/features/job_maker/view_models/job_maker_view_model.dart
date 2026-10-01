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
  final _fileContentTypes = <String, FileContentType>{};
  FileContentType fileContentType(File file) =>
      _fileContentTypes[file.path] ?? .other;

  List<File> _excludedFiles = [];
  List<File> get excludedFiles => _excludedFiles;

  /// Map of output file names.
  Map<String, String?> _outputFileNames = const {};
  FormatEntry? _selectedFormatEntry;
  ConversionPreset? _selectedPreset;
  ConversionPreset? get selectedPreset => _selectedPreset;
  bool _showPresetGrid = true;
  bool get showPresetGrid => _showPresetGrid;

  void togglePresetLayout() {
    _showPresetGrid = !_showPresetGrid;
    notifyListeners();
  }

  /// Return to custom editing without discarding the current settings.
  void clearPreset() {
    if (_isLoadingFormat || _selectedPreset == null) return;
    _selectedPreset = null;
    notifyListeners();
  }

  int _configurationRevision = 0;
  bool _isLoadingFormat = false;
  bool get isLoadingFormat => _isLoadingFormat;
  String _formatQuery = '';
  String get formatQuery => _formatQuery;
  bool _trimEnabled = false;
  bool get trimEnabled => _trimEnabled;
  String _trimStartText = '';
  String get trimStartText => _trimStartText;
  String _trimEndText = '';
  String get trimEndText => _trimEndText;

  void setTrimEnabled(bool value) {
    if (_trimEnabled == value) return;
    _trimEnabled = value;
    _selectedPreset = null;
    notifyListeners();
  }

  void setTrimStartText(String value) {
    if (_trimStartText == value) return;
    _trimStartText = value;
    _selectedPreset = null;
    notifyListeners();
  }

  void setTrimEndText(String value) {
    if (_trimEndText == value) return;
    _trimEndText = value;
    _selectedPreset = null;
    notifyListeners();
  }

  void setTrimRange(ConversionTrim trim) {
    _trimEnabled = true;
    _trimStartText = MediaTimestamp.display(trim.start);
    _trimEndText = trim.end == null ? '' : MediaTimestamp.display(trim.end!);
    _selectedPreset = null;
    notifyListeners();
  }

  Failure? get trimStartFailure =>
      _trimEnabled &&
          _trimStartText.trim().isNotEmpty &&
          MediaTimestamp.parse(_trimStartText) == null
      ? const InvalidTrimTimestampFailure()
      : null;

  Failure? get trimEndFailure =>
      _trimEnabled &&
          _trimEndText.trim().isNotEmpty &&
          MediaTimestamp.parse(_trimEndText) == null
      ? const InvalidTrimTimestampFailure()
      : null;

  Failure? get trimRangeFailure {
    if (!_trimEnabled || trimStartFailure != null || trimEndFailure != null) {
      return null;
    }
    final start = MediaTimestamp.parse(_trimStartText) ?? Duration.zero;
    final end = MediaTimestamp.parse(_trimEndText);
    return end != null && end <= start ? const InvalidTrimRangeFailure() : null;
  }

  Failure? get trimFailure =>
      trimStartFailure ?? trimEndFailure ?? trimRangeFailure;

  ConversionTrim? get selectedTrim => !_trimEnabled || trimFailure != null
      ? null
      : .new(
          start: MediaTimestamp.parse(_trimStartText) ?? Duration.zero,
          end: MediaTimestamp.parse(_trimEndText),
        );

  List<ConversionPreset> get availablePresets => ConversionPreset.values
      .where(
        (preset) => formatConfigModel.formats.any(
          (format) => format.name == preset.formatName,
        ),
      )
      .toList();

  List<FormatEntry> get visibleFormats {
    final query = _formatQuery.trim().toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );
    return formatConfigModel.formats
        .where(
          (format) =>
              format.name.toLowerCase().contains(query) ||
              format.outputExtension.toLowerCase().contains(query),
        )
        .toList();
  }

  void setFormatQuery(String query) {
    if (_formatQuery == query) return;
    _formatQuery = query;
    notifyListeners();
  }

  Map<String, List<ConfigControl>> _configControls = const {};
  Map<String, String> _selectedValues = const {};

  String? _outputDirectoryPath = SettingsBox().lastOutputDirectoryPath;

  Map<String, Failure> _errorPaths = {};
  Map<String, Failure> get errorPaths => _errorPaths;
  int _pathValidationRevision = 0;
  bool _isDisposed = false;
  Future<List<ConvertJob>>? _preparation;
  final _preparedInputJobs = <String, String>{};
  bool get isPreparingJobs => _preparation != null;

  @override
  void dispose() {
    _isDisposed = true;
    _pathValidationRevision++;
    for (final jobId in _preparedInputJobs.values.toSet()) {
      unawaited(_cleanUnsubmittedInput(jobId));
    }
    _preparedInputJobs.clear();
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
    if (_isLoadingFormat) return;
    _selectedPreset = null;
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
    final accepted = <File>[];
    final excluded = <File>[];
    final contentTypes = <String, FileContentType>{};
    final selectedPaths = _selectedFiles.map((file) => file.path).toSet();
    for (final file in files) {
      if (selectedPaths.contains(file.path)) {
        continue;
      }
      final fileExtension = file.fileExtension;
      FileContentType contentType;
      try {
        contentType = .fromMimeType(await _fileService.getFileMimeType(file));
      } catch (error, trace) {
        printError(error, trace);
        contentType = .other;
      }

      /// Check file mime type for non-media files.
      if (shouldExcludeNonMediaFiles && contentType == .other) {
        printLog(
          '[FilePicker]: File ${file.path} mime type is not media: $fileExtension. Skipping.',
        );
        excluded.add(file);
        continue;
      }

      /// Check if file extension is excluded.
      if (isCheckingCustomExtensions &&
          excludedFileExtensions.contains(fileExtension)) {
        printLog(
          '[FilePicker]: File ${file.path} extension is excluded: $fileExtension. Skipping.',
        );
        excluded.add(file);
        continue;
      }

      selectedPaths.add(file.path);
      accepted.add(file);
      contentTypes[file.path] = contentType;
    }
    if (_isDisposed) {
      return;
    }
    // Reconcile with current state after asynchronous detection. Another pick
    // or removal may have completed while this request was reading headers.
    final currentPaths = _selectedFiles.map((file) => file.path).toSet();
    _selectedFiles = [
      ..._selectedFiles,
      for (final file in accepted)
        if (currentPaths.add(file.path)) file,
    ];
    final excludedPaths = _excludedFiles.map((file) => file.path).toSet();
    _excludedFiles = [
      ..._excludedFiles,
      for (final file in excluded)
        if (!currentPaths.contains(file.path) && excludedPaths.add(file.path))
          file,
    ];
    _fileContentTypes.addAll(contentTypes);
    notifyListeners();
    refreshOutputFileNames();
  }

  void removeFile(File file) {
    final clone = [
      ..._selectedFiles,
    ];
    clone.removeWhere((e) => e.path == file.path);
    _fileContentTypes.remove(file.path);
    final preparedJob = _preparedInputJobs.remove(file.path);
    if (preparedJob != null) {
      unawaited(_cleanUnsubmittedInput(preparedJob));
    }
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
      outputFormat: formatEntry,
    );
    if (_isDisposed || revision != _pathValidationRevision) {
      return;
    }
    _errorPaths = errorPaths;
    notifyListeners();
  }

  Future<void> setSelectedFormatEntry(FormatEntry formatEntry) =>
      _selectFormat(formatEntry);

  Future<void> applyPreset(ConversionPreset preset) async {
    final format = formatConfigModel.formats
        .where(
          (format) => format.name == preset.formatName,
        )
        .firstOrNull;
    if (format == null) return;
    await _selectFormat(format, preset: preset);
  }

  Future<void> _selectFormat(
    FormatEntry formatEntry, {
    ConversionPreset? preset,
  }) async {
    if (_selectedFormatEntry == formatEntry &&
        preset == null &&
        !_isLoadingFormat) {
      return;
    }
    final resetOutputNames = _selectedFormatEntry != formatEntry;
    final revision = ++_configurationRevision;
    _selectedFormatEntry = formatEntry;
    _selectedPreset = null;
    if (resetOutputNames) {
      _outputFileNames = {
        for (final file in _selectedFiles)
          file.path: CommandBuilder.getOutputFileName(
            inputFilePath: file.path,
            formatEntry: formatEntry,
          ),
      };
      _pathValidationRevision++;
      _errorPaths = {};
    }
    _isLoadingFormat = true;
    notifyListeners();
    try {
      final controls = await formatConfigModel.loadConfigControls(formatEntry);
      if (_isDisposed || revision != _configurationRevision) return;
      _configControls = controls;
      _initOutputConfig(
        overrides: preset?.selectedValues,
      );
      if (preset != null &&
          preset.selectedValues.entries.every(
            (entry) => _selectedValues[entry.key] == entry.value,
          )) {
        _selectedPreset = preset;
        _trimEnabled = false;
      }
      _isLoadingFormat = false;
      refreshOutputFileNames();
    } finally {
      if (!_isDisposed &&
          revision == _configurationRevision &&
          _isLoadingFormat) {
        _isLoadingFormat = false;
        _selectedValues = const {};
        _configControls = const {};
        notifyListeners();
      }
    }
  }

  void _initOutputConfig({
    Map<String, String>? overrides,
  }) {
    final formatEntry = _selectedFormatEntry;
    if (formatEntry == null) {
      return;
    }

    // Initialize selected config state to defaults.
    // Then overwrite with last known configurations.
    _selectedValues = ConfigurationSelection.normalizeValues(
      groups: _configControls,
      roots: _rootConfigKeys,
      overrides: overrides ?? formatEntry.lastKnownConfigurations,
    );
    notifyListeners();
  }

  void resetConfigurations() {
    if (_isLoadingFormat) return;
    _selectedPreset = null;
    _trimEnabled = false;
    _trimStartText = '';
    _trimEndText = '';
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

  Future<List<ConvertJob>> cook() {
    if (_preparation case final preparation?) return preparation;
    final result = Completer<List<ConvertJob>>();
    _preparation = result.future;
    notifyListeners();
    unawaited(_prepareJobs(result));
    return result.future;
  }

  Future<void> _prepareJobs(Completer<List<ConvertJob>> result) async {
    try {
      result.complete(await _buildJobs());
    } catch (error, trace) {
      result.completeError(error, trace);
    } finally {
      _preparation = null;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<List<ConvertJob>> _buildJobs() async {
    if (_isLoadingFormat) throw const NoOutputConfigFailure();
    if (trimFailure case final failure?) throw failure;
    final trim = selectedTrim;
    final formatEntry = _selectedFormatEntry;
    final selectedValues = {..._selectedValues};
    final outputDirectoryPath = _outputDirectoryPath;
    final controls = availableControls;
    final configurationKeys = _configControls.keys.toSet();
    final rememberConfigurations = _shouldRememberConfigs;
    final rememberOutputFolder = _shouldRememberOutputFolder;
    final threadCount = SettingsBox().threadCount;
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
      outputFormat: formatEntry,
    );
    if (errorPaths.isNotEmpty) {
      throw errorPaths.values.first;
    }

    final List<ConvertJob> result = [];
    final appCachedDir = await _fileService.getAppCacheDirectory();
    final allocatedInputs = <String, String>{};
    final movedInputs = <String, String>{};
    try {
      for (final inputFilePath in outputFileNames.keys) {
        final jobId = _preparedInputJobs[inputFilePath] ?? kUuid.v4();
        allocatedInputs[jobId] = inputFilePath;
        final fileName = outputFileNames[inputFilePath];
        if (fileName == null) {
          throw FileNameIsNotSetFailure(inputFilePath);
        }

        final newInputFilePath = await _fileService.movePickedFileToInputFolder(
          jobId: jobId,
          inputFilePath: inputFilePath,
          appCachedPath: appCachedDir.path,
        );

        if (newInputFilePath == null) {
          throw InputFileNotExistFailure(inputFilePath);
        }
        if (newInputFilePath != inputFilePath) {
          movedInputs[jobId] = newInputFilePath;
        }
        if (_isDisposed) {
          throw StateError('Conversion setup closed during preparation');
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
          threadCount: threadCount,
          configurationKeys: configurationKeys,
          trim: trim,
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

      if (rememberConfigurations) {
        formatEntry.setLastKnownConfigurations(selectedValues);
      }
      if (rememberOutputFolder) {
        SettingsBox().lastOutputDirectoryPath = outputDirectoryPath;
      }
      for (final input in outputFileNames.keys) {
        _preparedInputJobs.remove(input);
      }
    } catch (error, trace) {
      await _rollbackPreparedInputs(allocatedInputs, movedInputs);
      Error.throwWithStackTrace(error, trace);
    }

    return result;
  }

  Future<void> _rollbackPreparedInputs(
    Map<String, String> allocatedInputs,
    Map<String, String> movedInputs,
  ) async {
    for (final entry in allocatedInputs.entries.toList().reversed) {
      final original = entry.value;
      final prepared = movedInputs[entry.key];
      if (prepared == null) {
        if (!_preparedInputJobs.containsKey(original)) {
          await _cleanUnsubmittedInput(entry.key);
        }
        continue;
      }
      String? restored;
      try {
        restored = await _fileService.restorePickedFile(
          jobId: entry.key,
          originalFilePath: original,
          preparedFilePath: prepared,
        );
      } catch (error, trace) {
        printError(error, trace);
        restored = prepared;
      }
      if (restored == prepared && _isDisposed) {
        await _cleanUnsubmittedInput(entry.key);
        continue;
      }
      if (restored == null || _isDisposed) continue;
      if (restored == prepared) _preparedInputJobs[prepared] = entry.key;
      if (restored != original) _replacePreparedFile(original, restored);
    }
  }

  void _replacePreparedFile(String original, String restored) {
    if (!_selectedFiles.any((file) => file.path == original)) return;
    _selectedFiles = [
      for (final file in _selectedFiles)
        file.path == original ? File(restored) : file,
    ];
    final names = {..._outputFileNames};
    names[restored] = names.remove(original);
    _outputFileNames = names;
    final type = _fileContentTypes.remove(original);
    if (type != null) _fileContentTypes[restored] = type;
    refreshOutputFileNames();
  }

  Future<void> _cleanUnsubmittedInput(String jobId) async {
    try {
      await _fileService.cleanUpInputFile(jobId: jobId);
    } catch (error, trace) {
      printError(error, trace);
    }
  }

  Future<Map<String, Failure>> findInvalidPaths({
    required Map<String, String?> selectedPaths,
    required String outputDirectoryPath,
    FormatEntry? outputFormat,
  }) async {
    final formatEntry = outputFormat ?? _selectedFormatEntry;
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
    if (_isLoadingFormat) return const NoOutputConfigFailure();

    return null;
  }

  Failure? _checkOutputConfigError() {
    if (trimFailure case final failure?) return failure;
    if (_isLoadingFormat || _selectedValues.isEmpty) {
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

  List<({String label, List<String> values})> get configurationSummary {
    final result = <({String label, List<String> values})>[];
    for (final control in availableControls) {
      if (!control.isVisible) continue;
      final value = _selectedValues[control.name] ?? control.defaultValue;
      final labels = ConfigurationSelection.selectedOptions(control, value)
          .map((option) => option.label)
          .where((label) => label.isNotEmpty)
          .toList();
      if (labels.isEmpty) continue;
      result.add((label: control.label, values: labels));
    }
    return result;
  }

  List<ConfigControl> get availableControls => _isLoadingFormat
      ? const []
      : ConfigurationSelection.resolveControls(
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
    if (_isLoadingFormat) return;
    _selectedPreset = null;
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
