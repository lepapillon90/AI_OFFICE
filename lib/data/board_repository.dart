import 'package:ai_office/game/board/board_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists and loads a company's project/task board (`board_tasks` table).
/// See docs/PHASE7_BOARD.md for the schema/RLS setup this depends on.
class BoardRepository {
  BoardRepository(this._client);

  final SupabaseClient _client;

  /// All of [companyId]'s board tasks, oldest first.
  Future<List<BoardTask>> fetchTasks(String companyId) async {
    final rows = await _client
        .from('board_tasks')
        .select()
        .eq('company_id', companyId)
        .order('created_at');
    return rows.map(BoardTask.fromRow).toList();
  }

  Future<void> upsertTask(String companyId, BoardTask task) async {
    await _client.from('board_tasks').upsert(task.toRow(companyId));
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('board_tasks').delete().eq('id', taskId);
  }
}
