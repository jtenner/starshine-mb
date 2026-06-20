---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/research/0786-2026-06-20-precompute-descriptor-split-audit.md
  - ../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md
  - ../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/research/0468-2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/research/0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md
  - ../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md
  - ../../../raw/research/0400-2026-04-26-precompute-port-readiness.md
  - ../../../raw/binaryen/2026-04-22-precompute-primary-sources.md
  - ../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/precompute_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../scripts/lib/self-optimize-compare-task.ts
  - ../../../../../scripts/test/self-optimize-compare-canonical-func-command.ts
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./propagation-partial-precompute-and-gc-identity.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../precompute-propagate/index.md
---

# Starshine `precompute` port readiness and validation

This page is the implementation-readiness bridge for Starshine's active `precompute` pass. It does **not** claim that Starshine already implements the full Binaryen `Precompute.cpp` engine. It explains what is implemented, what to validate, and how to extend the pass without confusing Starshine's HOT cleanup subset with Binaryen's interpreter-driven strategy.
A 2026-05-05 current-main recheck in [`../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md) kept the upstream-teaching map stable.
A later 2026-05-07 current-head rerun in [`../../../raw/research/0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md`](../../../raw/research/0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md) reopened the direct fuzz parity gate on a narrower local family: Starshine trimmed dead root `nop` residue more aggressively than Binaryen before trailing `unreachable`. The same-day `[PC]001` recovery now preserves that dead-root `nop` during `precompute` lowering and normalizes empty unchanged direct-pass bodies to one `nop`; saved repro replay and the mixed direct lane have `0` semantic mismatches. Follow-up raw stack-level shortcuts now skip HOT lift/lower for no-candidate functions, nested nop-only control, safe adjacent scalar folds, branch-free constant-`if` arm picks, immutable module-constant `global.get` folds, mutable/global no-candidate reads, dropped flat nontrapping scalar/global/select expressions, dropped single-result blocks with no branch to the rewritten label, and preserved effectful/trapping dropped tails before HOT. A 2026-05-08 compare-tooling fix stopped WAT data string bytes such as `\\00(` from corrupting canonical-function splitting; the direct debug-artifact compare at `.tmp/pc-artifact-drift-classified` no longer reports canonical-function equality. The first real function drift is defined function `4` / absolute function `21`, and the remaining representation gap is Binaryen expression-stack / temporary-local shaping plus type-index ordering, not a small raw shortcut candidate. A final `[PC]001` recheck at `.tmp/pc001-final-recheck` and `.tmp/pass-fuzz-precompute-pc001-final` kept the direct semantic gate green (`6759 / 6759` normalized matches, `0` mismatches, only the known `20` Binaryen/tool command failures) and confirmed pass-local Starshine is faster than Binaryen (`118ms` vs `164ms`); the unresolved whole-command gap is attributed to `[WALL]001`, so the active `[PC]001` backlog slice is closed.

A 2026-06-20 release-gating refresh in [`../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md`](../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md) reopened the status bar under the modern pass-audit standard. Direct `precompute` remains implemented and supported by the compare harness, but final closeout now needs a dedicated GenValid profile plus the four-lane matrix. The same day's descriptor follow-up in [`../../../raw/research/0786-2026-06-20-precompute-descriptor-split-audit.md`](../../../raw/research/0786-2026-06-20-precompute-descriptor-split-audit.md) added focused registry coverage proving direct `precompute` is SSA-free while private `precompute-propagate-prefix` requires SSA, so `[AUDIT001-E]` is closed and `[AUDIT001-F]` is not needed for current source. The O4z preset slot story still needs explicit treatment: `src/passes/pass_manager.mbt` currently returns `o4z-precompute-noop` for `precompute` when `optimize_level >= 4 && shrink_level >= 1`, covered by the focused test `precompute skips O4z raw pass until self-opt ownership hazards are safe`. Do not claim O4z PC slot closure until that no-op gate is either safely narrowed with tests/evidence or explicitly accepted as a release boundary with reopening criteria.

## Current local contract

Starshine `precompute` is an active HOT pass with a narrow, practical contract:

- fold exact trap-free i32/i64 unary and binary expressions;
- use a conservative raw stack-level fast path for no-candidate functions, nested nop-only control, adjacent scalar folds, branch-free constant-`if` arm picks, module-proven immutable `global.get` constants, mutable/global no-candidate reads, dropped flat nontrapping scalar/global/select expressions, dropped single-result blocks with no branch to the rewritten label, and preserved effectful/trapping dropped tails with no remaining precompute candidate;
- fold exact i32/i64 comparisons to i32 booleans;
- replace immutable defined `global.get` values with constants or `ref.null` where the module context can prove the initializer;
- choose constant `if` arms and rebuild the chosen root shape;
- remove pure dropped values and clean up `nop` residue that would otherwise make HOT writeback harder;
- preserve Binaryen-visible dead-root `nop` sentinels before trailing `unreachable` and normalize empty void bodies to one `nop` at the direct pass boundary;
- validate suspicious lowered output before committing it back to the module;
- intentionally no-op current O4z `precompute` slots via the pass-manager raw gate until self-opt ownership hazards are narrowed or explicitly accepted as a release boundary.

That contract is source-backed by [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt), [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt), and the proof lanes in [`src/passes/precompute_test.mbt`](../../../../../src/passes/precompute_test.mbt) plus raw/perf skip coverage in [`src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt).

## What Binaryen does that Starshine does not yet do

Binaryen's plain `precompute` is much broader than the current Starshine pass. The source dossier records these upstream responsibilities:

- bounded compile-time execution via the `ConstantExpressionRunner` / interpreter family;
- `Flow`-aware handling of values, breaks, and returns;
- child-retention for local/global writes encountered during speculative computation;
- emitability checks separate from “we know the value”; 
- partial precompute through parent shapes such as selected `select` arms;
- GC identity caching for immutable object reasoning;
- final refinalization after type-affecting rewrites.

Starshine should keep those gaps explicit. The local pass is currently a HOT fold-and-cleanup fixpoint, not a miniature Binaryen interpreter.

## Safe next-slice order

### 1. Keep registry and preset behavior stable

Before changing rewrite semantics, keep these public surfaces green:

- [`src/passes/optimize.mbt:207-215`](../../../../../src/passes/optimize.mbt) registers the active `precompute` hot pass.
- [`src/passes/optimize.mbt:254-276`](../../../../../src/passes/optimize.mbt) and [`src/passes/optimize.mbt:394-417`](../../../../../src/passes/optimize.mbt) keep two `precompute` slots in both optimize and shrink presets.
- [`src/passes/registry_test.mbt:110-166`](../../../../../src/passes/registry_test.mbt) and [`src/passes/optimize_test.mbt:290-334`](../../../../../src/passes/optimize_test.mbt) prove those user-visible placements.

### 2. Prefer small trap-free scalar or module-constant additions

The cheapest safe extensions are still direct, trap-free shapes adjacent to what the pass already handles:

- additional integer bit operations with exact wasm wraparound semantics;
- more comparisons when both operands are exact constants;
- immutable-global literal families already representable in HOT;
- pure cleanup cases that preserve every side effect and trap.

Each new family should add a focused `src/passes/precompute_test.mbt` case before implementation and should avoid divisions, remainders, loads, atomics, or heap/object reads unless a stronger semantics proof exists.

### 3. Treat float, string, GC, and interpreter-like work as separate slices

Do not smuggle the larger Binaryen contract into a small fold patch. These families need dedicated design and oracle tests:

- floating point folding, especially NaN payload and signed-zero behavior;
- `StringConst` and string helper surfaces;
- immutable GC field/array reads and object identity;
- partial parent precompute through `select` or other value-carrying control;
- local-flow propagation, which belongs closer to the separate upstream `precompute-propagate` contract.

### 4. Keep writeback validation in scope

For this pass, correctness is not only “the fold result is right.” Old generated-artifact failures were caused by invalid lowered/writeback shapes. The current guard surfaces are part of the pass contract:

- [`src/passes/pass_manager.mbt:8185-8299`](../../../../../src/passes/pass_manager.mbt) validates precompute writeback and emits `skip-invalid-lower` reasons.
- [`src/passes/pass_manager.mbt:8310-8484`](../../../../../src/passes/pass_manager.mbt) detects the escape-carrier block shapes that made older precompute-adjacent rewrites unsafe.
- [`src/cmd/cmd_wbtest.mbt:6778-7101`](../../../../../src/cmd/cmd_wbtest.mbt) preserves artifact replay coverage for generated `-O4z` precompute witnesses.

Any new structural rewrite should preserve these guard rails and add a validation-facing test when it changes root/control shape.

## Validation ladder

Use this order for future work:

1. Add or update a focused `src/passes/precompute_test.mbt` case for the exact before/after shape.
2. Confirm registry, preset, and raw-skip trace tests still pass if the user-visible summary, pass placement, or pass-manager shortcut behavior changes.
3. Compare the new family against Binaryen with pass-targeted fuzzing where possible: `moon build --target native --release src/cmd` followed by `bun fuzz compare-pass --pass precompute ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` or the repository's equivalent pass-fuzz command with the same explicit parallel/binary flags.
4. For control/root-shape rewrites, run full-module validation and keep the `skip-invalid-lower` trace negative unless the test intentionally proves a skip.
5. For artifact-sensitive changes, replay the existing `src/cmd/cmd_wbtest.mbt` lanes before claiming parity improvement.

## Beginner-to-advanced before/after map

| Shape | Starshine today | Binaryen parity note |
| --- | --- | --- |
| `i32.const a; i32.const b; i32.add` | Folds to one i32 const when both operands are exact. | Matches the easy arithmetic subset, not the full interpreter model. |
| `i32.const a; i32.const b; i32.div_s` | Preserved. | Correctly avoids trap-sensitive folding. |
| immutable defined `global.get` | Replaced with literal i32/i64/f32/f64/ref-null constants; `StringConst` is rejected. | Binaryen's emitability and string/GC behavior is broader and subtler. |
| constant void/result `if` | HOT chooses the surviving arm and emits `nop`, a root, or a rebuilt block; raw direct execution now also folds branch-free stack-level constant-`if` tails before adjacent scalar folds, while label-relative branchy arms still defer to HOT. | Related to but narrower than Binaryen's flow-aware computation. |
| `drop(pure-value)` / preserved effectful or trapping dropped value | Pure, side-effect-free, nontrapping values are replaced with `nop` or spliced away; flat scalar/global/select drop tails and safely voidable dropped result blocks can use the raw shortcut, and preserved effectful/trapping dropped tails can now skip HOT when no fold candidate remains, while dead exact roots before a trailing `unreachable` and still-unsupported pure drop families stay on the HOT/direct-boundary path. | Local HOT/raw cleanup and skip gating, not the full Binaryen child-retention algorithm. |
| `select` partial precompute | Not implemented. | Binaryen has a source-backed partial-precompute path. |
| local-flow propagation | Not implemented in `precompute`; local sibling `precompute-propagate` is removed today. | Binaryen's `precompute-propagate` uses `LazyLocalGraph` and a rerun. |
| GC/string/atomic reads | Mostly not implemented. | Upstream has drift and special-case safety fixes; treat as a dedicated future design. |

## Current representation drift classification

The current direct debug-artifact evidence is `.tmp/pc-artifact-drift-classified`, generated with:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --precompute --out-dir .tmp/pc-artifact-drift-classified
```

Important results:

- canonical wasm equal: `no`
- normalized WAT text equal: `no`
- normalized WAT equal after canonical function fallback: `no`
- first differing function: defined `4`, absolute `21`
- Starshine pass time: about `123ms`; Binaryen pass time: about `155ms`
- function type-index drift: `1913 / 4671` defined functions have different type indices because Binaryen's `precompute` output reorders the 119 function types (`type 1` and `type 2` swap immediately), while Starshine's output stays in the no-pass type order
- code-body drift: `757 / 4671` defined code bodies differ byte-for-byte, with `683` size differences and Starshine's code section about `25.9KB` smaller than Binaryen's

The first function drift illustrates the main body-shape family. Starshine keeps the original stack expression around `memory.size`, `local.tee`, and scalar arithmetic, while Binaryen introduces a temporary local and block to preserve the left operand, drops the `local.tee` result, leaves dropped intermediate constants, and replaces the right side with `i32.const 3`. Later in the same function, Binaryen similarly turns a `local.tee`-fed comparison into an explicit `drop(local.tee(...)); if (i32.const 1)`, while Starshine leaves the comparison expression. This is representation drift, not a known semantic mismatch.

Do not treat the older `.tmp/pc-artifact-branch-blockdrop-raw` `Canonical function compare equal: yes` line as proof of function-body equality. The compare splitter was previously counting parentheses inside WAT data strings, so a large data line containing escaped bytes such as `\\00(` could hide all following defined functions from the fallback comparer.

## Open decisions

- Whether `[O4Z-AUDIT-PC]` should recover safe `precompute` behavior under the current O4z gate or keep `o4z-precompute-noop` as an explicitly approved v0.1.0 release boundary with reopening criteria.
- Which dedicated GenValid profile name and family split should be used for final closeout; `docs/wiki/binaryen/passes/precompute/fuzzing.md` currently proposes a composite such as `precompute-all`.
- Whether Starshine should grow a shared interpreter/constant-flow abstraction or keep `precompute` as a pragmatic HOT peephole-plus-cleanup pass. Reopen this as a new focused slice if the project chooses to chase Binaryen's temporary-local / expression-stack shaping rather than treating it as representation drift.
- Whether future `precompute-propagate` work should be a separate pass from the start, matching the current local removed registry entry, or should first share helper analysis with plain `precompute`.
- When the wiki should update its baseline from Binaryen `version_129` to a newer upstream release. Until that happens, current-main drift should stay labeled rather than silently changing the taught contract.

## Sources

- [`../../../raw/research/0786-2026-06-20-precompute-descriptor-split-audit.md`](../../../raw/research/0786-2026-06-20-precompute-descriptor-split-audit.md)
- [`../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md`](../../../raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md)
- [`../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md)
- [`../../../raw/research/0400-2026-04-26-precompute-port-readiness.md`](../../../raw/research/0400-2026-04-26-precompute-port-readiness.md)
- [`../../../raw/binaryen/2026-04-22-precompute-primary-sources.md`](../../../raw/binaryen/2026-04-22-precompute-primary-sources.md)
- [`../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md`](../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md)
- [`../../../../../src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/precompute_test.mbt`](../../../../../src/passes/precompute_test.mbt)
- [`../../../../../scripts/lib/self-optimize-compare-task.ts`](../../../../../scripts/lib/self-optimize-compare-task.ts)
- [`../../../../../scripts/test/self-optimize-compare-canonical-func-command.ts`](../../../../../scripts/test/self-optimize-compare-canonical-func-command.ts)
