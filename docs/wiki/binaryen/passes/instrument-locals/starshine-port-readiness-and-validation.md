---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-instrument-locals-port-readiness-primary-sources.md
  - ../../../raw/research/0397-2026-04-26-instrument-locals-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/lib/module.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/effects.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./unsupported-types-effects-and-import-roster.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../instrument-memory/index.md
  - ../global-effects/index.md
  - ../tracker.md
---

# `instrument-locals` Starshine port readiness and validation

## Current decision point

Starshine does **not** implement `instrument-locals` today.
This page exists so a future implementer does not confuse the upstream pass with a simple local peephole.
The source-backed upstream contract is a module transform:

1. add helper function imports,
2. wrap supported `local.get` values in `get_*` helper calls,
3. wrap supported `local.set` / `local.tee` assigned values in `set_*` helper calls,
4. report that the pass adds effects,
5. preserve unsupported traffic exactly.

A Starshine port should therefore be deliberately scheduled as **module-pass/import-synthesis work**, not as a HOT-only local rewrite.

## Recommended first local slice

The safest first slice is intentionally smaller than Binaryen's full current surface:

- accept the public pass spelling `instrument-locals` only after the registry status is deliberately chosen;
- synthesize helper function types and `env` imports for scalar helpers;
- rewrite only `i32`, `f32`, and `f64` local traffic;
- share one monotonic call-id sequence across get and set wrappers;
- preserve `i64`, reference, SIMD, `unreachable` value, and `Pop` cases as negative fixtures;
- validate the module after import/function-index insertion and after function-body rewriting;
- add an effect-composition test before mixing the pass with `global-effects`, `discard-global-effects`, or `vacuum`-like cleanup.

This slice is useful even though it is smaller than upstream because it proves the hard Starshine-specific part: helper ABI synthesis plus valid module repair.

## Why HOT-only is the wrong first slice

Starshine's HOT layer already sees local traffic:

- `src/ir/hot_core.mbt:42-44` defines `LocalGet`, `LocalSet`, and `LocalTee` operations.
- `src/ir/hot_lift.mbt:492-580` includes local operations in lifting decisions.
- `src/ir/effects.mbt:134-135` classifies local get/set/tee as local-state effects.

Those facts are necessary but not sufficient.
Binaryen's `instrument-locals` output is only valid after module-level helper imports and function types exist.
A HOT-only rewrite would need to emit calls to functions that were never declared, and it would not model the new imported-call effects that motivated Binaryen's `addsEffects()` override.

## Exact Starshine surfaces to read before implementing

### Registry and user-facing status

- `src/passes/optimize.mbt:126-153` lists boundary-only and removed pass names; `instrument-locals` is absent.
- `src/passes/optimize.mbt:156-267` builds active hot/module/preset entries; `instrument-locals` is absent.
- `src/passes/optimize.mbt:363-367` exposes public pass-category lookup.
- `src/passes/optimize.mbt:446-489` rejects absent names as `unknown pass flag ...` before boundary-only / removed guards.
- `src/passes/registry_test.mbt:1-90` and `134-157` cover registry categories and preset expansion; add expectations here first if the public status changes.

### Import and module-index substrate

- `src/lib/types.mbt:181-185` defines `FuncExternType(TypeIdx)`.
- `src/lib/types.mbt:430` defines `ImportSec(Array[Import])`.
- `src/lib/types.mbt:8084-8085` provides `ImportSec::new(...)`.
- `src/lib/module.mbt:146-151` includes function imports in module index construction.
- `src/passes/optimize.mbt:407-421` counts imported functions for pipeline validation bookkeeping. This helper is a **red herring** for implementation: it can help validate counts, but it does not synthesize helper imports.

### Body-rewrite substrate

- `src/ir/hot_core.mbt:42-44` names the local operations a body pass would visit.
- `src/ir/hot_lift.mbt:492-580` and nearby lifting logic determine when local operations appear in HOT regions.
- `src/ir/effects.mbt:134-135` currently treats local ops as local-state effects. Imported helper calls would need their own effect story rather than inheriting local-state-only behavior.

## Shape coverage for first-slice tests

Start with fixtures modeled on [`./wat-shapes.md`](./wat-shapes.md):

| Shape | Expected first-slice behavior |
| --- | --- |
| `(local.get $x)` where `$x : i32` | replace value with `(call $get_i32 (i32.const id) (i32.const local) (local.get $x))` |
| `(local.set $x (f32.const ...))` | keep outer set, wrap assigned value with `set_f32` |
| `(local.tee $x (f64.const ...))` | keep outer tee, wrap assigned value with `set_f64` |
| helper imports absent initially | add required `env` scalar helper imports and function types |
| ordinary `i64` get/set/tee | leave unchanged, even if helper roster later includes `i64` imports |
| nullable `funcref` / `externref` | leave unchanged in the first slice; add later with separate feature tests |
| `v128` locals | leave unchanged in the first slice; add later behind SIMD feature tests |
| `Pop` assigned value | leave unchanged |
| unreachable assigned value | leave unchanged |

## Validation ladder

1. **Registry behavior:** decide whether `instrument-locals` remains unknown or becomes an active module pass. Encode that in `src/passes/registry_test.mbt`.
2. **Import synthesis:** parse a minimal module, run the pass, and assert helper function types plus imports are present and valid.
3. **Scalar get:** assert a value-position `local.get` is wrapped and still has the original result type.
4. **Scalar set/tee:** assert the outer local write remains while only the value child changes.
5. **Call-id ordering:** mix gets and sets in one function and assert one shared increasing ID sequence.
6. **Negative families:** assert `i64`, unsupported refs, SIMD before support, `Pop`, and unreachable assigned values stay unchanged.
7. **Index stability:** assert pre-existing direct calls still target the same functions after helper imports are inserted.
8. **Effect composition:** model Binaryen's `instrument-locals_effects.wast` lesson: after helper calls are inserted, effect-sensitive cleanup must not rely on stale global-effect knowledge.
9. **Oracle comparison:** once the harness supports instrumentation passes, compare the covered subset against `wasm-opt --instrument-locals` while ignoring known deliberate first-slice gaps.

## Explicit non-goals

- Do not add the pass to `optimize` or `shrink` presets just because it becomes implementable. It is instrumentation, not optimization.
- Do not claim memory load/store coverage; that belongs to [`../instrument-memory/index.md`](../instrument-memory/index.md).
- Do not silently instrument `i64` before Binaryen does; upstream still injects `i64` helper imports but does not wrap ordinary `i64` local traffic.
- Do not collapse this page into [`./starshine-strategy.md`](./starshine-strategy.md). That page records current status; this page records the future implementation/validation bridge.

## Sources

- [`../../../raw/binaryen/2026-04-26-instrument-locals-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-instrument-locals-port-readiness-primary-sources.md)
- [`../../../raw/research/0397-2026-04-26-instrument-locals-port-readiness.md`](../../../raw/research/0397-2026-04-26-instrument-locals-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md)
- Binaryen current-main `InstrumentLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentLocals.cpp>
- Binaryen current-main `instrument-locals_all-features_disable-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
- Binaryen current-main `instrument-locals_effects.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_effects.wast>
- Binaryen current-main `instrument-locals-eh-legacy.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals-eh-legacy.wast>
