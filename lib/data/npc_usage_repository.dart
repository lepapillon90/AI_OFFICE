import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists and loads a company's AI-employee usage counters
/// (`npc_usage_events` table — one row per `askEmployee` attempt). See
/// docs/PHASE6_AI_EMPLOYEES.md's persistence section for the schema/RLS
/// setup this depends on.
class NpcUsageRepository {
  NpcUsageRepository(this._client);

  final SupabaseClient _client;

  // PostgREST has no GROUP BY through the table API, so summaries are
  // aggregated client-side from the raw events instead of a Postgres view
  // or RPC function — simplest option for this MVP's event volume.
  static const _eventLimit = 5000;

  Future<void> recordEvent(
    String companyId,
    String employeeId, {
    required bool success,
    NpcUsage? usage,
  }) async {
    await _client.from('npc_usage_events').insert({
      'company_id': companyId,
      'employee_id': employeeId,
      'success': success,
      'prompt_tokens': usage?.promptTokens,
      'completion_tokens': usage?.completionTokens,
    });
  }

  /// Cumulative usage per employee id for [companyId], aggregated from the
  /// raw event rows.
  Future<Map<String, NpcUsageSummary>> fetchUsageSummaries(
    String companyId,
  ) async {
    final rows = await _client
        .from('npc_usage_events')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(_eventLimit);

    final summaries = <String, NpcUsageSummary>{};
    for (final row in rows) {
      final employeeId = row['employee_id'] as String;
      final success = row['success'] as bool? ?? false;
      final current = summaries[employeeId] ?? const NpcUsageSummary();
      summaries[employeeId] = NpcUsageSummary(
        calls: current.calls + 1,
        successes: current.successes + (success ? 1 : 0),
        failures: current.failures + (success ? 0 : 1),
        promptTokens: current.promptTokens + ((row['prompt_tokens'] as int?) ?? 0),
        completionTokens:
            current.completionTokens + ((row['completion_tokens'] as int?) ?? 0),
      );
    }
    return summaries;
  }
}
