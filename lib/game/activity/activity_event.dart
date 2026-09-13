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
  });

  final String id;
  final ActivityType type;

  /// Pre-formatted Korean summary (e.g. "노아의 상태가 '작업 중'으로 바뀌었습니다") —
  /// built once when the event is logged, not reconstructed from raw fields.
  final String message;
  final DateTime createdAt;

  Map<String, dynamic> toRow(String companyId) => {
        'id': id,
        'company_id': companyId,
        'type': type.name,
        'message': message,
        'created_at': createdAt.toIso8601String(),
      };

  factory ActivityEvent.fromRow(Map<String, dynamic> row) => ActivityEvent(
        id: row['id'] as String,
        type: ActivityTypeName.parse(row['type'] as String),
        message: row['message'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
