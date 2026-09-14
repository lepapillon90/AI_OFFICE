import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages the company's optional server-machine password (see
/// [ServerMachineInteraction]/docs/PHASE8_REMOTE_AGENT.md) — a game-world
/// flavor gate on `@서버` remote commands, layered on top of the real
/// security boundary (the command whitelist and per-employee opt-in), not
/// a replacement for it.
///
/// The password itself lives in `company_integrations.server_password`
/// (same table as the Slack webhook URL) but, unlike that column, is
/// write-only from this client's point of view — nothing ever reads the
/// raw value back, not even the owner who set it (see docs/
/// PHASE8_REMOTE_AGENT.md's `revoke select (server_password) ...`). Both
/// [hasPassword] and [verify] go through SECURITY DEFINER RPCs that answer
/// only a boolean, so a curious member can never fetch the plaintext
/// value through this client either way.
class ServerLockRepository {
  ServerLockRepository(this._client);

  final SupabaseClient _client;

  /// Sets (or, given null/blank, clears) the company's server password —
  /// owner only, enforced by RLS. Write-only: there is no matching
  /// "fetch the current password" — the admin panel's field always starts
  /// blank, with a placeholder noting that leaving it blank keeps
  /// whatever is already set.
  Future<void> savePassword(String companyId, String? password) async {
    final trimmed = password?.trim();
    await _client.from('company_integrations').upsert({
      'company_id': companyId,
      'server_password': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Whether the company currently has a server password configured at
  /// all — any signed-in company member can call this; it never reveals
  /// the value itself. Used to decide whether [OfficeGame] should start a
  /// session already unlocked (no password set = the lock simply doesn't
  /// apply, same "opt-in" shape as the Slack integration) or locked.
  Future<bool> hasPassword(String companyId) async {
    final result = await _client.rpc<bool>(
      'has_server_password',
      params: {'target_company_id': companyId},
    );
    return result;
  }

  /// Checks [attempt] against the company's configured password without
  /// ever exposing the real value to the caller.
  Future<bool> verify(String companyId, String attempt) async {
    final result = await _client.rpc<bool>(
      'verify_server_password',
      params: {'target_company_id': companyId, 'attempt': attempt},
    );
    return result;
  }

  /// Whether the local agent (docs/PHASE8_REMOTE_AGENT.md) is currently
  /// willing to actually execute commands for this company — the agent
  /// process itself may already be running in the background the whole
  /// time (e.g. via the Windows scheduled task), but only processes
  /// `pending` rows while this is true. Any signed-in company member can
  /// read/toggle it — see [setRunning] — it isn't a security boundary
  /// (that's still the command whitelist and per-employee opt-in), just
  /// the "power switch" half of the server machine's game-world flavor.
  Future<bool> fetchRunning(String companyId) async {
    final row = await _client
        .from('server_control')
        .select('running')
        .eq('company_id', companyId)
        .maybeSingle();
    return row?['running'] as bool? ?? false;
  }

  /// Flips the "power switch" — any signed-in company member may call
  /// this (RLS), same as [fetchRunning].
  Future<void> setRunning(String companyId, bool running) async {
    await _client.from('server_control').upsert({
      'company_id': companyId,
      'running': running,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
