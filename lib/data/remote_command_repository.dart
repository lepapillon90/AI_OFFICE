import 'dart:async';

import 'package:ai_office/data/remote_command.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends a whitelisted [RemoteCommandType] to the company's local agent
/// (docs/PHASE8_REMOTE_AGENT.md) by inserting a row into `remote_commands`,
/// then waits for that same row to be updated (by the agent, running
/// outside this app entirely, using its own service-role key — RLS grants
/// this client no UPDATE access) and returns a human-readable outcome.
class RemoteCommandRepository {
  RemoteCommandRepository(this._client);

  final SupabaseClient _client;

  Future<String> runCommand({
    required String companyId,
    required String requestedByName,
    required RemoteCommandType type,
    required Map<String, dynamic> params,
    // Null routes to the default agent — one started without
    // --agent-key. A specific employee's [AiEmployee.workstationId] routes
    // to the agent started with `--agent-key <that workstationId>` — see
    // docs/PHASE8_REMOTE_AGENT.md's multi-computer section.
    String? machineKey,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return '로그인이 필요합니다.';
    }

    final Map<String, dynamic> inserted;
    try {
      inserted = await _client
          .from('remote_commands')
          .insert({
            'company_id': companyId,
            'requested_by': userId,
            'requested_by_name': requestedByName,
            'command_type': type.wireName,
            'params': params,
            'machine_key': machineKey,
          })
          .select('id')
          .single();
    } catch (e) {
      return '명령을 전달하지 못했습니다: $e';
    }
    final id = inserted['id'] as String;

    final completer = Completer<Map<String, dynamic>>();
    final channel = _client.channel('remote_command_result:$id');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'remote_commands',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != null && status != 'pending' && !completer.isCompleted) {
              completer.complete(payload.newRecord);
            }
          },
        )
        .subscribe();

    try {
      final updated = await completer.future.timeout(timeout);
      final status = updated['status'] as String?;
      final result = (updated['result'] as String?)?.trim();
      if (status == 'done') {
        return (result == null || result.isEmpty) ? '완료되었습니다.' : result;
      }
      return (result == null || result.isEmpty)
          ? '처리에 실패했습니다.'
          : '실패했습니다: $result';
    } on TimeoutException {
      return '서버 에이전트가 응답하지 않습니다 — 에이전트 프로그램이 그 컴퓨터에서 실행 중인지 확인해주세요. (요청 id: $id)';
    } finally {
      unawaited(_client.removeChannel(channel));
    }
  }
}
