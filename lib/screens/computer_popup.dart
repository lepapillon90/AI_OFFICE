import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/npc/npc_task.dart';
import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/util/open_url.dart';
import 'package:flutter/material.dart';

/// A workstation's AI employee: status at a glance, "대화하기" to open a
/// chat with them (same `@employee` pipeline as the space chat), and
/// "작업 이력" to see their structured command/response history — including
/// in-flight and failed attempts, not just the latest reply — without
/// leaving the popup.
class ComputerPopup extends StatelessWidget {
  const ComputerPopup({
    required this.employee,
    required this.game,
    required this.onClose,
    super.key,
  });

  final AiEmployee employee;
  final OfficeGame game;
  final VoidCallback onClose;

  void _showTaskHistory(BuildContext context) {
    final tasks = game.tasksFor(employee);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${employee.name}의 작업 이력'),
        content: SizedBox(
          width: 320,
          child: tasks.isEmpty
              ? const Text('아직 대화한 내역이 없습니다. "대화하기"로 업무를 지시해보세요.')
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (_, index) =>
                        _TaskTile(task: tasks[index], game: game),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF17212B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5DE0E6)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employee.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: onClose,
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  employee.role,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  employee.displayStatus,
                  style: TextStyle(
                    color: employee.status.displayColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  final usage = game.usageFor(employee);
                  if (usage.calls == 0) {
                    return const SizedBox.shrink();
                  }
                  final tokenPart = usage.totalTokens > 0
                      ? ' · ${usage.totalTokens} 토큰 (약 ${formatUsd(usage.estimatedCostUsd)})'
                      : '';
                  return Text(
                    '호출 ${usage.calls}회 (성공 ${usage.successes} · 실패 '
                    '${usage.failures})$tokenPart',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  );
                }),
                const SizedBox(height: 24),
                const Text(
                  '업무 지시',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => game.openChatWithEmployee(employee),
                        child: const Text('대화하기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showTaskHistory(context),
                        child: const Text('작업 이력'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

/// One entry in the "작업 이력" dialog: the command, a status icon, and its
/// result/error — plus a retry note when [NpcTask.attempts] shows the
/// automatic retry-on-failure kicked in.
class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.game});

  final NpcTask task;
  final OfficeGame game;

  Future<void> _openDocument(BuildContext context) async {
    final url = await game.documentUrlFor(task);
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문서를 열지 못했습니다.')),
        );
      }
      return;
    }
    openInNewTab(url);
  }

  IconData get _icon => switch (task.status) {
        NpcTaskStatus.pending => Icons.hourglass_top,
        NpcTaskStatus.success => Icons.check_circle,
        NpcTaskStatus.error => Icons.error,
      };

  Color get _color => switch (task.status) {
        NpcTaskStatus.pending => const Color(0xFFFFC107),
        NpcTaskStatus.success => const Color(0xFF4CAF50),
        NpcTaskStatus.error => const Color(0xFFF44336),
      };

  String get _body => switch (task.status) {
        NpcTaskStatus.pending => '처리 중...',
        NpcTaskStatus.success => task.result ?? '',
        NpcTaskStatus.error => task.errorMessage ?? '오류가 발생했습니다.',
      };

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, size: 16, color: _color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.command,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_body, style: const TextStyle(color: Colors.white70)),
          if (task.attempts > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                task.status == NpcTaskStatus.success
                    ? '재시도 끝에 성공 (${task.attempts}회 시도)'
                    : '재시도했지만 실패 (${task.attempts}회 시도)',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          if (task.usage?.totalTokens != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${task.usage!.totalTokens} 토큰 사용 '
                '(약 ${formatUsd(task.usage!.estimatedCostUsd)})',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          if (task.documentPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Builder(
                builder: (context) => OutlinedButton.icon(
                  onPressed: () => _openDocument(context),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('문서 열기'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ),
        ],
      );
}
