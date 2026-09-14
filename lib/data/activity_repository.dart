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

  /// When [userId] last cleared their unread badge for [companyId]'s
  /// activity feed, or null if they never have (or the
  /// `activity_read_marks` table hasn't been migrated yet). See
  /// docs/PHASE7_ACTIVITY.md for the schema this depends on.
  Future<DateTime?> fetchLastReadAt(String companyId, String userId) async {
    final row = await _client
        .from('activity_read_marks')
        .select('last_read_at')
        .eq('company_id', companyId)
        .eq('user_id', userId)
        .maybeSingle();
    final value = row?['last_read_at'] as String?;
    return value == null ? null : DateTime.parse(value);
  }

  /// Records that [userId] has read [companyId]'s activity feed as of
  /// [readAt], so the unread count picks up from there on their next login
  /// instead of always resetting to zero.
  Future<void> markRead(String companyId, String userId, DateTime readAt) async {
    await _client.from('activity_read_marks').upsert({
      'company_id': companyId,
      'user_id': userId,
      'last_read_at': readAt.toIso8601String(),
    });
  }
}
