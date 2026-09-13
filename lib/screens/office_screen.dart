import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/computer_popup.dart';
import 'package:ai_office/screens/elevator_popup.dart';
import 'package:ai_office/screens/profile_card.dart';
import 'package:ai_office/screens/roster_editor_dialog.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Hosts the full-screen Flame office experience.
class OfficeScreen extends StatelessWidget {
  const OfficeScreen({
    this.game,
    this.onLogout,
    this.canManageRoster = true,
    super.key,
  });

  final OfficeGame? game;

  /// Shown as a logout button in the top bar when provided (i.e. when
  /// hosted behind Supabase auth).
  final VoidCallback? onLogout;

  /// Whether the signed-in user may open the "직원 정보 관리" roster panel —
  /// true by default so callers without auth (tests, the no-arg
  /// constructor) keep today's open-by-default behavior. Hosts behind
  /// Supabase auth should pass the user's actual company role here.
  final bool canManageRoster;

  @override
  Widget build(BuildContext context) {
    final officeGame = game ?? OfficeGame();

    return Scaffold(
      body: AnimatedBuilder(
        animation: officeGame,
        builder: (context, _) => Stack(
          children: [
            GameWidget(game: officeGame),
            Positioned(
              top: 16,
              left: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    '${officeGame.currentFloor.level}층 · ${officeGame.currentFloor.displayName}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  Tooltip(
                    message: canManageRoster
                        ? '직원 정보 관리'
                        : '직원 정보 관리 (대표·인사관리자 전용)',
                    child: IconButton.filled(
                      onPressed: canManageRoster
                          ? () => showDialog<void>(
                                context: context,
                                builder: (_) =>
                                    RosterEditorDialog(game: officeGame),
                              )
                          : null,
                      icon: const Icon(Icons.badge_outlined),
                    ),
                  ),
                  if (onLogout != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '로그아웃',
                      child: IconButton.filled(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (officeGame.isComputerNearby && !officeGame.isComputerPopupOpen)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xCC000000),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        '[E] ${officeGame.nearbyEmployee!.name} 컴퓨터 사용',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            if (officeGame.isElevatorNearby &&
                !officeGame.isElevatorPopupOpen &&
                !officeGame.isComputerPopupOpen)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xCC000000),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        '[E] 엘리베이터 이용',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            if (officeGame.isComputerPopupOpen)
              ComputerPopup(
                employee: officeGame.nearbyEmployee!,
                onClose: officeGame.closeComputerPopup,
              ),
            if (officeGame.isElevatorPopupOpen) ElevatorPopup(game: officeGame),
            if (officeGame.isProfileCardOpen) ProfileCard(game: officeGame),
          ],
        ),
      ),
    );
  }
}
