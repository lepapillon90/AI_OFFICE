/// A snapshot of one other signed-in user's position and profile, shared
/// over a Supabase Realtime Presence channel.
class RemotePlayerState {
  const RemotePlayerState({
    required this.userId,
    required this.name,
    required this.role,
    required this.statusLabel,
    required this.statusColorValue,
    required this.floorLevel,
    required this.x,
    required this.y,
  });

  final String userId;
  final String name;
  final String role;
  final String statusLabel;
  final int statusColorValue;
  final int floorLevel;
  final double x;
  final double y;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'role': role,
        'statusLabel': statusLabel,
        'statusColorValue': statusColorValue,
        'floorLevel': floorLevel,
        'x': x,
        'y': y,
      };

  /// Returns null for a malformed payload rather than throwing, since this
  /// is parsed from data other clients broadcast.
  static RemotePlayerState? fromJson(Map<String, dynamic> json) {
    try {
      return RemotePlayerState(
        userId: json['userId'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        statusLabel: json['statusLabel'] as String,
        statusColorValue: json['statusColorValue'] as int,
        floorLevel: json['floorLevel'] as int,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
