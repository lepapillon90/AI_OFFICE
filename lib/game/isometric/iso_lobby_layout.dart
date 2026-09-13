import 'dart:ui';

import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:flame/components.dart';

/// A visual layer positioned at its foot point in the isometric lobby world.
class IsoLobbyPlacement {
  const IsoLobbyPlacement({
    required this.assetPath,
    required this.worldFootPoint,
    required this.screenSize,
    this.layerOffset = 0,
  });

  final String assetPath;
  final Vector2 worldFootPoint;
  final Vector2 screenSize;
  final int layerOffset;
}

/// Collision and layered-art configuration for the first-floor lobby.
abstract final class IsoLobbyLayout {
  static final Vector2 _worldSize = Vector2(960, 704);

  // Exterior cutouts and their wall faces follow the stepped floor artwork.
  // Fill the exterior as well as the face so a large move cannot land outside.
  static const List<Rect> wallBlockers = [
    Rect.fromLTWH(0, 0, 960, 88),
    Rect.fromLTWH(0, 88, 352, 68),
    Rect.fromLTWH(608, 88, 352, 68),
    Rect.fromLTWH(0, 156, 256, 68),
    Rect.fromLTWH(704, 156, 256, 68),
    Rect.fromLTWH(0, 224, 36, 208),
    Rect.fromLTWH(924, 224, 36, 208),
    Rect.fromLTWH(0, 432, 240, 272),
    Rect.fromLTWH(720, 432, 240, 272),
    Rect.fromLTWH(240, 512, 96, 192),
    Rect.fromLTWH(624, 512, 96, 192),
    Rect.fromLTWH(336, 592, 288, 112),
  ];

  // Bases of the props, excluding their tall canopies and transparent padding.
  static const List<Rect> furnitureBlockers = [
    Rect.fromLTWH(400, 192, 160, 96),
    Rect.fromLTWH(96, 320, 240, 224),
    Rect.fromLTWH(624, 320, 240, 192),
    Rect.fromLTWH(400, 392, 160, 88), // Planter bed and surrounding pots.
    Rect.fromLTWH(634, 520, 220, 104), // Lounge seats and coffee table.
  ];

  static final FloorLayout floorLayout = FloorLayout(
    worldSize: _worldSize.clone(),
    blockers: [
      ...wallBlockers,
      ...furnitureBlockers,
    ],
    elevatorPosition: Vector2(480, 80),
  );

  static final List<IsoLobbyPlacement> placements = [
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/lobby_ground.png',
      worldFootPoint: Vector2(480, 704),
      screenSize: Vector2(960, 704),
      layerOffset: -100000,
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/reception.png',
      worldFootPoint: Vector2(480, 288),
      screenSize: Vector2(240, 240),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/cafe.png',
      worldFootPoint: Vector2(216, 544),
      screenSize: Vector2(300, 300),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/store.png',
      worldFootPoint: Vector2(744, 512),
      screenSize: Vector2(280, 280),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/lounge.png',
      worldFootPoint: Vector2(744, 640),
      screenSize: Vector2(240, 240),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/planters.png',
      worldFootPoint: Vector2(480, 480),
      screenSize: Vector2(220, 220),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/foreground.png',
      worldFootPoint: Vector2(480, 704),
      screenSize: Vector2(960, 240),
      layerOffset: 100000,
    ),
  ];
}
