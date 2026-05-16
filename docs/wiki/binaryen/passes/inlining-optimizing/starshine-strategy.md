---
kind: concept
status: working
last_reviewed: 2026-05-14
sources:
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining/starshine-strategy.md
  - ../dae-optimizing/index.md
  - ../precompute-propagate/index.md
  - ../duplicate-function-elimination/index.md
---

# Starshine Strategy For `inlining-optimizing`

## Current status

`inlining-optimizing` is a **partial active module pass** in Starshine. It is owned by [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt), shares its core with plain `inlining`, and adds the local optimizing-mode cleanup approximation.

The current v0.1.0 surface is accepted. This is not universal Binaryen inliner parity: broader partial-splitting and residual name/annotation repair are deferred to v0.2.0. The standard direct seed-`0x5eed` mismatch frontier is green:

```text
.tmp/pass-fuzz-inlining-seed-0x5eed-after-four-func-frontier
9975 compared
9975 normalized matches
0 mismatches
0 validation failures
25 ignored Binaryen/tool command failures
```

The broadened direct lane is also green over compared cases:

```text
.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2
9978 compared
9978 normalized matches
0 mismatches
0 validation failures
22 ignored Binaryen/tool command failures
```

The `[INL]002` closeout fuzz lane `.tmp/pass-fuzz-inlining-optimizing-inl002-closeout-10000-keep` is also green over compared cases (`9975/10000`, `9975` matches, `0` mismatches, `25` ignored Binaryen/tool command failures). The debug-artifact direct native abort is cleared, and the latest direct replay `.tmp/inl002-puresuffix-only-20260516-002821` exits `0` and validates. `[INL]002` is accepted as of 2026-05-16 as representation/factoring drift rather than exact Binaryen byte/WAT parity: canonical output still differs, but targeted triage found no validation error, no exported/start/table/ref.func semantic discrepancy, and no meaning-changing evidence in the top aligned examples or skipped helper set. Starshine is smaller by current artifact evidence (`~1.7M` wasm vs Binaryen `~2.2M`; code section `1,560,895` vs `2,106,285`; printed WAT about `35M` vs `134M`; `wasm-opt --all-features --metrics` total nodes `762,965` vs `977,216`).

Both direct fuzz lanes used `--jobs auto` with the prebuilt native `--starshine-bin _build/native/release/build/cmd/cmd.exe`. For seed `0x5eed`, all 25 command failures are Binaryen/tool parse or canonicalization failures and do not count as Starshine semantic parity failures. For seed `0x1eed`, all 22 command failures are ignored Binaryen/tool `binaryen-rec-group-zero` parse failures; the former `case-008100-gen-valid` Starshine command failure now replays green in `.tmp/pass-fuzz-inlining-seed-0x1eed-replay-case008100-narrow-hotunsafe`. `[INL]001`, `[INL]002`, and `[INL]007` are accepted for their current v0.1.0 surfaces, while `[INL]005` and `[INL]006` track deferred partial-inlining and repair/multi-result/tail-call breadth. Reopen `[INL]003` only for a new heuristic/action-filtering semantic mismatch.

## Exact local code map

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - registers `inlining-optimizing` as a module pass;
  - direct pass selection accepts it;
  - public `optimize` / `shrink` presets still omit the late Binaryen `INL` slot.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - dispatches `inlining-optimizing` to `inlining_run_module_pass(... optimize=true, trace=Some(options.trace), pass_name="inlining-optimizing", optimize_level=options.optimize_level, shrink_level=options.shrink_level)`.
- [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt)
  - shared core and optimizing approximation.
- [`src/passes/inlining_test.mbt`](../../../../../src/passes/inlining_test.mbt)
  - focused public-pipeline tests and current mismatch-frontier regressions.
- [`src/passes/inlining_wbtest.mbt`](../../../../../src/passes/inlining_wbtest.mbt)
  - whitebox coverage for the narrow hot-unsafe polymorphic self-call suffix detector.
- [`agent-todo.md`](../../../../../agent-todo.md)
  - v0.1.0 accepts `[INL]001`, `[INL]002`, `[INL]003`, `[INL]004`, and `[INL]007`; v0.2.0 tracks deferred direct-inliner breadth slices `[INL]005` and `[INL]006`.

## Current implemented behavior

- Active `inlining` and `inlining-optimizing` module-pass names.
- Iterative direct `call` and narrow direct `return_call` rewrite waves, including the guarded `[INL]006` subset that can inline a return-call-containing callee only at an outer direct `return_call` callsite while keeping non-tail callsites gated.
- Tiny, one-use private, narrow typed multi-result, narrow shrinking-trivial two-parameter binary-wrapper, ordered direct-call-wrapper, narrow shrinking-trivial three-parameter `select`-wrapper, narrow shrinking-trivial parameter-passthrough memory/table/SIMD/GC operation-wrapper defined callee eligibility, now including the supported SIMD plus GC heap-operation breadth, plus the first speed-focused flexible no-direct-call/no-loop `size <= 20` subset when `optimize_level >= 3` and `shrink_level == 0`.
- Callee parameter/body-local appending and local-index remapping.
- Simple return-to-wrapper-block branch repair.
- Private helper removal after refs disappear.
- Function-index remapping across represented module surfaces.
- Combined-size action filtering using current caller size and the default 400 KiB estimate.
- Nested-cleanup trace marker for optimizing mode, plus an explicit nested-pass trace when the private `precompute-propagate-prefix` helper starts.
- Private touched-only `precompute-propagate-prefix` before the optimizing cleanup lane, using an absolute-to-defined touched-set conversion so imported functions do not shift touched defined-function indexes.
- Touched-function filtered cleanup approximation after the prefix, using the shared hot-pass touched runner plus narrow touched adapters for `local-subtyping`, `coalesce-locals`, and `local-cse`; it drops the former extra pre-default `precompute`, gates option-controlled slots (`ssa-nomerge`, `pick-load-signs`, `code-pushing`, `heap2local`, `optimize-casts`, `local-subtyping`, `local-cse`, `code-folding`, `merge-locals`, and `redundant-set-elimination`) to Binaryen's optimize/shrink thresholds, and keeps the early second `remove-unused-names`, local `reorder-locals`, late local cleanup cluster, and final touched `vacuum`; body restoration remains a safety net but the old whole-module nested cleanup batch no longer runs.
- Exact-`unreachable` private-helper survivor prediction refinements, including shadowed void-cycle result-helper retention, duplicate trimming against non-exact same-signature survivors only when no used self-loop root is present, unique private self-loop representative drops inside root SCCs, selected final root-self-loop representative trimming, and one-helper retention for private result cycles behind self-looping roots.

## Current gaps

### v0.2.0 direct-inliner breadth after accepted `[INL]001` / `[INL]007`

- `[INL]003`: accepted current-supported heuristic/action-filtering surface on 2026-05-14 after adding Binaryen's per-function repeated-work cap; shrinking-trivial wrappers, O3/no-shrink flexible policy, direct-call-only `hasCalls`, combined-size filtering, same-wave guards, and repeated-work caps have 10k closeout evidence;
- `[INL]004`: accepted current `no-inline*` policy surface; name-section/WAT-identifier wildcard marking, full-inline suppression, inlining-compaction annotation/function-name remap, stale local-name dropping, and the shared clone/copy policy helper landed on 2026-05-13;
- `[INL]005`: v0.2.0-only partial inlining splitter. Do not implement for v0.1.0 or for cosmetic Binaryen WAT/byte-shape parity; resume only with a reduced correctness, validation, performance, size, or user-facing policy reason.
- `[INL]006`: v0.2.0-only residual name/annotation repair. The tail-call and multi-result correctness subsets are covered; function names and non-function name maps are covered across type synthesis; function-scoped local/label names remain intentionally dropped after body rewrites rather than reconstructed with Binaryen-like collision repair.

### `[INL]002`: accepted optimizing suffix representation drift

`[INL]002` is accepted for v0.1.0. The private `precompute-propagate-prefix` and touched-function cleanup lane remain an approximation of Binaryen's exact public `precompute-propagate` plus option-specific default function pipeline, but direct fuzz signoff, artifact validation, and targeted triage found no correctness or validation evidence that justifies more v0.1.0 INL work. Do not reopen `[INL]002` for cosmetic canonical drift alone.

## Dependency map

- [`../inlining/index.md`](../inlining/index.md) - shared core and plain stop-point contract.
- [`../precompute-propagate/index.md`](../precompute-propagate/index.md) - required first nested cleanup pass.
- [`../dae-optimizing/index.md`](../dae-optimizing/index.md) - adjacent boundary optimizer with similar touched-function nested-scheduler need.
- [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md) - immediate downstream function-graph cleanup.

## Classification policy

When comparing outputs, separate:

- Starshine semantic/normalized mismatches;
- Starshine validation failures;
- generator failures;
- Binaryen parser/canonicalization/tool command failures.

The user explicitly prefers Binaryen parse/canonicalization failures to be classified as ignored oracle/tool failures, not Starshine semantic failures.

## Bottom line

The correct local mental model is:

- **active but partial**;
- **validation-clean in latest compared lanes, and command-clean for Starshine on the latest seed `0x1eed` lane**;
- **direct seed-`0x5eed` and seed-`0x1eed` compares are green over the compared ranges**;
- **core direct-call subset plus cleanup approximation**;
- **no active v0.1.0 INL implementation blocker**;
- **`[INL]005` and residual `[INL]006` are v0.2.0 backlog only unless new evidence justifies reopening them**.
