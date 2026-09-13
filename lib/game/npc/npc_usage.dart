/// Token accounting for one `askEmployee` call, when the underlying
/// provider reports it (OpenAI's chat completions response `usage` field).
/// Null fields mean the provider didn't report that number, not that usage
/// was zero.
class NpcUsage {
  const NpcUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
}

/// What an `NpcCommandHandler` resolves with: the employee's reply text,
/// plus usage accounting when the provider reports it.
class NpcCommandResult {
  const NpcCommandResult({required this.reply, this.usage});

  final String reply;
  final NpcUsage? usage;
}

/// Cumulative call/token counters for one AI employee (or, summed via
/// [operator +], for the whole roster) — backs [OfficeGame.usageFor] and
/// [OfficeGame.totalUsage]. Counts every `askEmployee` attempt, including
/// ones an automatic retry made, since each is a real call to the provider.
class NpcUsageSummary {
  const NpcUsageSummary({
    this.calls = 0,
    this.successes = 0,
    this.failures = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
  });

  final int calls;
  final int successes;
  final int failures;
  final int promptTokens;
  final int completionTokens;

  int get totalTokens => promptTokens + completionTokens;

  NpcUsageSummary operator +(NpcUsageSummary other) => NpcUsageSummary(
        calls: calls + other.calls,
        successes: successes + other.successes,
        failures: failures + other.failures,
        promptTokens: promptTokens + other.promptTokens,
        completionTokens: completionTokens + other.completionTokens,
      );
}
