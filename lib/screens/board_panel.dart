import 'package:ai_office/game/board/board_task.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter/material.dart';

/// The project/task board: three columns (할 일/진행 중/완료) with cards that
/// can move between columns, be assigned to an AI employee, and — when
/// assigned — be dispatched straight into that employee's chat as an
/// `@employee` command.
class BoardPanel extends StatefulWidget {
  const BoardPanel({required this.game, required this.onClose, super.key});

  final OfficeGame game;
  final VoidCallback onClose;

  @override
  State<BoardPanel> createState() => _BoardPanelState();
}

class _BoardPanelState extends State<BoardPanel> {
  static const _columns = [
    BoardTaskStatus.todo,
    BoardTaskStatus.inProgress,
    BoardTaskStatus.done,
  ];

  Future<void> _openAddTaskDialog() async {
    final titleController = TextEditingController();
    AiEmployee? assignee;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('새 업무'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '제목'),
                // Without this, typing never rebuilds the dialog, so the
                // "추가" button below (which reads titleController.text)
                // stays stuck showing its very first (empty) enabled state.
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AiEmployee?>(
                initialValue: assignee,
                decoration: const InputDecoration(labelText: '담당자'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('미배정')),
                  for (final employee in widget.game.employees)
                    DropdownMenuItem(value: employee, child: Text(employee.name)),
                ],
                onChanged: (value) => setDialogState(() => assignee = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: titleController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
    if (created == true && titleController.text.trim().isNotEmpty) {
      widget.game.createBoardTask(
        title: titleController.text.trim(),
        assignee: assignee,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksByStatus = {
      for (final status in _columns)
        status: widget.game.boardTasks.where((t) => t.status == status).toList(),
    };

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 720,
          height: 480,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF17212B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5DE0E6)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '업무 보드',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openAddTaskDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('새 업무'),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: widget.onClose,
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final status in _columns)
                      Expanded(
                        child: _BoardColumn(
                          status: status,
                          tasks: tasksByStatus[status]!,
                          game: widget.game,
                          onDispatched: widget.onClose,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.status,
    required this.tasks,
    required this.game,
    required this.onDispatched,
  });

  final BoardTaskStatus status;
  final List<BoardTask> tasks;
  final OfficeGame game;
  final VoidCallback onDispatched;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${status.displayLabel} (${tasks.length})',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DragTarget<String>(
                onAcceptWithDetails: (details) =>
                    game.setBoardTaskStatus(details.data, status),
                builder: (context, candidateData, rejectedData) => Container(
                  // Highlights the column a dragged card is currently over
                  // (`candidateData` is non-empty only for the target the
                  // pointer is hovering right now) — otherwise transparent
                  // so an empty column keeps its plain "없음" look.
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? const Color(0x225DE0E6)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: tasks.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            '없음',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.separated(
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, index) => _BoardTaskCard(
                            task: tasks[index],
                            game: game,
                            onDispatched: onDispatched,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _BoardTaskCard extends StatelessWidget {
  const _BoardTaskCard({
    required this.task,
    required this.game,
    required this.onDispatched,
  });

  final BoardTask task;
  final OfficeGame game;
  final VoidCallback onDispatched;

  Future<void> _editDescription(BuildContext context) async {
    final controller = TextEditingController(text: task.description ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('"${task.title}" 설명'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(hintText: '업무 설명을 입력하세요'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (saved == true) {
      game.editBoardTaskDescription(task.id, controller.text);
    }
  }

  Widget _buildCard(BuildContext context, {bool dragging = false}) => Opacity(
        opacity: dragging ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF23303C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: const TextStyle(color: Colors.white)),
              if (task.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              if (task.assigneeName != null) ...[
                const SizedBox(height: 4),
                Text(
                  '담당: ${task.assigneeName}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  if (task.status != BoardTaskStatus.todo)
                    IconButton(
                      tooltip: '이전 단계로',
                      iconSize: 18,
                      color: Colors.white70,
                      onPressed: () => game.moveBoardTask(task.id, forward: false),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  if (task.status != BoardTaskStatus.done)
                    IconButton(
                      tooltip: '다음 단계로',
                      iconSize: 18,
                      color: Colors.white70,
                      onPressed: () => game.moveBoardTask(task.id, forward: true),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  IconButton(
                    tooltip: '설명 편집',
                    iconSize: 18,
                    color: Colors.white70,
                    onPressed: () => _editDescription(context),
                    icon: const Icon(Icons.edit_note),
                  ),
                  if (task.assigneeId != null)
                    IconButton(
                      tooltip: 'AI에게 지시',
                      iconSize: 18,
                      color: const Color(0xFF5DE0E6),
                      onPressed: () {
                        game.dispatchBoardTaskToAssignee(task);
                        onDispatched();
                      },
                      icon: const Icon(Icons.send),
                    ),
                  IconButton(
                    tooltip: '삭제',
                    iconSize: 18,
                    color: Colors.white38,
                    onPressed: () => game.deleteBoardTask(task.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Draggable<String>(
        data: task.id,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 200, child: _buildCard(context)),
        ),
        childWhenDragging: _buildCard(context, dragging: true),
        child: _buildCard(context),
      );
}
