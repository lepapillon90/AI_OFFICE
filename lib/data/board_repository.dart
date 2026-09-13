import 'package:ai_office/game/board/board_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists and loads a company's project/task board (`board_tasks` table).
/// See docs/PHASE7_BOARD.md for the schema/RLS setup this depends on.
class BoardRepository {
  BoardRepository(this._client);

  final SupabaseClient _client;

  // Board cards are never auto-archived, so without a cap this query (and
  // the Kanban columns rendering its result) would grow unbounded for a
  // long-lived company — found during the Phase 7 ops review
  // (docs/PHASE7_OPS_REVIEW.md).
  static const _fetchLimit = 500;

  /// The most recent [_fetchLimit] of [companyId]'s board tasks, oldest
  /// first.
  Future<List<BoardTask>> fetchTasks(String companyId) async {
    final rows = await _client
        .from('board_tasks')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(_fetchLimit);
    return rows.map(BoardTask.fromRow).toList().reversed.toList();
  }

  Future<void> upsertTask(String companyId, BoardTask task) async {
    await _client.from('board_tasks').upsert(task.toRow(companyId));
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('board_tasks').delete().eq('id', taskId);
  }
}
