---
kind: comparison
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/ir/hot_lower_live_repro_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
  - ../../../../../scripts/pass-fuzz-compare.ts
  - ../../../../../scripts/self-optimize-compare.ts
related:
  - ./index.md
  - ./artifact-frontiers.md
  - ./validation-and-fuzzing.md
  - ./performance-and-runtime.md
---

# `code-pushing` Binaryen Parity

## Durable Conclusions

- Binaryen parity for `code-pushing` is primarily about local motion around
  conditional push points, not about generic local cleanup.
- The direct in-tree Starshine port already matches several core Binaryen
  behaviors:
  - SFA-only candidate selection
  - order-preserving same-region pushes
  - one-arm `if` sinking with the terminal-opposite-arm later-read exception
  - conservative effect and alias barriers
- Starshine also now matches several artifact-shaped families that Binaryen
  realizes but HOT lift made harder to express directly:
  - alias extraction out of dropped carriers
  - a narrow call-fed dropped-carrier extraction
  - safe explicit-exit-prefix variants of that extraction
  - one nested dropped-carrier wrapper variant
  - a narrower terminal-inner-owner carrier family
- Reduced compare-pass parity is green on the named `gen-valid` lane, but whole
  debug-artifact parity is still not signed off.
- Performance is still far behind Binaryen and remains a secondary, still-open
  problem even when a reduced correctness slice is green.

## Current In-Tree Status

- The implementation lives in
  [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt).
- Focused pass coverage lives in
  [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt).
- HOT-lowering proofs for the kept carrier rewrites live in
  [`../../../../../src/ir/hot_lower_live_repro_test.mbt`](../../../../../src/ir/hot_lower_live_repro_test.mbt).
- Native CLI and artifact-validation coverage live in
  [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt).
- Differential pass fuzzing is wired through
  [`../../../../../scripts/pass-fuzz-compare.ts`](../../../../../scripts/pass-fuzz-compare.ts).
- Direct artifact replay against Binaryen is wired through
  [`../../../../../scripts/self-optimize-compare.ts`](../../../../../scripts/self-optimize-compare.ts).

## Landed Direct-Pass Slices

- CP001: Binaryen-style SFA analysis plus pass-local local and global barrier
  summaries.
- CP002: same-region motion to recognized push points and one-arm `if` sinking.
- CP003: scheduler, registry, and direct `--code-pushing` exposure in the live
  optimize surfaces.
- CP004 partial slices now landed in-tree:
  - safe-prefix explicit-exit motion
  - self-contained and dropped-owner non-void prefix cases
  - alias dropped-carrier extraction
  - narrow `i32` call-fed dropped-carrier extraction
  - safe explicit-exit prefix handling for the call-fed extraction
  - one nested carrier-local wrapper variant
  - terminal-inner-owner carrier widening

## Current Reduced Evidence

- The current named `gen-valid` compare-pass lane still reports a clean reduced
  surface: `pass-fuzz-code-pushing-genvalid-20260410x` finished `10000/10000`
  with `0` mismatches, `0` validation failures, and `0` command failures.
- Earlier, after the dead-gap fix, the larger historical `gen-valid` lane
  `pass-fuzz-code-pushing-genvalid-10000-20260408b` also finished `10000/10000`
  with `0` mismatches. That remains useful evidence, but it is not a same-tree
  signoff for every later carrier slice.
- Mixed and smith-only lanes have also stayed semantically green on the kept pass
  surface, with the remaining failures attributed to Binaryen parser or
  canonicalization rejects rather than Starshine output mismatches.
- The newer explicit-exit branch-payload / body-region fixes remain part of that
  same clean reduced surface.
- The newer lowering-side live-carried fix is part of that same clean surface
  too: the reduced call-prefixed parent-exit family no longer drops the live
  carried value on the branch-taking arm, and the in-tree regression now pins
  the repaired raw lowered form directly.

## Current Signoff Gap

- Whole-artifact parity is still open.
- One smaller stable Binaryen mismatch is now closed.
  Binaryen leaves a nested-block `local.set` in place when the same local is
  still read after the enclosing block, and Starshine now matches that behavior
  instead of sinking the set into the inner `if` arm.
- The current direct debug-artifact path is valid again, but still not close to
  Binaryen parity.
- Native `--code-pushing` output on `tests/node/dist/starshine-debug-wasi.wasm`
  now validates, and traced serial replay now shows only two changed
  functions:
  - `Func 148`
  - `Func 1948`
- `Func 1977` is now kept unchanged earlier in the pass, and the current trace
  has `0` `skip-invalid-lower` lines.
- Direct compare at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3345552`
  still differs canonically and in normalized WAT, with the first visible
  reopened lines still at `44251` / `44254` in printed `func $127`.
- The old top-of-`Func 148` live-carried control-flow corruption is no longer
  the first actionable blocker. The remaining visible drift is later local /
  tuple temp materialization inside the same function.
- That raw hunk is not a fully stable oracle boundary yet: Binaryen no-pass
  writeback does not converge within five roundtrips on this artifact, and a
  fixed `nop5` replay shifts the first normalized hunks away from `44251`.
- A kept runtime-only change also clarified which historical family is already
  done. Comparing Binaryen no-pass-vs-pass output against Starshine no-pass-vs-
  pass output shows the old stable `48978` dropped-carrier move on both sides,
  so the current live parity issue is not that earlier alias move anymore. The
  remaining blocker is the later `44251` / `44254` local and tuple-
  materialization family that still survives the noisier writeback boundary.
- Runtime is also still far outside the target bar:
  - Starshine pass time: `928.451 ms`
  - Binaryen pass time: `55.628 ms`
  - Starshine total: `3496.840 ms`
  - Binaryen total: `373.614 ms`
- The latest kept fallback is narrower semantically too: suspicious
  `code-pushing` lowers are no longer skipped blindly. The pass now lets them
  through when full-module writeback validation succeeds, which is how the old
  `48978` family was admitted without reopening the still-invalid `Func 1977`
  family.
- A second narrowing is now live too: the pass keeps the one-off high-risk
  alias-if tail fenced, but it no longer blocks repeated alias-if ladders.
  That is why `Func 1948` rewrites again on the real artifact while `Func 1977`
  no longer reaches `skip-invalid-lower`.
- The next expected semantic frontier is therefore the reopened `44251`
  `func $127` terminal-owner / local-synthesis family and the later valid
  direct-artifact clusters described in
  [`./artifact-frontiers.md`](./artifact-frontiers.md).
- The honest reading is narrower than that raw diff suggests: some part of the
  remaining whole-artifact gap is still mixed with Binaryen's multivalue /
  local writeback behavior, so reduced pass or HOT proofs still matter more than
  raw WAT shape alone.
- The new reduced parity fix did not move that artifact frontier.
  The refreshed direct compare at
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-4176613` is still
  canonically and normalized red at the same `44251` / `44254` local and tuple
  materialization family, even though the reduced nested-`if` outer-read case
  now matches Binaryen exactly.
- The newer kept performance fix does not change that semantic reading either.
  The refreshed compare-pass lane
  `.tmp/pass-fuzz-code-pushing-genvalid-20260410ab` is still `10000/10000`
  with `0` mismatches, and the faster whole-artifact compare still lands on the
  same `44251` / `44254` family instead of reopening the older `48978` move.

## Scope Boundaries That Are Still Deliberate

- Trap-relaxing Binaryen modes are not modeled yet:
  - `--ignore-implicit-traps`
  - `-tnh`
- The GC non-nullable-local repair family is still out of scope for this direct
  slice because the current HOT pipeline does not yet model Binaryen's local-type
  repair behavior.
- Preset fidelity is intentionally reduced relative to Binaryen's full optimize
  path because Starshine still lacks neighboring passes such as
  `tuple-optimization` and `simplify-locals-nostructure`.

## Honest Current Rule

- Reduced same-tree compare-pass parity is good evidence.
- It is not final signoff.
- Final signoff for this pass still requires all of the following on the same
  tree:
  - valid native `--code-pushing` output on the debug artifact
  - a current-tree `10000`-comparison pass-fuzz lane with no semantic
    mismatches
  - direct artifact replay that either matches Binaryen or leaves only explicitly
    tracked out-of-scope gaps

## Sources

- Canonical research and running status:
  [`../../../../0073-2026-04-02-code-pushing-binaryen-plan.md`](../../../../0073-2026-04-02-code-pushing-binaryen-plan.md)
- Live backlog:
  [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
