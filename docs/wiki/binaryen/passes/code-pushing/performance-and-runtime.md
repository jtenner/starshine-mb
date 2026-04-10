---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/code_pushing.mbt
related:
  - ./index.md
  - ./parity.md
  - ./artifact-frontiers.md
  - ./validation-and-fuzzing.md
---

# `code-pushing` Performance And Runtime

## Why Performance Matters Here

- This pass should not be inherently expensive.
- Binaryen's own algorithm is a local backward scan over block lists plus one-arm
  `if` sinking.
- The repo rule in [`AGENTS.md`](../../../../../AGENTS.md) is to target either
  `< 1s` wall time or at least `>= 50%` of Binaryen where possible.
- `code-pushing` is still nowhere near that bar on the real artifact, so runtime
  remains a real secondary problem even though correctness is still first.

## Why Starshine Has Been Slower

- Starshine pays costs Binaryen does not pay in the same form:
  - HOT lift and lower around the pass
  - owner-aware explicit-exit analysis for non-void carriers
  - repeated summary rebuilds after each successful mutation
  - extra dropped-carrier extraction scans that only exist because HOT lift can
    hide the relevant shape inside result carriers
- Several earlier broad guard implementations were also simply too expensive,
  especially when they walked larger non-void prefixes repeatedly.

## Existing Runtime Defenses In The Implementation

- `cp_func_has_candidate_shape` fast-skips obviously irrelevant functions.
- `cp_prepare_func_static_scan` and `cp_new_traversal_gate_scan` avoid richer
  work when no useful candidate region exists.
- `CpSummaryCache` avoids recomputing full subtree summaries every time a segment
  scan crosses the same node.
- The pass mutates HOT regions in place instead of rebuilding wrapper AST shells.
- Several unsafe broad relaxations have also been rolled back, which matters for
  performance as well as correctness.

## Useful Historical Timing Checkpoints

- Early broad non-void experiments were extremely slow:
  - around `12662.937 ms` Starshine pass time vs about `54 ms` for Binaryen
- A narrower reachable-prefix rule improved one replay to:
  - `9907.976 ms` vs `54.208 ms`
- The self-contained dropped-owner refinement improved another valid replay to:
  - `9754.809 ms` vs `54.208 ms`
- A traversal expansion through `Drop`-wrapped owners later regressed badly:
  - `16579.566 ms` vs `49.523 ms`
- After more focused parity work and carrier reductions, later valid replay
  checkpoints improved substantially:
  - `4869.181 ms` vs `52.840 ms`
  - `1208.159 ms` vs `55.135 ms`
  - `808.760 ms` vs `51.461 ms`
  - `898.592 ms` vs `61.162 ms`

## What Those Numbers Actually Mean

- The good news is that the pass is no longer trapped in the original
  multi-second-to-tens-of-seconds range on every reduced valid replay.
- The bad news is that even the best valid direct-artifact checkpoints are still
  an order of magnitude slower than Binaryen, not merely somewhat slower.
- The current branch does not even have a new trustworthy direct runtime number on
  the real artifact because the output is invalid before compare can finish.

## Current Hot Spots

- Prefix explicit-exit analysis in non-void or owner-sensitive regions.
- Repeated scans through dropped-carrier bodies while hunting extractable sets.
- Rebuilding summaries across repeated rewrite rounds in large functions.
- Traversal through nested carrier wrappers that turn out not to contain a
  successful rewrite after all.

## Performance Work That Is Safe To Prioritize Only After Correctness

- Cache more prefix explicit-exit facts so repeated scans do not walk the same
  owner trees on every candidate.
- Narrow dropped-carrier probes earlier with cheaper shape tests before building
  deeper safety summaries.
- Reduce the number of full rewrite rounds required in functions where only one
  late carrier family is still live.
- Measure whether some summary recomputation can be made more incremental after a
  small local rewrite.

## Performance Work That Should Not Come First

- Do not remove correctness fences just to regain speed.
- Do not throw away HOT-lowering proofs because the fuzz lane is cheaper to run.
- Do not treat the older `808 ms` or `898 ms` checkpoints as final improvement
  proof while the current branch is still invalid on the real artifact.

## Honest Current Rule

- Correctness remains primary.
- Performance is still a live, documented secondary gap.
- The right near-term goal is:
  - restore valid direct-artifact output
  - close the remaining correctness frontier
  - then remeasure on the real artifact and only optimize the actual remaining
    hot spots
