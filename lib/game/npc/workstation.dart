import 'package:flame/components.dart';

class Workstation {
  const Workstation({
    required this.id,
    required this.deskTopLeft,
  });

  final String id;

  /// Top-left corner of the desk sprite, matching `OfficeLayout.blockers`.
  final Vector2 deskTopLeft;

  /// Where an NPC should stand: on the chair tile in front of the desk.
  Vector2 get seatPosition =>
      Vector2(deskTopLeft.x + 32, deskTopLeft.y + 96);

  /// Centre of the desk's computer sprite, used for interaction proximity.
  Vector2 get computerPosition =>
      Vector2(deskTopLeft.x + 32, deskTopLeft.y + 32);

  static final List<Workstation> all = [
    Workstation(id: 'desk-1', deskTopLeft: Vector2(384, 320)),
    Workstation(id: 'desk-2', deskTopLeft: Vector2(544, 320)),
    Workstation(id: 'desk-3', deskTopLeft: Vector2(384, 512)),
  ];
}
