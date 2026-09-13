/// gpt-4o-mini's per-token USD pricing (the only model `ask-employee`
/// calls — see `supabase/functions/ask-employee/index.ts`'s
/// `OPENAI_MODEL`), as published on OpenAI's pricing page when this was
/// written. **Verify current rates if this matters for real budgeting** —
/// providers change prices over time and this isn't kept in sync
/// automatically.
const _kUsdPerPromptToken = 0.15 / 1000000;
const _kUsdPerCompletionToken = 0.60 / 1000000;

/// "$0.0012"-style label for a USD cost estimate — no `intl` dependency in
/// this project, so this is a plain manual format (4 decimals, since these
/// amounts are almost always sub-cent).
String formatUsd(double amountUsd) => '\$${amountUsd.toStringAsFixed(4)}';

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

  /// Rough USD cost estimate for this one call — see [_kUsdPerPromptToken].
  double get estimatedCostUsd =>
      (promptTokens ?? 0) * _kUsdPerPromptToken +
      (completionTokens ?? 0) * _kUsdPerCompletionToken;
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

  /// Rough cumulative USD cost estimate — see [_kUsdPerPromptToken].
  double get estimatedCostUsd =>
      promptTokens * _kUsdPerPromptToken +
      completionTokens * _kUsdPerCompletionToken;

  NpcUsageSummary operator +(NpcUsageSummary other) => NpcUsageSummary(
        calls: calls + other.calls,
        successes: successes + other.successes,
        failures: failures + other.failures,
        promptTokens: promptTokens + other.promptTokens,
        completionTokens: completionTokens + other.completionTokens,
      );
}
