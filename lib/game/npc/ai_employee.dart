import 'npc_status.dart';

class AiEmployee {
  const AiEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.provider,
    required this.workstationId,
    required this.status,
  });

  final String id;
  final String name;
  final String role;
  final String provider;
  final String workstationId;
  final NpcStatus status;

  String get displayStatus => status.displayLabel;

  AiEmployee copyWith({
    String? id,
    String? name,
    String? role,
    String? provider,
    String? workstationId,
    NpcStatus? status,
  }) {
    return AiEmployee(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      provider: provider ?? this.provider,
      workstationId: workstationId ?? this.workstationId,
      status: status ?? this.status,
    );
  }
}
