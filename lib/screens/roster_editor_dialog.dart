import 'package:ai_office/data/company_repository.dart';
import 'package:ai_office/data/company_role.dart';
import 'package:ai_office/data/pending_invite.dart';
import 'package:ai_office/data/username_auth.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/game/player/player_status.dart';
import 'package:flutter/material.dart';

/// Lets an owner or HR manager edit the player's and each AI employee's
/// name, role, and status badge, and (when [companyId]/[repository] are
/// provided, i.e. behind real Supabase auth) invite new members.
class RosterEditorDialog extends StatelessWidget {
  const RosterEditorDialog({
    required this.game,
    this.companyId,
    this.repository,
    this.canGrantHrManager = false,
    super.key,
  });

  final OfficeGame game;
  final String? companyId;
  final CompanyRepository? repository;

  /// Whether the current user may invite someone as an hr_manager — owner
  /// only, so an hr_manager can't create a peer manager (or promote
  /// themselves). Server-side RLS enforces this too either way; this just
  /// keeps the option from being offered client-side.
  final bool canGrantHrManager;

  @override
  Widget build(BuildContext context) {
    final companyId = this.companyId;
    final repository = this.repository;
    return AlertDialog(
      title: const Text('직원 정보 관리'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlayerEditor(game: game),
              const Divider(height: 32),
              for (final employee in game.employees)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _EmployeeEditor(game: game, employeeId: employee.id),
                ),
              if (companyId != null && repository != null) ...[
                const Divider(height: 32),
                _InviteSection(
                  companyId: companyId,
                  repository: repository,
                  canGrantHrManager: canGrantHrManager,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _PlayerEditor extends StatefulWidget {
  const _PlayerEditor({required this.game});

  final OfficeGame game;

  @override
  State<_PlayerEditor> createState() => _PlayerEditorState();
}

class _PlayerEditorState extends State<_PlayerEditor> {
  late final _nameController =
      TextEditingController(text: widget.game.playerProfile.name);
  late final _roleController =
      TextEditingController(text: widget.game.playerProfile.role);

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.game.playerProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('플레이어', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '이름'),
          onChanged: (value) =>
              widget.game.updatePlayerProfile(profile.copyWith(name: value)),
        ),
        TextField(
          controller: _roleController,
          decoration: const InputDecoration(labelText: '직책'),
          onChanged: (value) =>
              widget.game.updatePlayerProfile(profile.copyWith(role: value)),
        ),
        DropdownButtonFormField<PlayerStatus>(
          initialValue: profile.status,
          decoration: const InputDecoration(labelText: '상태'),
          items: PlayerStatus.values
              .map((status) => DropdownMenuItem(
                    value: status,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: status.displayColor),
                        const SizedBox(width: 8),
                        Text(status.displayLabel),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (status) {
            if (status == null) {
              return;
            }
            widget.game.updatePlayerProfile(profile.copyWith(status: status));
          },
        ),
      ],
    );
  }
}

class _EmployeeEditor extends StatefulWidget {
  const _EmployeeEditor({required this.game, required this.employeeId});

  final OfficeGame game;
  final String employeeId;

  @override
  State<_EmployeeEditor> createState() => _EmployeeEditorState();
}

class _EmployeeEditorState extends State<_EmployeeEditor> {
  late final _nameController = TextEditingController(text: _employee.name);
  late final _roleController = TextEditingController(text: _employee.role);

  AiEmployee get _employee =>
      widget.game.employees.firstWhere((e) => e.id == widget.employeeId);

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employee = _employee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(employee.workstationId,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '이름'),
          onChanged: (value) =>
              widget.game.updateEmployee(employee.copyWith(name: value)),
        ),
        TextField(
          controller: _roleController,
          decoration: const InputDecoration(labelText: '직책'),
          onChanged: (value) =>
              widget.game.updateEmployee(employee.copyWith(role: value)),
        ),
        DropdownButtonFormField<NpcStatus>(
          initialValue: employee.status,
          decoration: const InputDecoration(labelText: '상태'),
          items: NpcStatus.values
              .map((status) => DropdownMenuItem(
                    value: status,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: status.displayColor),
                        const SizedBox(width: 8),
                        Text(status.displayLabel),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (status) {
            if (status == null) {
              return;
            }
            widget.game.updateEmployee(employee.copyWith(status: status));
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('실제 컴퓨터와 연결(원격 명령)'),
          subtitle: Text(
            '켜면 "@${employee.name} 터미널 열어줘"처럼 말했을 때 이 직원의 자리'
            '(${employee.workstationId})에서 실행 중인 로컬 에이전트로 명령이 감 — '
            'docs/PHASE8_REMOTE_AGENT.md',
            style: const TextStyle(fontSize: 11),
          ),
          value: employee.computerLinked,
          onChanged: (linked) {
            if (linked == null) {
              return;
            }
            // Unlike the name/role TextFields (whose own controller shows
            // typed text immediately) and the status dropdown (which caches
            // its own selection via `initialValue`), this checkbox's
            // `value:` is controlled — it only ever shows what re-reading
            // `employee.computerLinked` returns, so without a local
            // setState the box would visibly stay unchecked even though
            // updateEmployee() already applied the change underneath.
            setState(() {
              widget.game
                  .updateEmployee(employee.copyWith(computerLinked: linked));
            });
          },
        ),
      ],
    );
  }
}

/// Lets the current manager invite a username to join the company, and
/// shows/withdraws invites that haven't been accepted yet.
class _InviteSection extends StatefulWidget {
  const _InviteSection({
    required this.companyId,
    required this.repository,
    required this.canGrantHrManager,
  });

  final String companyId;
  final CompanyRepository repository;
  final bool canGrantHrManager;

  @override
  State<_InviteSection> createState() => _InviteSectionState();
}

class _InviteSectionState extends State<_InviteSection> {
  final _usernameController = TextEditingController();
  CompanyRole _role = CompanyRole.member;
  late Future<List<PendingInvite>> _invitesFuture = _loadInvites();
  String? _error;

  Future<List<PendingInvite>> _loadInvites() =>
      widget.repository.fetchPendingInvites(widget.companyId);

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final username = _usernameController.text.trim();
    if (!UsernameAuth.isValidUsername(username)) {
      setState(() => _error = '아이디는 영문/숫자/밑줄 3~20자여야 합니다.');
      return;
    }
    setState(() => _error = null);
    try {
      await widget.repository.inviteMember(
        widget.companyId,
        username: username,
        role: _role,
      );
      _usernameController.clear();
      setState(() {
        _invitesFuture = _loadInvites();
      });
    } catch (e) {
      setState(() => _error = '초대에 실패했습니다: $e');
    }
  }

  Future<void> _cancelInvite(String inviteId) async {
    await widget.repository.cancelInvite(inviteId);
    setState(() {
      _invitesFuture = _loadInvites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('구성원 초대', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '초대할 아이디'),
                onSubmitted: (_) => _sendInvite(),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<CompanyRole>(
              value: _role,
              items: [
                const DropdownMenuItem(
                  value: CompanyRole.member,
                  child: Text('일반 직원'),
                ),
                // Only the owner can grant hr_manager — an hr_manager
                // creating a peer manager (or promoting themselves) would
                // be a privilege escalation; server-side RLS enforces this
                // too regardless of what's offered here.
                if (widget.canGrantHrManager)
                  const DropdownMenuItem(
                    value: CompanyRole.hrManager,
                    child: Text('인사관리자'),
                  ),
              ],
              onChanged: (role) {
                if (role != null) {
                  setState(() => _role = role);
                }
              },
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _sendInvite,
            child: const Text('초대장 보내기'),
          ),
        ),
        FutureBuilder<List<PendingInvite>>(
          future: _invitesFuture,
          builder: (context, snapshot) {
            final invites = snapshot.data;
            if (invites == null) {
              return const SizedBox.shrink();
            }
            if (invites.isEmpty) {
              return const Text(
                '대기 중인 초대가 없습니다.',
                style: TextStyle(color: Colors.black54),
              );
            }
            return Column(
              children: [
                for (final invite in invites)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(invite.username),
                    subtitle: Text(
                      invite.role == CompanyRole.hrManager ? '인사관리자' : '일반 직원',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: '초대 취소',
                      onPressed: () => _cancelInvite(invite.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
