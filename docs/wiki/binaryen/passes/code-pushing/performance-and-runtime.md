---
kind: concept
status: working
last_reviewed: 2026-04-13
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md
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
- Node-indexed boolean memo tables now use packed `BitSet` storage instead of
  raw `Array[Bool]`, which trims memory traffic across large-function repeated
  scans without changing the admitted rewrite surface.
- Shared `@ir.bitset_any(...)` and `@ir.bitset_overlaps(...)` helpers now do
  word-wise checks instead of repeated per-bit probes inside `code-pushing`
  conflict tests.
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
- The current valid-safe branch is still much slower again:
  - `4640.306 ms` vs `59.083 ms` pass time
  - `7306.772 ms` vs `396.894 ms` total time
- The newer writeback-valid suspicious-carrier gate improves correctness again
  without fixing runtime:
  - `4115.090 ms` vs `49.905 ms` pass time
  - `6590.874 ms` vs `316.897 ms` total time
- The current repeated-ladder-aware guard keeps the artifact valid while
  readmitting `Func 1948`:
  - `4413.342 ms` vs `51.978 ms` pass time
  - `7013.947 ms` vs `370.277 ms` total time
- The new live-carried lowering fix closes one correctness family without
  helping runtime yet:
  - `4611.631 ms` vs `55.247 ms` pass time
  - `7421.741 ms` vs `407.483 ms` total time
- A kept pushpoint-gating fast path now removes the largest unchanged-function
  scan without changing the changed-function set:
  - `928.451 ms` vs `55.628 ms` pass time
  - `3496.840 ms` vs `373.614 ms` total time
- The newer expression-position value-block traversal prune is parity-safe but
  not yet a runtime win on the real artifact:
  - `pass-fuzz-code-pushing-genvalid-20260410ac3` is still `10000/10000` with
    `0` mismatches
  - direct release `cmd.exe --code-pushing` replay on the debug artifact stayed
    above `5` minutes of CPU time and was aborted

## What Those Numbers Actually Mean

- The good news is that the pass is no longer trapped in the original
  multi-second-to-tens-of-seconds range on every reduced valid replay.
- The bad news is that even the best valid direct-artifact checkpoints are still
  an order of magnitude slower than Binaryen, not merely somewhat slower.
- The current branch does have a trustworthy direct runtime number again because
  artifact replay validates to completion.
- But traced serial replay now shows only two changed functions and no
  `skip-invalid-lower` lines, which means the current runtime gap is
  concentrated in an even smaller live set of large changed functions rather
  than in broad whole-module pass churn.
- A temporary experiment that also revalidated every changed lowered function
  against the module environment did not materially improve the valid replay
  story and stayed extremely slow, so the current kept slowdown is not explained
  solely by whole-function writeback validation.
- The hottest changed function in the latest serial trace is still `Func 1948`,
  which now spends about `100.1 ms` in `code-pushing` by itself before
  lower/writeback.
  That makes the next performance target much sharper than it was on the older
  four-function safe branch.
- The newer nested-block outer-read bailout did not materially change the live
  runtime picture.
  The refreshed direct compare at
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-4176613` still
  takes `4135.998 ms` in Starshine's pass vs `53.811 ms` in Binaryen, and the
  refreshed serial trace at `/tmp/code-pushing-trace-20260410aa.log` still
  shows the same two changed functions (`Func 148`, `Func 1948`) plus the same
  huge unchanged hotspot `Func 3665` at about `3337746 us`.
- The new same-tree correctness fix did not change that performance story much.
  The first live direct compare blocker moved later inside `Func 148`, but total
  runtime stayed in the same multi-second range, so the pass is still missing a
  large runtime win even after the repaired lowering family.
- One tempting cache micro-optimization has now been ruled out too. Memoizing
  the simple-owner payload, terminal-inner-owner payload, and ignorable
  non-void prefix-carrier checks made the live trace worse, pushing total
  `pass:code-pushing` from `4198179 us` to `4552778 us` and the unchanged
  hotspot `Func 3665` from `3139111 us` to `3466464 us`. That probe was
  reverted.
- A different fast path did pay off and is now kept. The pass now only runs the
  expensive sink / extract / push probes on actual pushpoint roots, and the two
  target-root-specific probes now resolve the target `if` / pushpoint before
  doing their non-void-prefix scans. On `/tmp/code-pushing-trace-perf1.log`,
  that drops traced `pass:code-pushing` from `4454138 us` to `934833 us` and
  cuts unchanged `Func 3665` from `3311870 us` to `858 us`, while preserving
  the same changed set (`Func 148`, `Func 1948`) and the same direct-compare
  frontier at `44251` / `44254`.

## Current Hot Spots

- The few real changed functions on the debug artifact, especially `Func 1948`.
- Prefix explicit-exit analysis in non-void or owner-sensitive regions.
- Repeated scans through real pushpoint-root dropped-carrier bodies while
  hunting extractable sets.
- Rebuilding summaries across repeated rewrite rounds in large functions.
- Traversal through nested carrier wrappers that do sit under pushpoint roots
  but still turn out not to contain a successful rewrite.

## Performance Work That Is Safe To Prioritize Only After Correctness

- Reduce the valid direct-artifact frontier from `func $127` downward so fewer
  large functions stay in the expensive changed set.
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
- Do not assume more carrier-shape memoization is helpful just because those
  helpers look hot on paper; the reverted probe showed the live unchanged
  hotspot can get worse.

## Honest Current Rule

- Correctness remains primary.
- Performance is still a live, documented secondary gap.
- The right near-term goal is:
  - keep valid direct-artifact output on the safe branch
  - keep the restored `Func 148` terminal-owner fence in place unless a
    refreshed Binaryen replay proves that function should still move
  - then optimize the actual remaining hot spots, starting with the real
    pushpoint-root work inside `Func 1948` and any later surviving changed
    functions after that fence
