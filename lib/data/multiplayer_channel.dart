import 'package:ai_office/data/remote_player_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A Supabase Realtime Presence channel scoped to one company, used to
/// share each signed-in user's position/profile with everyone else
/// currently in the same office.
class MultiplayerChannel {
  MultiplayerChannel({
    required SupabaseClient client,
    required String companyId,
    required this.userId,
  })  : _client = client,
        _companyId = companyId;

  final SupabaseClient _client;
  final String _companyId;
  final String userId;

  RealtimeChannel? _channel;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const _minInterval = Duration(milliseconds: 150);

  /// Joins the channel, tracking [initial] as this user's starting state,
  /// and calls [onChanged] with every other user's latest state whenever
  /// the shared presence state changes (join/leave/update).
  Future<void> connect({
    required RemotePlayerState initial,
    required void Function(Map<String, RemotePlayerState>) onChanged,
  }) async {
    final channel = _client.channel(
      'office:company:$_companyId',
      opts: RealtimeChannelConfig(key: userId),
    );
    _channel = channel;

    void emit() {
      final states = <String, RemotePlayerState>{};
      for (final single in channel.presenceState()) {
        for (final presence in single.presences) {
          final state = RemotePlayerState.fromJson(presence.payload);
          if (state != null && state.userId != userId) {
            states[state.userId] = state;
          }
        }
      }
      onChanged(states);
    }

    channel
      ..onPresenceSync((_) => emit())
      ..onPresenceJoin((_) => emit())
      ..onPresenceLeave((_) => emit());

    final subscribed = <void>[];
    channel.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await channel.track(initial.toJson());
        subscribed.add(null);
      }
    });
    _lastSentAt = DateTime.now();

    // Give the subscribe handshake a moment; the game can still proceed
    // (and will emit again) even if this races ahead.
    for (var i = 0; i < 20 && subscribed.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Broadcasts [state] to the rest of the company, throttled to at most
  /// once per [_minInterval] unless [force] is set (e.g. on a floor
  /// change, where other clients should update immediately).
  void updateState(RemotePlayerState state, {bool force = false}) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_lastSentAt) < _minInterval) {
      return;
    }
    _lastSentAt = now;
    channel.track(state.toJson());
  }

  Future<void> disconnect() async {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    _channel = null;
    await channel.untrack();
    await _client.removeChannel(channel);
  }
}
