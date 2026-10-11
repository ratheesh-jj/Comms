import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class FileService {
  final Dio _dio = Dio();

  /// Downloads a file to a temporary directory for viewing.
  Future<File?> downloadToTemp(String url, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = path.join(tempDir.path, fileName);
      
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }

      await _dio.download(url, filePath);
      return File(filePath);
    } catch (e) {
      print('Error downloading to temp: $e');
      return null;
    }
  }

  /// Downloads and saves a file to the public storage (Downloads folder).
  Future<String?> saveToPublicStorage(String url, String fileName) async {
    try {
      // Request storage permissions
      if (Platform.isAndroid) {
        if (!await Permission.storage.request().isGranted && 
            !await Permission.manageExternalStorage.request().isGranted) {
          return 'Permission denied';
        }
      }

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) return 'Could not find downloads directory';

      final filePath = path.join(downloadsDir.path, fileName);
      
      // Check if file already exists to avoid overwriting or provide a new name
      String finalPath = filePath;
      int counter = 1;
      while (await File(finalPath).exists()) {
        final nameWithoutExt = path.basenameWithoutExtension(fileName);
        final ext = path.extension(fileName);
        finalPath = path.join(downloadsDir.path, '${nameWithoutExt}_$counter$ext');
        counter++;
      }

      await _dio.download(url, finalPath);
      return finalPath;
    } catch (e) {
      print('Error saving to public storage: $e');
      return 'Download failed: $e';
    }
  }

  /// Checks if a file exists locally.
  Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }
}
