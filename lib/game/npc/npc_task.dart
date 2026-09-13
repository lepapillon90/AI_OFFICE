import 'npc_usage.dart';

/// The lifecycle of one `@employee command` dispatched to an AI employee.
enum NpcTaskStatus { pending, success, error }

extension NpcTaskStatusName on NpcTaskStatus {
  String get name => switch (this) {
        NpcTaskStatus.pending => 'pending',
        NpcTaskStatus.success => 'success',
        NpcTaskStatus.error => 'error',
      };

  static NpcTaskStatus parse(String value) => switch (value) {
        'success' => NpcTaskStatus.success,
        'error' => NpcTaskStatus.error,
        _ => NpcTaskStatus.pending,
      };
}

/// A structured record of one AI-employee command/response exchange —
/// backs the computer popup's "작업 이력" list instead of just exposing the
/// single most recent reply ([OfficeGame.lastReplyFrom]).
class NpcTask {
  const NpcTask({
    required this.id,
    required this.employeeId,
    required this.command,
    required this.status,
    required this.createdAt,
    this.result,
    this.errorMessage,
    this.attempts = 0,
    this.usage,
    this.documentPath,
  });

  final String id;
  final String employeeId;
  final String command;
  final NpcTaskStatus status;
  final DateTime createdAt;
  final String? result;
  final String? errorMessage;

  /// How many times `askEmployee` was actually called for this task — 1 on
  /// a first-try success or failure, 2 when the automatic retry-once
  /// kicked in after the first attempt failed.
  final int attempts;

  /// Token usage reported for the attempt that produced [result], if the
  /// provider reported it. Null while [status] is pending or error.
  final NpcUsage? usage;

  /// Path of the generated work document in the `npc-documents` Supabase
  /// Storage bucket (`<companyId>/<employeeId>/<taskId>.txt`), if one was
  /// produced for this task's result. Null for pending/error tasks and for
  /// sessions with no document generator configured (e.g. tests).
  final String? documentPath;

  NpcTask copyWith({
    NpcTaskStatus? status,
    String? result,
    String? errorMessage,
    int? attempts,
    NpcUsage? usage,
    String? documentPath,
  }) {
    return NpcTask(
      id: id,
      employeeId: employeeId,
      command: command,
      status: status ?? this.status,
      createdAt: createdAt,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      attempts: attempts ?? this.attempts,
      usage: usage ?? this.usage,
      documentPath: documentPath ?? this.documentPath,
    );
  }

  /// Row shape for the `npc_tasks` table (see
  /// docs/PHASE6_AI_EMPLOYEES.md's persistence section).
  Map<String, dynamic> toRow(String companyId) => {
        'id': id,
        'company_id': companyId,
        'employee_id': employeeId,
        'command': command,
        'status': status.name,
        'result': result,
        'error_message': errorMessage,
        'attempts': attempts,
        'prompt_tokens': usage?.promptTokens,
        'completion_tokens': usage?.completionTokens,
        'total_tokens': usage?.totalTokens,
        'document_path': documentPath,
        'created_at': createdAt.toIso8601String(),
      };

  factory NpcTask.fromRow(Map<String, dynamic> row) {
    final promptTokens = row['prompt_tokens'] as int?;
    final completionTokens = row['completion_tokens'] as int?;
    final totalTokens = row['total_tokens'] as int?;
    final hasUsage =
        promptTokens != null || completionTokens != null || totalTokens != null;
    return NpcTask(
      id: row['id'] as String,
      employeeId: row['employee_id'] as String,
      command: row['command'] as String,
      status: NpcTaskStatusName.parse(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      result: row['result'] as String?,
      errorMessage: row['error_message'] as String?,
      attempts: row['attempts'] as int? ?? 0,
      usage: hasUsage
          ? NpcUsage(
              promptTokens: promptTokens,
              completionTokens: completionTokens,
              totalTokens: totalTokens,
            )
          : null,
      documentPath: row['document_path'] as String?,
    );
  }
}
