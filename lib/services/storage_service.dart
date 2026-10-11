import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Uploads a company image (logo or banner) to Supabase Storage and returns the public download URL.
  Future<String> uploadCompanyImage({
    required String companyId,
    required File imageFile,
    required bool isLogo,
  }) async {
    try {
      final fileExtension = path.extension(imageFile.path);
      final fileName = isLogo
          ? 'logo_$companyId$fileExtension'
          : 'banner_$companyId$fileExtension';
      final folderPath = 'companies/$companyId/images';
      final fullPath = '$folderPath/$fileName';

      // Upload the file
      await _supabase.storage
          .from('uploads')
          .upload(
            fullPath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get the public URL
      final publicUrl = _supabase.storage
          .from('uploads')
          .getPublicUrl(fullPath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
