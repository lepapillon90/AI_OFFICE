import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the lobby arrival point is inside its world', () {
    final layout = IsoLobbyLayout.floorLayout;
    final arrival = layout.arrivalPosition;

    expect(arrival.x, inInclusiveRange(0, layout.worldSize.x));
    expect(arrival.y, inInclusiveRange(0, layout.worldSize.y));
  });

  test('the layered artwork includes the floor and foreground anchors', () {
    final paths = IsoLobbyLayout.placements.map((item) => item.assetPath);

    expect(paths, contains('office_1f/isometric/lobby_ground.png'));
    expect(paths, contains('office_1f/isometric/reception.png'));
    expect(paths, contains('office_1f/isometric/foreground.png'));
  });

  test('layers and props fit the lobby composition', () {
    final worldSize = IsoLobbyLayout.floorLayout.worldSize;
    final placements = IsoLobbyLayout.placements;
    final ground = placements.firstWhere(
      (item) => item.assetPath.endsWith('lobby_ground.png'),
    );
    final foreground = placements.firstWhere(
      (item) => item.assetPath.endsWith('foreground.png'),
    );

    expect(ground.screenSize, worldSize);
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
