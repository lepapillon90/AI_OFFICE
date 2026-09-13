/// Thrown by an `NpcCommandHandler` when the backend rejects a call for a
/// reason the UI should explain distinctly (e.g. the ask-employee Edge
/// Function's per-company rate limit — see docs/PHASE7_OPS_REVIEW.md)
/// rather than folding it into the generic retry-then-error message.
/// Deliberately provider-agnostic (no Supabase types) so OfficeGame, which
/// works standalone in tests, doesn't need to import anything
/// Supabase-specific to special-case this.
class AskEmployeeRateLimitException implements Exception {
  const AskEmployeeRateLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}
