import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/player/office_player.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arrival cannot cross the top floor boundary', () {
    final start = Vector2(768, 192);
    final player = OfficePlayer(
      position: start.clone(),
      floorLayout: IsoLobbyLayout.floorLayout,
    );

    player.tryMove(Vector2(0, -180));
    expect(player.position, start);
    player.tryMove(Vector2(-64, 0));
    expect(player.position, Vector2(704, 192));
  });

  test('empty foundation has no furniture collision areas', () {
    final player = OfficePlayer(
      position: Vector2(640, 640),
      floorLayout: IsoLobbyLayout.floorLayout,
    );

    player.tryMove(Vector2(128, 0));
    expect(player.position, Vector2(768, 640));
  });

  test('the lobby arrival point is inside its world', () {
    final layout = IsoLobbyLayout.floorLayout;
    final arrival = layout.arrivalPosition;

    expect(arrival.x, inInclusiveRange(0, layout.worldSize.x));
    expect(arrival.y, inInclusiveRange(0, layout.worldSize.y));
  });

  test('the foundation includes only floor tile assets', () {
    final paths = IsoLobbyLayout.placements.map((item) => item.assetPath);

    expect(paths, contains('office_1f/v3/floor/main_lobby/base.png'));
    expect(paths, contains('office_1f/v3/floor/cafe/base.png'));
    expect(paths, contains('office_1f/v3/floor/store/base.png'));
    expect(paths, contains('office_1f/v3/floor/shallow_water/base.png'));
    expect(paths, everyElement(startsWith('office_1f/v3/floor/')));
  });

  test('floor tiles fill the 24 by 16 foundation', () {
    final worldSize = IsoLobbyLayout.floorLayout.worldSize;
    final placements = IsoLobbyLayout.placements;
    final ground = placements.firstWhere(
      (item) => item.assetPath.startsWith('office_1f/v3/floor/'),
    );
    expect(ground.screenSize, Vector2.all(64));
    expect(
      placements
          .where((item) => item.assetPath.startsWith('office_1f/v3/floor/'))
          .length,
      // 24 columns x 16 rows, per IsoLobbyLayout's base grid spec.
      24 * 16,
    );
    for (final placement in placements) {
      expect(placement.worldFootPoint.x, inInclusiveRange(0, worldSize.x));
      expect(placement.worldFootPoint.y, inInclusiveRange(0, worldSize.y));
    }
  });
}
