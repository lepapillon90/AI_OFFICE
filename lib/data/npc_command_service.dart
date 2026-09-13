import 'package:supabase_flutter/supabase_flutter.dart';

/// Asks an AI employee to respond to an `@employee command` chat message,
/// via the `ask-employee` Supabase Edge Function. The function — not this
/// client — holds the Anthropic API key, so it never reaches the browser
/// bundle. See docs/PHASE6_AI_EMPLOYEES.md for how to deploy it.
class NpcCommandService {
  NpcCommandService(this._client);

  final SupabaseClient _client;

  Future<String> ask({
    required String employeeName,
    required String employeeRole,
    required String command,
  }) async {
    final response = await _client.functions.invoke(
      'ask-employee',
      body: {
        'employeeName': employeeName,
        'employeeRole': employeeRole,
        'command': command,
      },
    );
    final data = response.data;
    if (data is Map && data['reply'] is String) {
      return data['reply'] as String;
    }
    throw Exception('예상치 못한 응답 형식입니다: ${response.data}');
  }
}
