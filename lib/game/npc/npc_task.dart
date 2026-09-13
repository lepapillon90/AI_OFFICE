/// The lifecycle of one `@employee command` dispatched to an AI employee.
enum NpcTaskStatus { pending, success, error }

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

  NpcTask copyWith({
    NpcTaskStatus? status,
    String? result,
    String? errorMessage,
    int? attempts,
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
    );
  }
}
