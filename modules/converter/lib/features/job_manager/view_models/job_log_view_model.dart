import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:platform_utils/platform_utils.dart';

class JobLogViewModel(final ConvertJob job) extends ChangeNotifier {
  late final LogData _data = injector<LogData>();
  late final ValueListenable<void> _changes = _data.getLogListenable(job.id);
  String _logs = '';
  String _query = '';
  bool _initialized = false;
  bool _disposed = false;
  bool _isExporting = false;

  String get logs => _logs;
  String get query => _query;
  bool get isExporting => _isExporting;
  String get visibleLogs {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _logs;
    return _logs
        .split('\n')
        .where((line) => line.toLowerCase().contains(query))
        .join('\n');
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _logs = _data.getLog(job.id);
    _changes.addListener(_refresh);
  }

  void _refresh() {
    _logs = _data.getLog(job.id);
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  Future<void> copyLogs() => Clipboard.setData(.new(text: _logs));

  /// Export a snapshot of the complete log, including lines hidden by search.
  Future<(String?, Failure?)> exportLogs(dynamic context) async {
    if (_isExporting || _logs.isEmpty) return (null, null);
    final snapshot = _logs;
    _isExporting = true;
    notifyListeners();
    Directory? temporary;
    try {
      final files = injector<FileService>();
      final (destination, failure) = await files.chooseSavePath(context);
      if (failure != null || destination == null) return (null, failure);
      final cache = await files.getAppCacheDirectory();
      temporary = await cache.createTemp('job_log_export_');
      final name =
          '${job.outputFileName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')}.log.txt';
      final staged = File(join(temporary.path, name));
      await staged.writeAsString(snapshot, flush: true);
      final exportFailure = await files.moveConvertedFileToPath(
        convertedFilePath: staged.path,
        outputFileName: name,
        outputFilePath: destination,
      );
      return exportFailure == null
          ? (join(destination, name), null)
          : (null, exportFailure);
    } catch (error, trace) {
      printError(error, trace);
      return (null, error is Failure ? error : Failure(error.toString()));
    } finally {
      if (temporary != null) {
        try {
          await temporary.delete(recursive: true);
        } catch (error, trace) {
          printError(error, trace);
        }
      }
      _isExporting = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_initialized) _changes.removeListener(_refresh);
    super.dispose();
  }
}
