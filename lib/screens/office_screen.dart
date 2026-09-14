import 'package:ai_office/data/company_repository.dart';
import 'package:ai_office/data/server_lock_repository.dart';
import 'package:ai_office/data/slack_integration_repository.dart';
import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/activity_panel.dart';
import 'package:ai_office/screens/admin_panel.dart';
import 'package:ai_office/screens/board_panel.dart';
import 'package:ai_office/screens/chat_panel.dart';
import 'package:ai_office/screens/computer_popup.dart';
import 'package:ai_office/screens/elevator_popup.dart';
import 'package:ai_office/screens/meeting_panel.dart';
import 'package:ai_office/screens/profile_card.dart';
import 'package:ai_office/screens/roster_editor_dialog.dart';
import 'package:ai_office/screens/server_lock_dialog.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Hosts the full-screen Flame office experience.
class OfficeScreen extends StatefulWidget {
  const OfficeScreen({
    this.game,
    this.onLogout,
    this.canManageRoster = true,
    this.canManageMembers = true,
    this.companyId,
    this.repository,
    this.slackRepository,
    this.serverLockRepository,
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

  /// Whether the signed-in user may open the admin screen (member list,
  /// role changes) — owner only. Same default-true-for-tests rationale as
  /// [canManageRoster].
  final bool canManageMembers;

  /// The signed-in user's company id and a repository to manage it — both
  /// null for callers without auth (tests, the no-arg constructor), which
  /// hides the roster panel's invite section since there's no company to
  /// invite anyone into.
  final String? companyId;
  final CompanyRepository? repository;

  /// Manages the company's Slack webhook integration — null for callers
  /// without auth (tests), which hides the admin screen's Slack section.
  final SlackIntegrationRepository? slackRepository;

  /// Manages the company's server-machine password — null for callers
  /// without auth (tests), which hides the admin screen's server lock
  /// section.
  final ServerLockRepository? serverLockRepository;

  @override
  State<OfficeScreen> createState() => _OfficeScreenState();
}

class _OfficeScreenState extends State<OfficeScreen> {
  late final OfficeGame _officeGame = widget.game ?? OfficeGame();

  // GameWidget only forwards keyboard events to the game while this node
  // has focus. A chat/roster text field taking focus (to type into it) and
  // then leaving the tree (panel closed) doesn't hand focus back on its
  // own, which would otherwise permanently strand WASD/E/Enter with
  // nowhere to go. So: whenever nothing overlays the game, claim focus.
  final _gameFocusNode = FocusNode(debugLabel: 'OfficeGame');

  // Purely UI overlays (no game-logic interaction needed), unlike the
  // computer/elevator/profile/chat popups which OfficeGame itself tracks.
  bool _isActivityPanelOpen = false;
  bool _isBoardPanelOpen = false;
  bool _isAdminPanelOpen = false;

  bool get _anyOverlayOpen =>
      _officeGame.isComputerPopupOpen ||
      _officeGame.isElevatorPopupOpen ||
      _officeGame.isMeetingPopupOpen ||
      _officeGame.isServerLockDialogOpen ||
      _officeGame.isProfileCardOpen ||
      _officeGame.isChatOpen ||
      _isActivityPanelOpen ||
      _isBoardPanelOpen ||
      _isAdminPanelOpen;

  void _reclaimGameFocusIfIdle() {
    if (_anyOverlayOpen || _gameFocusNode.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_anyOverlayOpen) {
        _gameFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _gameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final officeGame = _officeGame;
    _reclaimGameFocusIfIdle();

    return Scaffold(
      body: AnimatedBuilder(
        animation: officeGame,
        builder: (context, _) {
          _reclaimGameFocusIfIdle();
          return Stack(
            children: [
              GameWidget(game: officeGame, focusNode: _gameFocusNode),
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
                      message: widget.canManageRoster
                          ? '직원 정보 관리'
                          : '직원 정보 관리 (대표·인사관리자 전용)',
                      child: IconButton.filled(
                        onPressed: widget.canManageRoster
                            ? () => showDialog<void>(
                                  context: context,
                                  builder: (_) => RosterEditorDialog(
                                    game: officeGame,
                                    companyId: widget.companyId,
                                    repository: widget.repository,
                                    canGrantHrManager: widget.canManageMembers,
                                  ),
                                )
                            : null,
                        icon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: officeGame.isChatOpen ? '채팅 닫기' : '공간 채팅',
                      child: IconButton.filled(
                        onPressed: officeGame.isChatOpen
                            ? officeGame.closeChat
                            : officeGame.openChat,
                        icon: const Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '업무 보드',
                      child: IconButton.filled(
                        onPressed: () => setState(() => _isBoardPanelOpen = true),
                        icon: const Icon(Icons.view_kanban_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '활동 기록',
                      child: Badge(
                        isLabelVisible: officeGame.unreadActivityCount > 0,
                        label: Text('${officeGame.unreadActivityCount}'),
                        child: IconButton.filled(
                          onPressed: () {
                            officeGame.markActivityRead();
                            setState(() => _isActivityPanelOpen = true);
                          },
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                      ),
                    ),
                    if (widget.canManageMembers) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: '관리자 화면',
                        child: IconButton.filled(
                          onPressed: () => setState(() => _isAdminPanelOpen = true),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                        ),
                      ),
                    ],
                    if (widget.onLogout != null) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: '로그아웃',
                        child: IconButton.filled(
                          onPressed: widget.onLogout,
                          icon: const Icon(Icons.logout),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (officeGame.isComputerNearby &&
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
              if (officeGame.isMeetingRoomNearby &&
                  !officeGame.isMeetingPopupOpen &&
                  !officeGame.isComputerPopupOpen &&
                  !officeGame.isElevatorPopupOpen)
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
                          officeGame.isMeetingActive
                              ? '[E] 회의 참여 현황 보기'
                              : '[E] 회의실 이용',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              // Explicit keys below: these are conditional siblings in the
              // same Stack, so whether one appears/disappears shifts every
              // later one's *index* in this children list. Flutter's
              // default (keyless) reconciliation matches by index, not
              // identity — without a stable key, e.g. closing
              // ComputerPopup while ChatPanel stays open would slide
              // ChatPanel one slot earlier and get its State wrongly
              // disposed/recreated (losing scroll position, the selected
              // room, everything), even though ChatPanel itself never
              // closed. A key makes each one keep its own State regardless
              // of what else opens or closes around it.
              if (officeGame.isComputerPopupOpen)
                ComputerPopup(
                  key: const ValueKey('computer-popup'),
                  employee: officeGame.nearbyEmployee!,
                  game: officeGame,
                  onClose: officeGame.closeComputerPopup,
                ),
              if (officeGame.isElevatorPopupOpen)
                ElevatorPopup(key: const ValueKey('elevator-popup'), game: officeGame),
              if (officeGame.isMeetingPopupOpen)
                MeetingPanel(
                  key: const ValueKey('meeting-popup'),
                  game: officeGame,
                  onClose: officeGame.closeMeetingPopup,
                ),
              if (officeGame.isServerLockDialogOpen)
                ServerLockDialog(
                  key: const ValueKey('server-lock-dialog'),
                  game: officeGame,
                  onClose: officeGame.closeServerLockDialog,
                ),
              if (officeGame.isProfileCardOpen)
                ProfileCard(key: const ValueKey('profile-card'), game: officeGame),
              if (officeGame.isChatOpen)
                ChatPanel(key: const ValueKey('chat-panel'), game: officeGame),
              if (_isActivityPanelOpen)
                ActivityPanel(
                  key: const ValueKey('activity-panel'),
                  game: officeGame,
                  onClose: () => setState(() => _isActivityPanelOpen = false),
                ),
              if (_isBoardPanelOpen)
                BoardPanel(
                  key: const ValueKey('board-panel'),
                  game: officeGame,
                  onClose: () => setState(() => _isBoardPanelOpen = false),
                ),
              if (_isAdminPanelOpen && widget.companyId != null && widget.repository != null)
                AdminPanel(
                  key: const ValueKey('admin-panel'),
                  game: officeGame,
                  companyId: widget.companyId!,
                  repository: widget.repository!,
                  slackRepository: widget.slackRepository,
                  serverLockRepository: widget.serverLockRepository,
                  onClose: () => setState(() => _isAdminPanelOpen = false),
                ),
            ],
          );
        },
      ),
    );
  }
}
