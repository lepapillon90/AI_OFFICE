/// Where a board task sits in the workflow.
enum BoardTaskStatus { todo, inProgress, done }

extension BoardTaskStatusDisplay on BoardTaskStatus {
  String get displayLabel => switch (this) {
        BoardTaskStatus.todo => '할 일',
        BoardTaskStatus.inProgress => '진행 중',
        BoardTaskStatus.done => '완료',
      };

  String get name => switch (this) {
        BoardTaskStatus.todo => 'todo',
        BoardTaskStatus.inProgress => 'in_progress',
        BoardTaskStatus.done => 'done',
      };

  static BoardTaskStatus parse(String value) => switch (value) {
        'in_progress' => BoardTaskStatus.inProgress,
        'done' => BoardTaskStatus.done,
        _ => BoardTaskStatus.todo,
      };

  /// The next column over (no-op — stays put — once already [done]).
  BoardTaskStatus get next => switch (this) {
        BoardTaskStatus.todo => BoardTaskStatus.inProgress,
        BoardTaskStatus.inProgress => BoardTaskStatus.done,
        BoardTaskStatus.done => BoardTaskStatus.done,
      };

  /// The previous column over (no-op once already [todo]).
  BoardTaskStatus get previous => switch (this) {
        BoardTaskStatus.todo => BoardTaskStatus.todo,
        BoardTaskStatus.inProgress => BoardTaskStatus.todo,
        BoardTaskStatus.done => BoardTaskStatus.inProgress,
      };
}

/// One card on the project/task board.
class BoardTask {
  const BoardTask({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.assigneeId,
    this.assigneeName,
  });

  final String id;
  final String title;
  final String? description;
  final BoardTaskStatus status;

  /// The assigned AI employee's id, or null when unassigned. [assigneeName]
  /// is kept alongside it (denormalized) so the board can show a name
  /// without a roster lookup, and still reads sensibly if that employee is
  /// later removed from the roster.
  final String? assigneeId;
  final String? assigneeName;

  final DateTime createdAt;
  final DateTime updatedAt;

  BoardTask copyWith({
    String? title,
    Object? description = _unset,
    BoardTaskStatus? status,
    Object? assigneeId = _unset,
    Object? assigneeName = _unset,
    DateTime? updatedAt,
  }) {
    return BoardTask(
      id: id,
      title: title ?? this.title,
      description:
          identical(description, _unset) ? this.description : description as String?,
      status: status ?? this.status,
      assigneeId:
          identical(assigneeId, _unset) ? this.assigneeId : assigneeId as String?,
      assigneeName: identical(assigneeName, _unset)
          ? this.assigneeName
          : assigneeName as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toRow(String companyId) => {
        'id': id,
        'company_id': companyId,
        'title': title,
        'description': description,
        'status': status.name,
        'assignee_id': assigneeId,
        'assignee_name': assigneeName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory BoardTask.fromRow(Map<String, dynamic> row) => BoardTask(
        id: row['id'] as String,
        title: row['title'] as String,
        description: row['description'] as String?,
        status: BoardTaskStatusDisplay.parse(row['status'] as String),
        assigneeId: row['assignee_id'] as String?,
        assigneeName: row['assignee_name'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
}

/// Sentinel distinguishing "not passed" from "explicitly passed null" for
/// [BoardTask.copyWith]'s nullable fields.
const _unset = Object();
