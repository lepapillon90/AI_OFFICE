import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads/downloads real files shared in chat (as opposed to
/// [NpcDocumentRepository]'s AI-generated text documents) — the
/// `chat-attachments` Supabase Storage bucket. See
/// docs/PHASE8_FILE_SHARING.md for the bucket/policy setup this depends on.
class ChatAttachmentRepository {
  ChatAttachmentRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'chat-attachments';

  /// Uploads [bytes] and returns its storage path
  /// (`<companyId>/<epoch-micros>-<sanitized fileName>`) — the epoch
  /// prefix keeps two uploads of a same-named file from colliding.
  ///
  /// The storage key uses a sanitized version of [fileName] (Supabase
  /// Storage rejects keys with non-ASCII characters — e.g. Korean — or
  /// spaces as "Invalid key", confirmed live: a plain-English filename
  /// uploaded fine, "새 텍스트 문서.txt" 400'd). The original [fileName] is
  /// never touched here — callers keep it as the display name shown in
  /// chat (see OfficeGame.sendChatAttachment), independent of this key.
  Future<String> upload({
    required String companyId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$companyId/${DateTime.now().microsecondsSinceEpoch}-$safeName';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  /// A short-lived signed URL to view/download the file at [path].
  Future<String> signedUrl(String path) =>
      _client.storage.from(_bucket).createSignedUrl(path, 600);
}
