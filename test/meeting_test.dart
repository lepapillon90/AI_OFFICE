import 'package:ai_office/game/activity/activity_event.dart';
import 'package:ai_office/game/interactions/meeting_room_interaction.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks a player near only inside the meeting room interaction radius',
      () {
    final interaction = MeetingRoomInteraction(position: Vector2(1150, 200));

    expect(interaction.isPlayerNearby(Vector2(1150, 220)), isTrue);
    expect(interaction.isPlayerNearby(Vector2(1150, 400)), isFalse);
  });

  test('E opens and escape closes the meeting popup near the meeting room',
      () {
    final game = OfficeGame.forTest(playerPosition: Vector2(1150, 220));

    expect(game.isMeetingRoomNearby, isTrue);
    game.handleInteractionKey(LogicalKeyboardKey.keyE);
    expect(game.isMeetingPopupOpen, isTrue);
    game.handleInteractionKey(LogicalKeyboardKey.escape);
    expect(game.isMeetingPopupOpen, isFalse);
  });

  test('blocks player movement while the meeting popup is open', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(1150, 220));

    game.handleInteractionKey(LogicalKeyboardKey.keyE);
    game.player.tryMove(Vector2(10, 0));

    expect(game.player.position, Vector2(1150, 220));
  });

  test('startMeeting flips participants to 회의 중 and logs the activity',
      () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final noah = game.employees.firstWhere((e) => e.name == '노아');
    final yuna = game.employees.firstWhere((e) => e.name == '유나');

    game.startMeeting([noah, yuna]);

    expect(game.isMeetingActive, isTrue);
    expect(game.meetingStartedAt, isNotNull);
    expect(
      game.meetingParticipants.map((e) => e.id),
      containsAll([noah.id, yuna.id]),
    );
    final updatedNoah = game.employees.firstWhere((e) => e.id == noah.id);
    expect(updatedNoah.status, NpcStatus.meeting);

    expect(game.activityLog, hasLength(1));
    expect(game.activityLog.first.type, ActivityType.meeting);
    expect(game.activityLog.first.message, contains('노아'));
    expect(game.activityLog.first.message, contains('유나'));
  });

  test('endMeeting restores each participant\'s prior status and logs it',
      () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final noah = game.employees.firstWhere((e) => e.name == '노아');
    game.updateEmployee(noah.copyWith(status: NpcStatus.working));
    final beforeMeeting = game.employees.firstWhere((e) => e.id == noah.id);
    expect(beforeMeeting.status, NpcStatus.working);

    game.startMeeting([beforeMeeting]);
    expect(
      game.employees.firstWhere((e) => e.id == noah.id).status,
      NpcStatus.meeting,
    );

    game.endMeeting();

    expect(game.isMeetingActive, isFalse);
    expect(game.meetingParticipants, isEmpty);
    expect(
      game.employees.firstWhere((e) => e.id == noah.id).status,
      NpcStatus.working,
    );
    expect(game.activityLog, hasLength(3)); // roster edit + start + end
    // activityLog is most-recent-first, so the "end meeting" entry is at
    // index 0, not .last.
    expect(game.activityLog.first.type, ActivityType.meeting);
    expect(game.activityLog.first.message, contains('종료'));
  });

  test('startMeeting is a no-op with no participants or while already active',
      () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final noah = game.employees.firstWhere((e) => e.name == '노아');

    game.startMeeting([]);
    expect(game.isMeetingActive, isFalse);

    game.startMeeting([noah]);
    expect(game.isMeetingActive, isTrue);

    final yuna = game.employees.firstWhere((e) => e.name == '유나');
    game.startMeeting([yuna]); // already in a meeting — ignored
    expect(game.meetingParticipants.map((e) => e.id), [noah.id]);
  });

  test('endMeeting is a no-op when no meeting is running', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));

    game.endMeeting();

    expect(game.activityLog, isEmpty);
  });
}
