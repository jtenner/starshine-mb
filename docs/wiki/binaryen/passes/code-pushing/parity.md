---
kind: comparison
status: working
last_reviewed: 2026-04-12
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md
  - ../../../raw/research/0077-2026-04-11-code-pushing-result-if-sink.md
  - ../../../raw/research/0078-2026-04-11-code-pushing-result-if-reorder.md
  - ../../../raw/research/0079-2026-04-12-code-pushing-one-off-alias-tail-prefix.md
  - ../../../raw/research/0080-2026-04-12-code-pushing-crossed-condition-set-alias.md
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
  - result-producing `if` arm sinks when only one arm reads the local
  - reorders past result-producing `if` pushpoints that do not touch the local
  - one-off alias tails without an earlier explicit-exit carrier feeding them
  - crossed-gap carrier aliases when the kept condition-set does not alias that same carried local

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
- The clean reduced surface now also covers expression-position nested-region
  carriers explicitly. Binaryen rewrites the same nested `block (result ...)`
  family under `local.set`, `local.tee`, and `global.set` value positions, and
  the current tree now pins all three reduced cases in `src/passes/code_pushing_test.mbt`.
- The latest same-tree compare-pass lane is
  `pass-fuzz-code-pushing-20260412c`, and it completed `10000/10000` with `0`
  mismatches, validation failures, generator failures, or command failures after
  narrowing the crossed condition-set carrier alias guard to the real same-source
  aliasing case.
- A fresh smith-only lane stays semantically green too after that fix:
  `pass-fuzz-code-pushing-20260412d` completed `997/1000` compared with `0`
  mismatches and only `3` Binaryen-side command failures.

## Current Signoff Gap

- Reduced and fuzz parity are still green.
- The old ownership question on the whole-artifact frontier is now resolved:
  Binaryen `--code-pushing` is a no-op on the printed `func $127` /
  `parse__config__json` frontier, so that family was not an unported upstream
  transform surface. It was a Starshine-only admission mixed with Binaryen
  writeback noise.
- One smaller stable Binaryen mismatch is now closed.
  Binaryen leaves a nested-block `local.set` in place when the same local is
  still read after the enclosing block, and Starshine now matches that behavior
  instead of sinking the set into the inner `if` arm.
- The same narrowing is now applied one step later too:
  `code-pushing` again fences the
  `candidate-set -> condition-set -> later-if` terminal-owner family when the
  candidate aliases an earlier explicit-exit carried local.
- One older deliberate divergence is gone now too: Starshine no longer blocks
  one-arm sinks just because the target `if` produces a value. Binaryen does
  perform that sink surface, and the reduced plus fuzz evidence stays green on
  the current tree after removing the blanket result-`if` fence.
- A second result-`if` over-fence is gone too: Starshine no longer refuses the
  ordinary same-region pushpoint reorder just because the target `if` produces
  a value. Binaryen moves safe `local.set` roots to immediately after such
  pushpoints, and the current tree now matches that reduced surface.
- The old explicit-exit-fed alias-if-tail fence is gone now too: the reduced
  repeated-ladder repro plus the current Binaryen `Func 1977` artifact slice
  both show Binaryen still moving the carried alias through the later decref
  `if`, so Starshine no longer blocks that family through a dedicated tail
  guard.
- The crossed condition-set carrier alias guard is narrower now too: Starshine
  no longer blocks the move just because some crossed condition-set local feeds
  the later `if`. The guard now only keeps the true same-source aliasing case
  fenced.
- The current direct debug-artifact path is valid again, but still not close to
  Binaryen parity.
- Native `--code-pushing` output on `tests/node/dist/starshine-debug-wasi.wasm`
  still validates on the kept branch, and the artifact contract is narrower now:
  `Func 148` should stay unchanged while `Func 1948` and the reopened `Func 1977`
  family are the expected late rewrites.
- `Func 1977` is no longer just a "not skipped" contract. The reduced probe and
  Binaryen artifact slice now both show it as real upstream surface again.
- One sharper current-tree frontier was isolated outside the still-expensive
  full replay and is now closed too: standalone recreations built from saved
  function slices showed that the old saved `Func 509` family was stale on the
  current tree, while standalone `Func 1975` still differed as a richer
  result-`if` sink case. The reduced nested-condition repro from `0083` now
  matches Binaryen there as well.
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
- A newer direct release replay is more blunt still: the current `cmd.exe --code-pushing`
  artifact run stayed above `5` minutes of CPU time and was aborted before completion.
  So the kept tree is parity-safe on reduced and generated cases, but runtime on the
  real artifact is still the next blocker.
- The latest kept fallback is narrower semantically too: suspicious
  `code-pushing` lowers are no longer skipped blindly. The pass now lets them
  through when full-module writeback validation succeeds, which is how the old
  `48978` family was admitted while the branch-arity-sensitive owner cases stay
  fail-closed.
- A second narrowing is now live too: the pass no longer keeps a dedicated
  explicit-exit-fed alias-if-tail fence. That is why the reopened `Func 1977`
  family is upstream surface again instead of a deliberate Starshine-only hold.
- A third narrowing is live too: the crossed condition-set carrier alias guard
  only fires when the crossed condition-set itself aliases that same carried
  local. Unrelated condition-set locals no longer block the move.
- The earlier wiki wording that treated `44251` as the next remaining upstream
  `code-pushing` surface is now superseded by
  [`0076`](../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md):
  Binaryen does not transform that function at all.
- The next full signoff question is therefore narrower:
  rerun the real artifact on the kept fence and see whether any later semantic
  delta survives after `Func 148` stops changing.
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
