import 'package:ai_office/data/company_member.dart';
import 'package:ai_office/data/company_repository.dart';
import 'package:ai_office/data/company_role.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/activity_panel.dart';
import 'package:flutter/material.dart';

/// The owner-only admin screen: the company's real member accounts (not
/// the AI employee roster — see [RosterEditorDialog] for that) and their
/// roles, plus a shortcut into the activity/audit log.
class AdminPanel extends StatefulWidget {
  const AdminPanel({
    required this.game,
    required this.companyId,
    required this.repository,
    required this.onClose,
    super.key,
  });

  final OfficeGame game;
  final String companyId;
  final CompanyRepository repository;
  final VoidCallback onClose;

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  late Future<List<CompanyMember>> _membersFuture = _loadMembers();
  String? _error;

  Future<List<CompanyMember>> _loadMembers() =>
      widget.repository.fetchMembers(widget.companyId);

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
            constraints: const BoxConstraints(maxHeight: 520),
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
