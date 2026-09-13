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

  test('props fit the lobby composition and all foot points stay in bounds', () {
    final worldSize = IsoLobbyLayout.floorLayout.worldSize;

    for (final placement in IsoLobbyLayout.placements) {
      if (placement.assetPath.endsWith('lobby_ground.png') ||
          placement.assetPath.endsWith('foreground.png')) {
        continue;
      }

      expect(placement.screenSize.x, lessThanOrEqualTo(300));
      expect(placement.screenSize.y, lessThanOrEqualTo(300));
    }

    for (final placement in IsoLobbyLayout.placements) {
      expect(placement.worldFootPoint.x, inInclusiveRange(0, worldSize.x));
      expect(placement.worldFootPoint.y, inInclusiveRange(0, worldSize.y));
    }
  });
}
