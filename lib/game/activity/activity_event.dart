/// What kind of thing happened — used only to pick an icon in the activity
/// log UI; the human-readable summary always lives in [ActivityEvent.message].
enum ActivityType { employee, aiCommand, member, board, meeting }

extension ActivityTypeName on ActivityType {
  String get name => switch (this) {
        ActivityType.employee => 'employee',
        ActivityType.aiCommand => 'ai_command',
        ActivityType.member => 'member',
        ActivityType.board => 'board',
        ActivityType.meeting => 'meeting',
      };

  static ActivityType parse(String value) => switch (value) {
        'ai_command' => ActivityType.aiCommand,
        'member' => ActivityType.member,
        'board' => ActivityType.board,
        'meeting' => ActivityType.meeting,
        _ => ActivityType.employee,
      };
}

/// One entry in the company's activity feed — a roster edit, an AI
/// employee command resolving, a membership change, etc. Backs the office
/// screen's "알림" bell/"활동 기록" panel.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.actorName,
  });

  final String id;
  final ActivityType type;

  /// Pre-formatted Korean summary (e.g. "노아의 상태가 '작업 중'으로 바뀌었습니다") —
  /// built once when the event is logged, not reconstructed from raw fields.
  final String message;
  final DateTime createdAt;

  /// The signed-in player's display name at the time this was logged — the
  /// "who" half of an audit entry (the "what" is [message]). Null for
  /// events logged before this field existed. Note this is just a display
  /// name (from [PlayerProfile], editable in "직원 정보 관리"), not a stable
  /// user id — see docs/PHASE7_ADMIN.md's deferred-scope note.
  final String? actorName;

  Map<String, dynamic> toRow(String companyId) => {
        'id': id,
        'company_id': companyId,
        'type': type.name,
        'message': message,
        'actor_name': actorName,
        'created_at': createdAt.toIso8601String(),
      };

  factory ActivityEvent.fromRow(Map<String, dynamic> row) => ActivityEvent(
        id: row['id'] as String,
        type: ActivityTypeName.parse(row['type'] as String),
        message: row['message'] as String,
        actorName: row['actor_name'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
