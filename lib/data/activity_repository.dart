import 'package:ai_office/game/activity/activity_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists and loads a company's activity feed (`activity_events` table).
/// See docs/PHASE7_ACTIVITY.md for the schema/RLS setup this depends on.
class ActivityRepository {
  ActivityRepository(this._client);

  final SupabaseClient _client;

  static const _historyLimit = 50;

  /// The most recent activity for [companyId], oldest first (matching
  /// [ChatRepository.fetchRecentMessages]'s convention).
  Future<List<ActivityEvent>> fetchRecentActivity(String companyId) async {
    final rows = await _client
        .from('activity_events')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(_historyLimit);
    return rows.map(ActivityEvent.fromRow).toList().reversed.toList();
  }

  Future<void> logEvent(String companyId, ActivityEvent event) async {
    await _client.from('activity_events').insert(event.toRow(companyId));
  }
}
