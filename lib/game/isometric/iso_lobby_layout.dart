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

  static final FloorLayout floorLayout = FloorLayout(
    worldSize: _worldSize.clone(),
    blockers: [
      ...FloorLayout.perimeterWalls(_worldSize),
      const Rect.fromLTWH(400, 192, 160, 96),
      const Rect.fromLTWH(96, 320, 240, 224),
      const Rect.fromLTWH(624, 320, 240, 192),
    ],
    elevatorPosition: Vector2(480, 128),
  );

  static final List<IsoLobbyPlacement> placements = [
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/lobby_ground.png',
      worldFootPoint: Vector2(480, 704),
      screenSize: Vector2(960, 960),
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
      screenSize: Vector2(960, 960),
      layerOffset: 100000,
    ),
  ];
}
