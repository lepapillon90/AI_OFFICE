import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages a company's optional Slack incoming-webhook integration — see
/// docs/PHASE8_SLACK.md.
class SlackIntegrationRepository {
  SlackIntegrationRepository(this._client);

  final SupabaseClient _client;

  /// The company's configured webhook URL, or null if Slack isn't enabled
  /// (or the table hasn't been migrated yet).
  Future<String?> fetchWebhookUrl(String companyId) async {
    final row = await _client
        .from('company_integrations')
        .select('slack_webhook_url')
        .eq('company_id', companyId)
        .maybeSingle();
    return row?['slack_webhook_url'] as String?;
  }

  /// Sets (or, given null/blank, clears) the company's webhook URL — owner
  /// only, enforced by RLS.
  Future<void> saveWebhookUrl(String companyId, String? url) async {
    final trimmed = url?.trim();
    await _client.from('company_integrations').upsert({
      'company_id': companyId,
      'slack_webhook_url':
          (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Posts [text] to the company's Slack channel via the `notify-slack`
  /// Edge Function — the server looks up the webhook URL and makes the
  /// actual call, so the browser never needs direct network access to
  /// Slack (whose incoming-webhook endpoint doesn't allow that via CORS
  /// anyway) and the URL itself never reaches the client bundle. A no-op
  /// if the company hasn't configured a webhook.
  Future<void> notify(String companyId, String text) async {
    await _client.functions.invoke(
      'notify-slack',
      body: {'companyId': companyId, 'text': text},
    );
  }
}
