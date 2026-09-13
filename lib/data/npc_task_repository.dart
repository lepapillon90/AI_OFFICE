import 'package:ai_office/game/npc/npc_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists and loads a company's AI-employee task history (`npc_tasks`
/// table). See docs/PHASE6_AI_EMPLOYEES.md's persistence section for the
/// schema/RLS setup this depends on.
class NpcTaskRepository {
  NpcTaskRepository(this._client);

  final SupabaseClient _client;

  static const _historyLimit = 200;

  /// The most recent tasks for [companyId], oldest first (matching
  /// [ChatRepository.fetchRecentMessages]'s convention so callers can feed
  /// both straight into OfficeGame's initial-state lists).
  Future<List<NpcTask>> fetchRecentTasks(String companyId) async {
    final rows = await _client
        .from('npc_tasks')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(_historyLimit);
    return rows.map(NpcTask.fromRow).toList().reversed.toList();
  }

  /// Inserts or updates [task]'s row — called once when a task starts
  /// (`pending`) and again when it resolves (`success`/`error`), so a
  /// `pending` task never lingers if the app closes mid-call.
  Future<void> upsertTask(String companyId, NpcTask task) async {
    await _client.from('npc_tasks').upsert(task.toRow(companyId));
  }
}
