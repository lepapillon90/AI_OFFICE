import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/player/office_player.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

// The lobby's collision geometry is proportionally scaled from a legacy
// 15x11/960x704 layout up to the current 24x16/1536x1024 grid (see
// IsoLobbyLayout's doc comment) — these tests derive their expected
// positions via IsoLobbyLayout.scaleX/scaleY instead of hardcoding
// magic numbers, so they stay correct if that base spec changes again.
Vector2 _scaled(double x, double y) =>
    Vector2(x * IsoLobbyLayout.scaleX, y * IsoLobbyLayout.scaleY);

void main() {
  test('arrival cannot cross the stepped upper wall into the exterior', () {
    final start = _scaled(480, 144);
    final player = OfficePlayer(
      position: start.clone(),
      floorLayout: IsoLobbyLayout.floorLayout,
    );

    player.tryMove(Vector2(-380 * IsoLobbyLayout.scaleX, 0));
    expect(player.position, start);
    player.tryMove(Vector2(380 * IsoLobbyLayout.scaleX, 0));
    expect(player.position, start);
    player.tryMove(Vector2(-60 * IsoLobbyLayout.scaleX, 0));
    expect(player.position, Vector2(420 * IsoLobbyLayout.scaleX, start.y));
  });

  test('planter base blocks crossing but leaves the front aisle open', () {
    final player = OfficePlayer(
      position: _scaled(368, 432),
      floorLayout: IsoLobbyLayout.floorLayout,
    );

    player.tryMove(Vector2(112 * IsoLobbyLayout.scaleX, 0));
    expect(player.position, _scaled(368, 432));
    player.position = _scaled(400, 500);
    player.tryMove(Vector2(160 * IsoLobbyLayout.scaleX, 0));
    expect(player.position, _scaled(560, 500));
  });

  test('lounge seats and table block walking across their base', () {
    final player = OfficePlayer(
      position: _scaled(580, 560),
      // Isolate the prop from exterior walls that overlap this artwork.
      floorLayout: FloorLayout(
        worldSize: IsoLobbyLayout.floorLayout.worldSize,
        blockers: IsoLobbyLayout.furnitureBlockers,
        elevatorPosition: IsoLobbyLayout.floorLayout.elevatorPosition,
      ),
    );

    player.tryMove(Vector2(164 * IsoLobbyLayout.scaleX, 0));
    expect(player.position, _scaled(580, 560));
  });

  test('the lobby arrival point is inside its world', () {
    final layout = IsoLobbyLayout.floorLayout;
    final arrival = layout.arrivalPosition;

    expect(arrival.x, inInclusiveRange(0, layout.worldSize.x));
    expect(arrival.y, inInclusiveRange(0, layout.worldSize.y));
  });

  test('the layered artwork includes the floor and foreground anchors', () {
    final paths = IsoLobbyLayout.placements.map((item) => item.assetPath);

    expect(paths, contains('office_1f/v3/floor/main_lobby/base.png'));
    expect(paths, contains('office_1f/v3/floor/cafe/base.png'));
    expect(paths, contains('office_1f/v3/floor/store/base.png'));
    expect(paths, contains('office_1f/v3/floor/shallow_water/base.png'));
    expect(paths, contains('office_1f/isometric/reception.png'));
    expect(paths, contains('office_1f/isometric/foreground.png'));
  });

  test('layers and props fit the lobby composition', () {
    final worldSize = IsoLobbyLayout.floorLayout.worldSize;
    final placements = IsoLobbyLayout.placements;
    final ground = placements.firstWhere(
      (item) => item.assetPath.startsWith('office_1f/v3/floor/'),
    );
    final foreground = placements.firstWhere(
      (item) => item.assetPath.endsWith('foreground.png'),
    );

    expect(ground.screenSize, Vector2.all(64));
    expect(
      placements
          .where((item) => item.assetPath.startsWith('office_1f/v3/floor/'))
          .length,
      // 24 columns x 16 rows, per IsoLobbyLayout's base grid spec.
      24 * 16,
    );
    expect(foreground.screenSize.x, worldSize.x);
    expect(foreground.screenSize.y, lessThanOrEqualTo(240));

    const propNames = ['reception', 'cafe', 'store', 'lounge', 'planters'];
    for (final name in propNames) {
      final placement = placements.firstWhere(
        (item) => item.assetPath.endsWith('$name.png'),
      );

      expect(placement.screenSize.x, placement.screenSize.y);
      expect(placement.screenSize.x, lessThanOrEqualTo(300));
      expect(placement.screenSize.y, lessThanOrEqualTo(300));
    }

    for (final placement in placements) {
      expect(placement.worldFootPoint.x, inInclusiveRange(0, worldSize.x));
      expect(placement.worldFootPoint.y, inInclusiveRange(0, worldSize.y));
    }
  });
}
