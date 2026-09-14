import 'npc_status.dart';

class AiEmployee {
  const AiEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.provider,
    required this.workstationId,
    required this.status,
    this.computerLinked = false,
  });

  final String id;
  final String name;
  final String role;
  final String provider;
  final String workstationId;
  final NpcStatus status;

  /// Opt-in whitelist flag (docs/PHASE8_REMOTE_AGENT.md) — when true, an
  /// `@employee 터미널 열어줘`/`폴더 만들어줘` chat command routes to the local
  /// agent running on this employee's real computer (identified by
  /// [workstationId], not [id] — [id] is an opaque Supabase UUID in
  /// production, [workstationId] is the stable, human-readable desk name
  /// (e.g. "desk-1") an operator can actually type into the agent's
  /// `--agent-key`) instead of asking the employee's LLM. Defaults to
  /// false so an ordinary AI employee's normal conversation (which might
  /// happen to contain the word "폴더") is never reinterpreted as a real
  /// remote command.
  final bool computerLinked;

  String get displayStatus => status.displayLabel;

  AiEmployee copyWith({
    String? id,
    String? name,
    String? role,
    String? provider,
    String? workstationId,
    NpcStatus? status,
    bool? computerLinked,
  }) {
    return AiEmployee(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      provider: provider ?? this.provider,
      workstationId: workstationId ?? this.workstationId,
      status: status ?? this.status,
      computerLinked: computerLinked ?? this.computerLinked,
    );
  }
}
