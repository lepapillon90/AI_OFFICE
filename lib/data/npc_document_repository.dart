import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a successful AI-employee reply into a downloadable text document —
/// the "실제 업무 수행" a chat reply alone doesn't convey — stored in the
/// `npc-documents` Supabase Storage bucket. See
/// docs/PHASE6_AI_EMPLOYEES.md's persistence section for the bucket/policy
/// setup this depends on.
class NpcDocumentRepository {
  NpcDocumentRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'npc-documents';

  /// Uploads a plain-text document for one task's result and returns its
  /// storage path (`<companyId>/<employeeId>/<taskId>.txt`).
  Future<String> upload({
    required String companyId,
    required String employeeId,
    required String employeeName,
    required String taskId,
    required String command,
    required String result,
  }) async {
    final path = '$companyId/$employeeId/$taskId.txt';
    final content = '$employeeName의 작업 결과\n'
        '작성일: ${DateTime.now().toIso8601String()}\n'
        '\n'
        '지시:\n$command\n'
        '\n'
        '결과:\n$result\n';
    final bytes = Uint8List.fromList(utf8.encode(content));
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'text/plain; charset=utf-8',
            upsert: true,
          ),
        );
    return path;
  }

  /// A short-lived signed URL to view/download the document at [path].
  Future<String> signedUrl(String path) =>
      _client.storage.from(_bucket).createSignedUrl(path, 600);
}
