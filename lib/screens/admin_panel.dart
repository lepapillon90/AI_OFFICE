import 'package:ai_office/data/company_member.dart';
import 'package:ai_office/data/company_repository.dart';
import 'package:ai_office/data/company_role.dart';
import 'package:ai_office/data/server_lock_repository.dart';
import 'package:ai_office/data/slack_integration_repository.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/activity_panel.dart';
import 'package:flutter/material.dart';

/// The owner-only admin screen: the company's real member accounts (not
/// the AI employee roster — see [RosterEditorDialog] for that) and their
/// roles, a shortcut into the activity/audit log, and the Slack webhook
/// integration (docs/PHASE8_SLACK.md).
class AdminPanel extends StatefulWidget {
  const AdminPanel({
    required this.game,
    required this.companyId,
    required this.repository,
    required this.onClose,
    this.slackRepository,
    this.serverLockRepository,
    super.key,
  });

  final OfficeGame game;
  final String companyId;
  final CompanyRepository repository;
  final VoidCallback onClose;

  /// Null for callers without auth (tests) — hides the Slack section.
  final SlackIntegrationRepository? slackRepository;

  /// Null for callers without auth (tests) — hides the server lock section.
  final ServerLockRepository? serverLockRepository;

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  late Future<List<CompanyMember>> _membersFuture = _loadMembers();
  String? _error;

  final _slackUrlController = TextEditingController();
  bool _slackLoaded = false;
  bool _slackSaving = false;
  String? _slackStatus;

  final _serverPasswordController = TextEditingController();
  bool _serverPasswordSaving = false;
  String? _serverPasswordStatus;

  @override
  void initState() {
    super.initState();
    _loadSlackWebhook();
  }

  @override
  void dispose() {
    _slackUrlController.dispose();
    _serverPasswordController.dispose();
    super.dispose();
  }

  Future<List<CompanyMember>> _loadMembers() =>
      widget.repository.fetchMembers(widget.companyId);

  Future<void> _loadSlackWebhook() async {
    final repo = widget.slackRepository;
    if (repo == null) {
      return;
    }
    try {
      final url = await repo.fetchWebhookUrl(widget.companyId);
      if (mounted) {
        setState(() {
          _slackUrlController.text = url ?? '';
          _slackLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _slackLoaded = true);
      }
    }
  }

  Future<void> _saveSlackWebhook() async {
    final repo = widget.slackRepository;
    if (repo == null) {
      return;
    }
    setState(() {
      _slackSaving = true;
      _slackStatus = null;
    });
    try {
      await repo.saveWebhookUrl(widget.companyId, _slackUrlController.text);
      if (mounted) {
        setState(() {
          _slackSaving = false;
          _slackStatus = _slackUrlController.text.trim().isEmpty
              ? 'Slack 연동을 해제했습니다.'
              : '저장했습니다 — 이제부터 활동 기록이 Slack으로도 전송됩니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _slackSaving = false;
          _slackStatus = '저장에 실패했습니다: $e';
        });
      }
    }
  }

  Future<void> _saveServerPassword() async {
    final repo = widget.serverLockRepository;
    if (repo == null) {
      return;
    }
    setState(() {
      _serverPasswordSaving = true;
      _serverPasswordStatus = null;
    });
    try {
      await repo.savePassword(widget.companyId, _serverPasswordController.text);
      final cleared = _serverPasswordController.text.trim().isEmpty;
      if (mounted) {
        setState(() {
          _serverPasswordSaving = false;
          _serverPasswordController.clear();
          _serverPasswordStatus = cleared
              ? '서버 비밀번호를 해제했습니다 — 이제 "@서버" 명령이 잠기지 않습니다.'
              : '저장했습니다 — 2층 서버기계에서 이 비밀번호를 입력해야 "@서버" 명령을 쓸 수 있습니다.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverPasswordSaving = false;
          _serverPasswordStatus = '저장에 실패했습니다: $e';
        });
      }
    }
  }

  Future<void> _changeRole(CompanyMember member, CompanyRole role) async {
    setState(() => _error = null);
    try {
      await widget.repository.updateMemberRole(
        widget.companyId,
        member.userId,
        role,
      );
      // Block body, not `() => _membersFuture = _loadMembers()`: an arrow
      // function's body is an expression whose *value* becomes the
      // callback's return value, and an assignment expression evaluates to
      // the assigned value — here, the Future _loadMembers() returns.
      // setState() asserts its callback must be synchronous (returning
      // void), so that arrow form throws "setState() callback argument
      // returned a Future" every time a role change actually succeeds.
      setState(() {
        _membersFuture = _loadMembers();
      });
    } catch (e) {
      setState(() => _error = '역할 변경에 실패했습니다: $e');
    }
  }

  Future<void> _removeMember(CompanyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('구성원 제거'),
        content: Text(
          '"${member.username}"님을 회사에서 제거하시겠어요?\n'
          '계정 자체는 삭제되지 않고, 이 회사에서만 나가게 됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('제거'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _error = null);
    try {
      await widget.repository.removeMember(widget.companyId, member.userId);
      setState(() {
        _membersFuture = _loadMembers();
      });
    } catch (e) {
      setState(() => _error = '구성원 제거에 실패했습니다: $e');
    }
  }

  void _openActivityPanel() {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ActivityPanel(
          game: widget.game,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            // A fixed height (not a maxHeight the Column merely tries to
            // respect) so the body below can be made genuinely
            // scrollable — with maxHeight alone, content that happened to
            // land just past the limit (e.g. a long Slack webhook URL)
            // hard-overflowed instead of scrolling, as a real user hit.
            height: 620,
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
                        '관리자 화면',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: widget.onClose,
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(child: SingleChildScrollView(child: _buildBody())),
              ],
            ),
          ),
        ),
      );

  /// Everything below the fixed title bar — scrolled as one unit (see
  /// [build]'s comment on why) rather than each section trying to manage
  /// its own overflow independently.
  Widget _buildBody() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('구성원', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFF44336)),
              ),
            ),
          FutureBuilder<List<CompanyMember>>(
            future: _membersFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  '구성원 목록을 불러오지 못했습니다.\n${snapshot.error}',
                  style: const TextStyle(color: Colors.white70),
                );
              }
              final members = snapshot.data;
              if (members == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF5DE0E6)),
                  ),
                );
              }
              if (members.isEmpty) {
                return const Text(
                  '구성원이 없습니다.',
                  style: TextStyle(color: Colors.white38),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 16, color: Colors.white24),
                itemBuilder: (_, index) => _MemberRow(
                  member: members[index],
                  onChangeRole: (role) => _changeRole(members[index], role),
                  onRemove: () => _removeMember(members[index]),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openActivityPanel,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('감사 기록 보기'),
            ),
          ),
          if (widget.slackRepository != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            const Text('Slack 연동', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            const Text(
              '활동 기록에 남는 모든 이벤트를 이 웹훅으로 전송합니다. 비워두면 연동이 꺼집니다.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _slackUrlController,
              enabled: _slackLoaded && !_slackSaving,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'https://hooks.slack.com/services/...',
                hintStyle: TextStyle(color: Colors.white38),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _slackLoaded && !_slackSaving ? _saveSlackWebhook : null,
                    child: _slackSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF5DE0E6),
                            ),
                          )
                        : const Text('저장'),
                  ),
                ),
              ],
            ),
            if (_slackStatus != null) ...[
              const SizedBox(height: 4),
              Text(
                _slackStatus!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
          if (widget.serverLockRepository != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            const Text('서버 잠금(게임 속 서버기계)',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            const Text(
              '2층 서버기계에서 이 비밀번호를 맞춰야 "@서버" 원격 명령을 쓸 수 있습니다. 비워두면'
              ' 잠금이 꺼집니다(누구나 바로 사용 가능). 이미 설정된 비밀번호는 보안상 다시 보여주지'
              ' 않으니, 바꿀 때만 새 값을 입력해주세요.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _serverPasswordController,
              enabled: !_serverPasswordSaving,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '새 비밀번호 (바꿀 때만 입력)',
                hintStyle: TextStyle(color: Colors.white38),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _serverPasswordSaving ? null : _saveServerPassword,
                    child: _serverPasswordSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF5DE0E6),
                            ),
                          )
                        : const Text('저장'),
                  ),
                ),
              ],
            ),
            if (_serverPasswordStatus != null) ...[
              const SizedBox(height: 4),
              Text(
                _serverPasswordStatus!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ],
      );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.onChangeRole,
    required this.onRemove,
  });

  final CompanyMember member;
  final void Function(CompanyRole role) onChangeRole;

  /// Never invoked for the owner's own row — see build(), which omits the
  /// button entirely there (removing the owner would leave the company
  /// without one).
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              member.username,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (member.role == CompanyRole.owner)
            const Text('대표', style: TextStyle(color: Colors.white38))
          else ...[
            DropdownButton<CompanyRole>(
              value: member.role,
              dropdownColor: const Color(0xFF23303C),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: CompanyRole.member,
                  child: Text('일반 직원'),
                ),
                DropdownMenuItem(
                  value: CompanyRole.hrManager,
                  child: Text('인사관리자'),
                ),
              ],
              onChanged: (role) {
                if (role != null) {
                  onChangeRole(role);
                }
              },
            ),
            IconButton(
              tooltip: '구성원 제거',
              iconSize: 18,
              color: Colors.white38,
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined),
            ),
          ],
        ],
      );
}
