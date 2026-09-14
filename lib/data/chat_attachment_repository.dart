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

  /// Uploads [bytes] as [fileName] and returns its storage path
  /// (`<companyId>/<epoch-micros>-<fileName>`) — the epoch prefix keeps two
  /// uploads of a same-named file from colliding.
  Future<String> upload({
    required String companyId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = '$companyId/${DateTime.now().microsecondsSinceEpoch}-$fileName';
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
