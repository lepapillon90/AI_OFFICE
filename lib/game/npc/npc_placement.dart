import 'package:ai_office/game/floors/floor.dart';
import 'package:flame/components.dart';

/// Where a non-workspace-floor AI employee stands, keyed by
/// [AiEmployee.workstationId] the same way [Workstation] does for the 2층
/// desk grid — kept separate since those floors have their own furniture
/// layout (see the matching `*_map.dart` file) rather than a repeating
/// desk/computer/chair unit.
class NpcPlacement {
  const NpcPlacement({
    required this.id,
    required this.floor,
    required this.position,
  });

  final String id;
  final Floor floor;

  /// Where the NPC stands, already the seat's centre (unlike
  /// [Workstation.seatPosition], there's no shared desk-relative formula
  /// here since each floor's furniture is laid out by hand).
  final Vector2 position;

  static final List<NpcPlacement> all = [
    // 3층 프로젝트룸: the shared two-desk table from ProjectRoomMap.
    NpcPlacement(
        id: 'project-desk-1',
        floor: Floor.projectRoom,
        position: Vector2(320, 320)),
    NpcPlacement(
        id: 'project-desk-2',
        floor: Floor.projectRoom,
        position: Vector2(384, 320)),
    // 4층 대표실: the CEO desk from ExecutiveMap.
    NpcPlacement(
        id: 'executive-desk',
        floor: Floor.executive,
        position: Vector2(448, 384)),
  ];

  static List<NpcPlacement> forFloor(Floor floor) =>
      all.where((p) => p.floor == floor).toList();
}
