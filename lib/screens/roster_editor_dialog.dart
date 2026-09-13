import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/game/player/player_status.dart';
import 'package:flutter/material.dart';

/// Lets an owner or HR manager edit the player's and each AI employee's
/// name, role, and status badge. Not yet gated by real authentication —
/// that arrives with the Phase 4 Supabase auth/roles work.
class RosterEditorDialog extends StatelessWidget {
  const RosterEditorDialog({required this.game, super.key});

  final OfficeGame game;

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}
