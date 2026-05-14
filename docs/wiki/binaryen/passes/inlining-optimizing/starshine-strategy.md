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
  - ../../../../../CHANGELOG.md
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

Do not claim full pass signoff yet because broader heuristic gaps and the exact optimizing nested scheduler remain open. The standard direct seed-`0x5eed` mismatch frontier is green:

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

Both lanes used `--jobs auto` with the prebuilt native `--starshine-bin _build/native/release/build/cmd/cmd.exe`. For seed `0x5eed`, all 25 command failures are Binaryen/tool parse or canonicalization failures and do not count as Starshine semantic parity failures. For seed `0x1eed`, all 22 command failures are ignored Binaryen/tool `binaryen-rec-group-zero` parse failures; the former `case-008100-gen-valid` Starshine command failure now replays green in `.tmp/pass-fuzz-inlining-seed-0x1eed-replay-case008100-narrow-hotunsafe`. `[INL]001` is accepted for the current supported optimizing direct surface, `[INL]007` is accepted for the current supported plain direct surface, `[INL]002` remains active for the touched-function nested scheduler, and `[INL]003`, `[INL]005`, and `[INL]006` track deferred direct-inliner breadth.

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
  - active `[INL]002` scheduler work plus deferred direct-inliner breadth slices `[INL]003`, `[INL]005`, and `[INL]006`; `[INL]007` is accepted for plain direct signoff.
- [`CHANGELOG.md`](../../../../../CHANGELOG.md)
  - 2026-05-11 and 2026-05-12 implementation checkpoints.

## Current implemented behavior

- Active `inlining` and `inlining-optimizing` module-pass names.
- Iterative direct `call` and narrow direct `return_call` rewrite waves.
- Tiny, one-use private, narrow shrinking-trivial two-parameter binary-wrapper, narrow shrinking-trivial three-parameter `select`-wrapper, narrow shrinking-trivial parameter-passthrough memory/table/SIMD/GC operation-wrapper defined callee eligibility, now including the supported SIMD plus GC heap-operation breadth, plus the first speed-focused flexible no-call/no-loop `size <= 20` subset when `optimize_level >= 3` and `shrink_level == 0`.
- Callee parameter/body-local appending and local-index remapping.
- Simple return-to-wrapper-block branch repair.
- Private helper removal after refs disappear.
- Function-index remapping across represented module surfaces.
- Nested-cleanup trace marker for optimizing mode.
- Broad cleanup approximation with untouched-body restoration and touched-local compaction.
- Exact-`unreachable` private-helper survivor prediction refinements, including shadowed void-cycle result-helper retention, duplicate trimming against non-exact same-signature survivors only when no used self-loop root is present, unique private self-loop representative drops inside root SCCs, selected final root-self-loop representative trimming, and one-helper retention for private result cycles behind self-looping roots.

## Current gaps

### Deferred direct-inliner breadth after accepted `[INL]001` / `[INL]007`

- `[INL]003`: exact Binaryen heuristic classes/options plus action filtering, iteration caps, and size guard; narrow two-parameter binary, three-parameter `select`, and memory/table/SIMD/GC operation `Shrinks` subsets through the latest supported SIMD plus GC heap-operation breadth slice landed on 2026-05-14, and the first optimize-level-three/no-shrink flexible no-call/no-loop subset is implemented and covered by loop/call/shrink-mode focused tests; remaining trivial/flexible/action-size breadth remains active;
- `[INL]004`: accepted current `no-inline*` policy surface; name-section/WAT-identifier wildcard marking, full-inline suppression, inlining-compaction annotation/function-name remap, stale local-name dropping, and the shared clone/copy policy helper landed on 2026-05-13;
- `[INL]005`: partial inlining splitter;
- `[INL]006`: nested `return_call*`, multi-result typing, and label/name/annotation repair.

### `[INL]002`: optimizing suffix parity

- exact touched-function set;
- former seed-`0x1eed` `case-008100-gen-valid` Starshine command failure is fixed by the narrow hot-unsafe helper guard;
- real `precompute-propagate` equivalent first;
- Binaryen default function pipeline on only touched functions;
- scheduler tests distinguishing touched callers/callees/removed helpers/untouched functions;
- late-tail artifact replay after direct parity.

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
- **INL backlog still open**.
