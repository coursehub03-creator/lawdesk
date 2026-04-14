import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Evidence Storage helper for Supabase.
///
/// Key rule: **never** store a device-local file path in Supabase.
/// Store the *storage path* (inside the bucket) in the DB, and generate a
/// signed URL when you need to display/open the file.
///
/// Naming convention (inside bucket):
/// users/{userId}/cases/{caseId}/documents/{documentId}/{filename}
class EvidenceStorageService {
  EvidenceStorageService._();

  /// Change this if your Supabase bucket has a different name.
  static const String kEvidenceBucket = 'evidence';

  static final SupabaseClient _client = Supabase.instance.client;
  static const Uuid _uuid = Uuid();

  static String _sanitizeFileName(String fileName) {
    // Keep it simple and URL-safe.
    final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    // Avoid empty.
    return sanitized.isEmpty ? 'file' : sanitized;
  }

  static String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated');
    }
    return user.id;
  }

  /// Builds a storage path that is stable and collision-free.
  static String buildEvidencePath({
    required String caseId,
    required String documentId,
    required String originalFileName,
  }) {
    final userId = _requireUserId();
    final fileName = _sanitizeFileName(originalFileName);
    return 'users/$userId/cases/$caseId/documents/$documentId/$fileName';
  }

  /// Uploads a local file to Supabase Storage and returns:
  /// - storagePath: path inside the bucket
  /// - documentId: generated UUID for the document folder
  static Future<({String storagePath, String documentId})> uploadEvidenceFile({
    required File file,
    required String firebaseCaseId,
    String? documentId,
  }) async {
    final docId = documentId ?? _uuid.v4();
    final storagePath = buildEvidencePath(
      caseId: firebaseCaseId,
      documentId: docId,
      originalFileName: p.basename(file.path),
    );

    final bytes = await file.readAsBytes();

    // Best-effort content type.
    final ext = p.extension(file.path).toLowerCase();
    final contentType = switch (ext) {
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };

    await _client.storage.from(kEvidenceBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return (storagePath: storagePath, documentId: docId);
  }

  /// Returns a signed URL for a given storage path.
  static Future<String> createSignedUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    return _client.storage.from(kEvidenceBucket).createSignedUrl(
          storagePath,
          expiresInSeconds,
        );
  }

  /// Downloads a signed URL to a temporary file and returns the local path.
  static Future<String> downloadSignedUrlToTemp({
    required String signedUrl,
    required String suggestedFileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(dir.path, 'lawdesk_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final localName = '${_uuid.v4()}_${_sanitizeFileName(suggestedFileName)}';
    final outFile = File(p.join(cacheDir.path, localName));

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(signedUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed with status ${response.statusCode}');
      }
      final bytes = await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      await outFile.writeAsBytes(bytes, flush: true);
      return outFile.path;
    } finally {
      httpClient.close(force: true);
    }
  }

  /// Backward-compatible helper used by older UI code.
  /// Accepts the signed URL and an optional file name (positional).
  static Future<String> downloadToTemp(String signedUrl, [String suggestedFileName = 'evidence']) {
    return downloadSignedUrlToTemp(
      signedUrl: signedUrl,
      suggestedFileName: suggestedFileName,
    );
  }
}
