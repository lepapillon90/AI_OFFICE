import 'package:ai_office/data/company_member.dart';
import 'package:ai_office/data/company_repository.dart';
import 'package:ai_office/data/company_role.dart';
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
    super.key,
  });

  final OfficeGame game;
  final String companyId;
  final CompanyRepository repository;
  final VoidCallback onClose;

  /// Null for callers without auth (tests) — hides the Slack section.
  final SlackIntegrationRepository? slackRepository;

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

  @override
  void initState() {
    super.initState();
    _loadSlackWebhook();
  }

  @override
  void dispose() {
    _slackUrlController.dispose();
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

  Future<void> _changeRole(CompanyMember member, CompanyRole role) async {
    setState(() => _error = null);
    try {
      await widget.repository.updateMemberRole(
        widget.companyId,
        member.userId,
        role,
      );
      setState(() => _membersFuture = _loadMembers());
    } catch (e) {
      setState(() => _error = '역할 변경에 실패했습니다: $e');
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
            constraints: const BoxConstraints(maxHeight: 620),
            decoration: BoxDecoration(
              color: const Color(0xFF17212B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5DE0E6)),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Flexible(
                  child: FutureBuilder<List<CompanyMember>>(
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
                            child: CircularProgressIndicator(
                              color: Color(0xFF5DE0E6),
                            ),
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
                        itemCount: members.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 16, color: Colors.white24),
                        itemBuilder: (_, index) => _MemberRow(
                          member: members[index],
                          onChangeRole: (role) =>
                              _changeRole(members[index], role),
                        ),
                      );
                    },
                  ),
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
              ],
            ),
          ),
        ),
      );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onChangeRole});

  final CompanyMember member;
  final void Function(CompanyRole role) onChangeRole;

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
          else
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
        ],
      );
}
