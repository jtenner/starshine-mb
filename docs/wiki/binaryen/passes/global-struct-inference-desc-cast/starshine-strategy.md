---
kind: concept
status: supported
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

Starshine has an **active behavior-parity implementation** as of 2026-06-20. The pass is no longer boundary-only:

- registry name: `global-struct-inference-desc-cast`
- upstream public name: `gsi-desc-cast`
- registry category: module pass
- active presets: omitted; this remains a direct-pass surface only
- pass-manager dispatch: present, routed through the GSI-family module implementation with desc-cast mode enabled
- compare harness spelling: `global-struct-inference-desc-cast`, mapped to Binaryen `--gsi-desc-cast`

The old 2026-06-04 `[GSI-PARITY-004]` boundary-only deferral is now superseded for the implemented subset. It remains useful historical context for why this pass was not aliased to ordinary `global-struct-inference` before real desc-cast behavior existed.

## Implemented behavior

The current Starshine implementation runs the ordinary `global-struct-inference` engine and additionally rewrites validated stack-shape casts when all of these source-backed Binaryen gates hold:

1. desc-cast mode is enabled by the sibling pass;
2. the pass is running with `closed_world=true`, so closed-world candidate globals are available;
3. the cast target heap type is a concrete type with a descriptor type;
4. the target is exact or the target type has no strict subtypes in the local subtype graph;
5. the target descriptor type has exactly one immutable top-level candidate global in the closed-world candidate map.

When the gates hold, Starshine rewrites:

```text
<arbitrary validated stack operand already produced>
ref.cast <target>
```

into:

```text
<same already-produced operand>
global.get <singleton descriptor global>
ref.cast_desc_eq <target>
```

The implementation is intentionally cast-local: it does not need to understand or move the operand tree. It inserts the descriptor global immediately before the eligible reachable `ref.cast`, which preserves WebAssembly evaluation order for local/global operands, structured block/loop/if operands, select operands, and casts separated from their source by no-result instructions. Statically unreachable cast inputs stay on the ordinary `ref.cast` path to match Binaryen's `visitRefCast` gate.

Focused tests in [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt) cover:

- singleton descriptor-global positive rewrite;
- nullable target positive rewrite;
- closed-world-required bailout;
- zero descriptor globals bailout;
- multiple descriptor globals bailout;
- non-exact target with strict subtypes bailout;
- exact target positive rewrite despite strict subtypes;
- broader validated operand coverage for block, select, if, loop, and intervening no-result-instruction stack shapes;
- unreachable-input bailout coverage.

The sibling also inherits ordinary GSI behavior for struct-field and descriptor-read optimizations through the shared implementation.

2026-06-20 exact-target follow-up: `Instruction::RefCast` and `Instruction::RefCastDescEq` now carry an exact-target bit, the binary codec roundtrips exact cast immediates, validation returns exact cast result types, and the desc-cast gate skips the strict-subtype bailout when the source cast target is exact.

## Remaining parity gaps and reopening criteria

No known unimplemented Binaryen `gsi-desc-cast` behavior gap remains in the current direct-pass scope. The old boundary-only deferral and the later final-closeout blocker are superseded by the 2026-06-20 implementation, dedicated GenValid profile, and full closeout matrix below.

Retained non-goals and boundaries:

- `global-struct-inference-desc-cast` is a direct module-pass surface only; it is still not scheduled in public `optimize` / `shrink` presets without a separate preset-neighborhood proof.
- Exact raw/canonical text shape parity is not claimed when normalized compare evidence is green and source-backed behavior matches Binaryen.
- Binaryen/oracle command failures in the explicit wasm-smith lane are tool boundaries, not Starshine transform mismatches.

Reopen this audit only for a new semantic mismatch, a Starshine validation failure attributable to this pass, a regression in the focused desc-cast tests or `gsi-desc-cast` profile, a broad unclassified output-shape family without measured/accepted Starshine benefit, a Starshine-specific command-failure class after oracle/tool failures are excluded, or new Binaryen source/lit drift that widens `gsi-desc-cast` beyond the implemented singleton target-descriptor contract.

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

2026-06-20 operand-breadth follow-up evidence:

- Red-first focused `global_struct_inference_test.mbt` first failed on the intervening no-result-instruction cast shape because `ref.cast` remained; the follow-up unreachable-input bailout test then failed because the new cast-local rewrite changed an unreachable cast to `ref.cast_desc_eq`. After implementation the focused file passed `70/70`.
- `moon info` — completed with pre-existing warnings.
- `moon fmt` — completed.
- `moon test src/passes` — `2685/2685` passed.
- `moon test` — `5999/5999` passed.
- `moon build --target native --release src/cmd` — completed, producing `_build/native/release/build/cmd/cmd.exe` with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-global-struct-inference-desc-cast-operand-breadth-unreachable-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` — `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Earlier attempts using `.tmp/pass-fuzz-global-struct-inference-desc-cast-operand-breadth-10000` and `.tmp/pass-fuzz-global-struct-inference-desc-cast-operand-breadth-10000-rerun` were superseded by the final unreachable-bailout rerun; the first failed before comparison while emitting the GenValid batch.

2026-06-20 dedicated GenValid profile follow-up evidence:

- Added `gsi-desc-cast` as a deterministic composite GenValid profile in [`../../../../../src/validate/gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt), with leaves for positive singleton rewrites, strict-subtype exact/non-exact split, zero-global bailout, multiple-global bailout, and unreachable-input bailout. Focused generator tests in [`../../../../../src/validate/gen_valid_tests.mbt`](../../../../../src/validate/gen_valid_tests.mbt) prove the profile resolves, samples every leaf, emits validating modules, and records the intended boundary/positive shapes.
- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` — `80/80` passed after the red-first unknown-profile failure.
- `moon test src/validate` — `1616/1616` passed.
- `moon info` — completed with pre-existing warnings.
- `moon fmt` — completed.
- `moon test` — `6003/6003` passed.
- `moon build --target native --release src/cmd` — completed, producing `_build/native/release/build/cmd/cmd.exe` with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --gen-valid-profile gsi-desc-cast --out-dir .tmp/pass-fuzz-gsi-desc-cast-genvalid-gsi-desc-cast-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` — `10000/10000` compared, `10000` normalized matches, `0` raw mismatches, `0` validation/generator/property failures, and `0` command failures. Selected profile counts: `gsi-desc-cast-positive=5045`, `gsi-desc-cast-strict-subtype=1944`, `gsi-desc-cast-zero-boundary=1021`, `gsi-desc-cast-unreachable-boundary=1006`, `gsi-desc-cast-multi-boundary=984`.

2026-06-20 final closeout evidence:

- Focused final validation: `moon info` passed with pre-existing GenValid warnings; `moon fmt` passed; `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` passed `80/80`; `moon test src/validate` passed `1616/1616`; `moon test --package jtenner/starshine/passes --file global_struct_inference_test.mbt` passed `70/70`; `moon test src/passes` passed `2685/2685`; `moon test src/cmd` passed `164/164`; full `moon test` passed `6003/6003`; `moon build --target native --release src/cmd` passed with pre-existing pass-manager warnings; `git diff --check` passed.
- Regular GenValid closeout lane: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-gsi-desc-cast-genvalid-100000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `100000/100000`, normalized `100000`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property failures `0`, command failures `0`; cache: wasm-smith `0/0`, Binaryen `10313` hits / `89687` misses, Binaryen failures `0/0`; selected profile `binaryen-oracle-portable=100000`.
- Explicit wasm-smith closeout lane: `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-gsi-desc-cast-wasm-smith-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `9956/10000`, normalized `9956`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property failures `0`, command failures `44`; command classes: `binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`; cache: wasm-smith `3811` hits / `6189` misses, Binaryen `3870` hits / `6086` misses, Binaryen failures `20` hits / `24` misses.
- Dedicated desc-cast GenValid closeout lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --gen-valid-profile gsi-desc-cast --out-dir .tmp/pass-fuzz-gsi-desc-cast-genvalid-gsi-desc-cast-final-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `10000/10000`, normalized `10000`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property failures `0`, command failures `0`; cache: Binaryen `10000` hits / `0` misses; selected profiles `gsi-desc-cast-positive=5045`, `gsi-desc-cast-strict-subtype=1944`, `gsi-desc-cast-zero-boundary=1021`, `gsi-desc-cast-unreachable-boundary=1006`, `gsi-desc-cast-multi-boundary=984`.
- Broad named GenValid profile lane: the local profile catalog has no literal `all-profiles` profile; for this audit the repo-current broad Binaryen-oracle portable profile name selected for the random/all-profile slot is `pass-fuzz-stress` (the named form of the default compare-pass GenValid batch config). `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass global-struct-inference-desc-cast --gen-valid-profile pass-fuzz-stress --out-dir .tmp/pass-fuzz-gsi-desc-cast-genvalid-pass-fuzz-stress-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `10000/10000`, normalized `10000`, cleanup-normalized `0`, raw mismatches `0`, validation/generator/property failures `0`, command failures `0`; cache: Binaryen `157` hits / `9843` misses; selected profile `pass-fuzz-stress=10000`.

Agent classification: the final matrix has zero Starshine semantic mismatches and zero Starshine validation failures. The explicit wasm-smith residual command failures are known Binaryen/oracle tool classes, not pass-output behavior. Source review plus focused tests cover the Binaryen target-descriptor-singleton gate, strict-subtype exactness split, zero/multiple descriptor-global bailouts, nullable targets, structured operands, no-result intervening instructions, inherited ordinary-GSI behavior, and the unreachable-input bailout. The direct `global-struct-inference-desc-cast` audit is closed for current behavior parity.

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
