import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NpcUsage.estimatedCostUsd applies gpt-4o-mini pricing per call', () {
    const usage = NpcUsage(promptTokens: 1000000, completionTokens: 1000000);
    // $0.15/1M prompt + $0.60/1M completion, at exactly 1M each.
    expect(usage.estimatedCostUsd, closeTo(0.75, 0.0001));
  });

  test('NpcUsage.estimatedCostUsd treats missing token counts as zero', () {
    const usage = NpcUsage();
    expect(usage.estimatedCostUsd, 0);
  });

  test('NpcUsageSummary.estimatedCostUsd sums across accumulated calls', () {
    const summary = NpcUsageSummary(
      calls: 2,
      successes: 2,
      promptTokens: 2000000,
      completionTokens: 1000000,
    );
    // 2M prompt tokens * $0.15/1M + 1M completion tokens * $0.60/1M
    expect(summary.estimatedCostUsd, closeTo(0.3 + 0.6, 0.0001));
  });

  test('formatUsd renders a \$-prefixed 4-decimal label', () {
    expect(formatUsd(0.0012345), '\$0.0012');
    expect(formatUsd(0), '\$0.0000');
  });
}
