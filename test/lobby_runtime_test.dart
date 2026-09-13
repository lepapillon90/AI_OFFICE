import 'package:ai_office/data/chat_message.dart';
import 'package:ai_office/data/multiplayer_channel.dart';
import 'package:ai_office/data/remote_player_state.dart';
import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/multiplayer/remote_player_component.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remote depth follows creation, movement, and lobby visibility',
      (tester) async {
    final channel = _PresenceChannel();
    final game = OfficeGame(multiplayer: channel);
    await _mount(tester, game);

    channel.emit(_state('existing', Floor.workspace, 540));
    await tester.runAsync(game.ready);
    final existing =
        game.world.children.whereType<RemotePlayerComponent>().single;
    expect(existing.priority, 3);

    channel.emit(_state('existing', Floor.lobby, 540));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.changeFloor(Floor.lobby));
    await tester.runAsync(game.ready);
    expect(existing.priority, 54000);

    channel.emit(_state('new', Floor.lobby, 180));
    await tester.runAsync(game.ready);
    final remote =
        game.world.children.whereType<RemotePlayerComponent>().single;
    expect(remote.priority, 18000);

    channel.emit(_state('new', Floor.lobby, 560));
    expect(remote.position, Vector2(580, 560));
    expect(remote.priority, 56000);

    channel.emit(_state('new', Floor.workspace, 560));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.changeFloor(Floor.workspace));
    await tester.runAsync(game.ready);
    expect(remote.priority, 3);
    channel.emit(_state('new', Floor.workspace, 180));
    expect(remote.priority, 3);
  });

  testWidgets('narrow lobby zoom applies on entry and resize', (tester) async {
    final game = OfficeGame();
    await _mount(tester, game);
    game.onGameResize(Vector2(390, 700));
    expect(game.camera.viewfinder.zoom, 1);

    await tester.runAsync(() => game.changeFloor(Floor.lobby));
    expect(game.camera.viewfinder.zoom, greaterThan(1));
    game.onGameResize(Vector2(1000, 700));
    expect(game.camera.viewfinder.zoom, 1);
    game.onGameResize(Vector2(390, 700));
    expect(game.camera.viewfinder.zoom, greaterThan(1));

    await tester.runAsync(() => game.changeFloor(Floor.workspace));
    expect(game.camera.viewfinder.zoom, 1);
  });

  testWidgets('desktop scroll zoom survives resize and lobby round trips',
      (tester) async {
    final game = OfficeGame();
    await _mount(tester, game);
    await tester.runAsync(() => game.changeFloor(Floor.lobby));
    game.onScroll(PointerScrollInfo.fromDetails(
      game,
      const PointerScrollEvent(scrollDelta: Offset(0, -1)),
    ));
    expect(game.camera.viewfinder.zoom, closeTo(1.1, .0001));
    game.onGameResize(Vector2(1200, 700));
    expect(game.camera.viewfinder.zoom, closeTo(1.1, .0001));
    game.onGameResize(Vector2(390, 700));
    expect(game.camera.viewfinder.zoom, greaterThan(1.1));
    game.onGameResize(Vector2(1000, 700));
    expect(game.camera.viewfinder.zoom, closeTo(1.1, .0001));
    await tester.runAsync(() => game.changeFloor(Floor.workspace));
    expect(game.camera.viewfinder.zoom, closeTo(1.1, .0001));
  });
}

Future<void> _mount(WidgetTester tester, OfficeGame game) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: GameWidget(game: game),
  ));
  await tester.runAsync(() async {
    await game.loaded;
    await game.ready();
  });
  await tester.pump();
}

RemotePlayerState _state(String userId, Floor floor, double y) =>
    RemotePlayerState(
      userId: userId,
      name: 'Remote coworker',
      role: 'Designer',
      statusLabel: 'Available',
      statusColorValue: 0xff00ff00,
      floorLevel: floor.level,
      x: 580,
      y: y,
    );

// Only the external presence transport is replaced; OfficeGame still creates
// and updates real remote components through its production callback.
class _PresenceChannel implements MultiplayerChannel {
  late void Function(Map<String, RemotePlayerState>) _onChanged;

  @override
  String get userId => 'local';

  @override
  Future<void> connect({
    required RemotePlayerState initial,
    required void Function(Map<String, RemotePlayerState>) onChanged,
    void Function(ChatMessage)? onChatMessage,
  }) async {
    _onChanged = onChanged;
  }

  void emit(RemotePlayerState state) => _onChanged({state.userId: state});

  @override
  void updateState(RemotePlayerState state, {bool force = false}) {}

  @override
  void sendChat(ChatMessage message) {}

  @override
  Future<void> disconnect() async {}
}
