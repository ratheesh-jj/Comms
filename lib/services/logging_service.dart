import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  File? _logFile;
  final Logger _logger = Logger('LoggingService');

  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/app_logs.txt');

      // Create file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }

      // Log start of session
      await _writeLog('=== Session Started: ${DateTime.now()} ===');

      // Listen to global logs
      Logger.root.onRecord.listen((record) {
        _logRecord(record);
      });

      _logger.info('LoggingService initialized. Logs path: ${_logFile!.path}');
    } catch (e) {
      print('Failed to initialize LoggingService: $e');
    }
  }

  void _logRecord(LogRecord record) {
    final logLine =
        '${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}';
    _writeLog(logLine);
    if (record.error != null) {
      _writeLog('ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      _writeLog('STACK TRACE: ${record.stackTrace}');
    }
  }

  Future<void> _writeLog(String line) async {
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString('$line\n', mode: FileMode.append);
      } catch (e) {
        print('Failed to write to log file: $e');
      }
    }
  }

  Future<String> getLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      return await _logFile!.readAsString();
    }
    return 'No logs found.';
  }

  Future<void> clearLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }
}
