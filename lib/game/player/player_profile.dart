import 'package:ai_office/game/player/player_status.dart';

/// Editable identity shown above the player's character: name, role
/// (job title), and a presence status badge.
class PlayerProfile {
  const PlayerProfile({
    required this.name,
    required this.role,
    required this.status,
  });

  final String name;
  final String role;
  final PlayerStatus status;

  static const initial = PlayerProfile(
    name: '사용자',
    role: '팀원',
    status: PlayerStatus.office,
  );

  PlayerProfile copyWith({
    String? name,
    String? role,
    PlayerStatus? status,
  }) {
    return PlayerProfile(
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }
}
