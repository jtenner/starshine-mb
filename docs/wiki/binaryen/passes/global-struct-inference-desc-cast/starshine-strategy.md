---
kind: concept
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md
  - ../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md
  - ../../../raw/binaryen/2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
  - ../../../raw/research/0488-2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-singleton-gate-and-dedicated-tests.md
  - ./wat-shapes.md
  - ../global-struct-inference/starshine-hot-ir-strategy.md
  - ../global-struct-inference/index.md
---

# Starshine `global-struct-inference-desc-cast` status and port strategy

This page tracks the local Starshine implementation for `global-struct-inference-desc-cast`, corresponding to upstream Binaryen's public `gsi-desc-cast` sibling.

## Current local status

Starshine now has a **partial active implementation** as of 2026-06-20. The pass is no longer boundary-only:

- registry name: `global-struct-inference-desc-cast`
- upstream public name: `gsi-desc-cast`
- registry category: module pass
- active presets: omitted; this remains a direct-pass surface only
- pass-manager dispatch: present, routed through the GSI-family module implementation with desc-cast mode enabled
- compare harness spelling: `global-struct-inference-desc-cast`, mapped to Binaryen `--gsi-desc-cast`

The old 2026-06-04 `[GSI-PARITY-004]` boundary-only deferral is now superseded for the implemented subset. It remains useful historical context for why this pass was not aliased to ordinary `global-struct-inference` before real desc-cast behavior existed.

## Implemented behavior

The current Starshine implementation runs the ordinary `global-struct-inference` engine and additionally rewrites immediate stack-shape casts when all of these source-backed Binaryen gates hold:

1. desc-cast mode is enabled by the sibling pass;
2. the pass is running with `closed_world=true`, so closed-world candidate globals are available;
3. the cast target heap type is a concrete type with a descriptor type;
4. the target is exact or the target type has no strict subtypes in the local subtype graph;
5. the target descriptor type has exactly one immutable top-level candidate global in the closed-world candidate map.

When the gates hold, Starshine rewrites:

```text
<local.get/global.get operand>
ref.cast <target>
```

into:

```text
<same operand>
global.get <singleton descriptor global>
ref.cast_desc_eq <target>
```

Focused tests in [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt) cover:

- singleton descriptor-global positive rewrite;
- nullable target positive rewrite;
- closed-world-required bailout;
- zero descriptor globals bailout;
- multiple descriptor globals bailout;
- non-exact target with strict subtypes bailout;
- exact target positive rewrite despite strict subtypes.

The sibling also inherits ordinary GSI behavior for struct-field and descriptor-read optimizations through the shared implementation.

2026-06-20 exact-target follow-up: `Instruction::RefCast` and `Instruction::RefCastDescEq` now carry an exact-target bit, the binary codec roundtrips exact cast immediates, validation returns exact cast result types, and the desc-cast gate skips the strict-subtype bailout when the source cast target is exact.

## Known remaining parity gaps

This is not yet a full Binaryen parity closeout.

Known implementation gaps:

- **Operand breadth:** the current desc-cast rewrite handles immediate `local.get` and `global.get` stack operands. Binaryen's AST rewrite can preserve arbitrary cast operands, so Starshine still needs broader stack/structured operand coverage.
- **Dedicated fuzz generation:** the standard compare lane exercises the public pass spelling, but without `--closed-world` it mostly proves the inherited ordinary-GSI/no-rewrite path. A dedicated closed-world descriptor-cast generator/profile is still needed to fuzz the positive `ref.cast_desc_eq` surface at scale.
- **Boundary fixtures:** the fuzz-harness boundary-only failure probe moved to `global-type-optimization`; `global-struct-inference-desc-cast` is no longer appropriate as a boundary-only sentinel.

These gaps keep the pass audit open under the behavior-parity standard.

## Validation evidence from the activation and exact-target slices

2026-06-20 focused evidence:

- Activation slice: `moon test --package jtenner/starshine/passes --file global_struct_inference_test.mbt` — `63/63` passed after adding desc-cast positives and bailouts.
- Exact-target follow-up: red-first focused GSI test failed before implementation because `Instruction::ref_cast_type` did not exist; after implementation, `moon test --package jtenner/starshine/passes --file global_struct_inference_test.mbt` passed `64/64` and `moon test --package jtenner/starshine/binary --file tests.mbt` passed `103/103`.
- `moon test src/passes` — `2894/2894` passed after exact-target support.
- `moon test src/cmd` — `164/164` passed after moving the boundary-only fuzz-harness sentinel.
- `moon info` — completed with pre-existing warnings.
- `moon fmt` — completed.
- `moon test` — `6254/6254` passed after exact-target support.
- `moon build --target native --release src/cmd` — completed, producing `_build/native/release/build/cmd/cmd.exe` with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-global-struct-inference-desc-cast-smoke-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` — `998/1000` compared, `998` normalized matches, `0` mismatches, `2` Binaryen/tool command failures.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-global-struct-inference-desc-cast-10000-rerun --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` — `7602/10000` compared, `7602` normalized matches, `0` mismatches, `20` Binaryen/tool command failures.

Agent classification: the compare lanes are direct-pass smoke/signoff for the public spelling and inherited non-closed-world behavior, not final parity evidence for closed-world descriptor-cast positives.

## Next porting priorities

1. Widen desc-cast operand coverage beyond immediate `local.get` / `global.get` while preserving validation.
2. Add a dedicated GenValid profile for closed-world descriptor-singleton modules that actually hit `ref.cast` -> `ref.cast_desc_eq` positives and the Binaryen bailout families.
3. Run a final closeout lane only after operand breadth and dedicated generator coverage are resolved.

## Sources

- [`../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md)
- [`../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md`](../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md)
- [`../../../raw/binaryen/2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md)
- [`../../../raw/research/0488-2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md`](../../../raw/research/0488-2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md)
- [`../../../../../src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt)
- [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
