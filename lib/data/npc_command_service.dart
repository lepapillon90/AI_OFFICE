import 'package:ai_office/game/npc/npc_command_errors.dart';
import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Asks an AI employee to respond to an `@employee command` chat message,
/// via the `ask-employee` Supabase Edge Function. The function — not this
/// client — holds the Anthropic API key, so it never reaches the browser
/// bundle. See docs/PHASE6_AI_EMPLOYEES.md for how to deploy it.
class NpcCommandService {
  NpcCommandService(this._client);

  final SupabaseClient _client;

  Future<NpcCommandResult> ask({
    required String employeeName,
    required String employeeRole,
    required String command,
    required String companyId,
    List<Map<String, String>> history = const [],
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'ask-employee',
        body: {
          'employeeName': employeeName,
          'employeeRole': employeeRole,
          'command': command,
          'history': history,
          // Lets the function confirm the caller actually belongs to this
          // company (and rate-limit per company) instead of trusting any
          // signed-in user of the Supabase project — see
          // docs/PHASE7_OPS_REVIEW.md.
          'companyId': companyId,
        },
      );
    } on FunctionException catch (e) {
      if (e.status == 429) {
        final details = e.details;
        final message = (details is Map && details['error'] is String)
            ? details['error'] as String
            : '이 회사의 AI 직원 호출 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
        throw AskEmployeeRateLimitException(message);
      }
      rethrow;
    }
    final data = response.data;
    if (data is Map && data['reply'] is String) {
      return NpcCommandResult(
        reply: data['reply'] as String,
        usage: _parseUsage(data['usage']),
      );
    }
    throw Exception('예상치 못한 응답 형식입니다: ${response.data}');
  }

  NpcUsage? _parseUsage(Object? usage) {
    if (usage is! Map) {
      return null;
    }
    int? asInt(Object? value) => value is int ? value : (value as num?)?.toInt();
    return NpcUsage(
      promptTokens: asInt(usage['prompt_tokens']),
      completionTokens: asInt(usage['completion_tokens']),
      totalTokens: asInt(usage['total_tokens']),
    );
  }
}
