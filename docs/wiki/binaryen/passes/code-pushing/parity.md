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
  surface: `pass-fuzz-code-pushing-genvalid-20260409j` finished `1000/1000`
  with `0` mismatches, `0` validation failures, and `0` command failures.
- Earlier, after the dead-gap fix, the larger historical `gen-valid` lane
  `pass-fuzz-code-pushing-genvalid-10000-20260408b` also finished `10000/10000`
  with `0` mismatches. That remains useful evidence, but it is not a same-tree
  signoff for every later carrier slice.
- Mixed and smith-only lanes have also stayed semantically green on the kept pass
  surface, with the remaining failures attributed to Binaryen parser or
  canonicalization rejects rather than Starshine output mismatches.

## Current Signoff Gap

- Whole-artifact parity is still open.
- The current direct debug-artifact path is blocked even before normalized WAT
  comparison finishes: native `--code-pushing` on
  `tests/node/dist/starshine-debug-wasi.wasm` currently fails final validation
  with `stack underflow` in `Func 1977`.
- Because of that invalid output, the current branch does not yet have an honest
  direct-pass signoff against Binaryen for the real artifact.
- Once that invalid family is fixed, the next expected semantic frontier is still
  the broader terminal-owner / alias-local-synthesis area described in
  [`./artifact-frontiers.md`](./artifact-frontiers.md).

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
