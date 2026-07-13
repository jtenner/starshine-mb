# DAE block-fallthrough propagation and imported-tag type gap

Date: 2026-07-13

## Scope

This slice compared Binaryen `version_130`'s direct `--dae-optimizing` nested replay with Starshine's touched-function scheduler and selected one behavior-bearing `precompute-propagate` gap rather than treating pass names alone as missing behavior.

Binaryen's direct-pass debug trace runs a prepended `precompute-propagate` before its default function pipeline. The reduced family here depends specifically on Binaryen's rule that a local set may be analyzed through the set value's fallthrough value while preserving the wrapper's effects.

## Red proof

The low-definition public-pipeline fixture added to `src/passes/dae_optimizing_test.mbt` has:

- a private callee with one dead parameter;
- a local set whose value is an `i32` result block;
- an observable `global.set` before the block's final `i32.const 7`;
- a later `local.get + 1` result;
- one direct caller passing an unused literal.

Binaryen `version_130 --dae-optimizing` preserves the `global.set` and returns `i32.const 8`. Before the implementation, Starshine removed the dead parameter but retained `local.set 7; local.get; i32.const 1; i32.add`. The focused test failed on the required `I32(8)` assertion.

## Implementation

`src/passes/precompute.mbt` now extends the private touched-only `precompute-propagate-prefix` constant resolver with two value-preserving fallthrough forms:

- `local.tee` with one value child;
- an unbranched single-result `block`, using its final body root as the fallthrough value.

The recognizer computes label-use facts once. A block is admitted only when its label is unused, so `br`, `br_if`, or other branch-carried alternate results cannot be mistaken for the final root's constant. The original block, local write, and effectful prefix are not deleted by the recognizer; it only supplies the constant fact to the later ordinary precompute/cleanup replay.

A focused negative keeps a branch-valued block whose label can receive `9` while ordinary fallthrough yields `7`. Starshine preserves the branch and does not replace the result with `8`.

This closes one real nested propagation family. It does not make the private helper the full public `precompute-propagate` sibling: broader `Properties::getFallthrough(...)` wrappers, the exact one-extra-walk contract, and the complete Binaryen default-function replay still require source/test review.

## Validation

- `moon fmt` — passed; unrelated formatter-only changes were reverted.
- `moon info` — passed with existing warnings.
- `moon test src/passes/dae_optimizing_test.mbt --filter '*block fallthrough*'` — `2/2` passed.
- `moon test src/passes/dae_optimizing_test.mbt` — `197/197` passed.
- `moon test src/passes` — `5087/5087` passed.
- `moon build --target native --release src/cmd` — passed with existing warnings.
- `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-wasm-smith-smoke-20260713-block-fallthrough --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe`
  - requested `1000`;
  - compared `996`;
  - normalized matches `996`;
  - cleanup-normalized matches `0`;
  - mismatches `0`;
  - validation/property/generator failures `0`;
  - command failures `4`;
  - cache: wasm-smith `500/500` hits/misses, Binaryen `5/991`, Binaryen failures `0/3`.

Three command failures were oracle/tool failures: two `binaryen-rec-group-zero` and one `binaryen-invalid-tag-index`.

The regular GenValid smoke could not regenerate its batch in this runtime because the harness's `moon run --target native --release src/fuzz` command failed registry resolution for the already-vendored `moonbitlang/x` dependency. The previous 2026-07-13 1000-case GenValid lane remains green, but it is not counted as post-change evidence for this slice.

## Newly exposed correctness blocker

The fourth wasm-smith command failure is a genuine Starshine DAE validation failure, independent of the new nested propagation path. The reduced module has no functions:

```wat
(module
  (type (func (param nullfuncref i32)))
  (import "8" "" (tag (type 0) (param nullfuncref i32)))
  (data "\1f\b4"))
```

A no-pass Starshine round trip validates. `--dae-optimizing` fails final validation with `No type exists for TypeIdx`.

Source inspection identifies the narrow owner: `dae_prune_unused_simple_func_types(...)` marks function, table, global, defined-tag, element, local, and instruction type uses, but its import scan handles function/table/global imports and omits imported `TagExternType`. It therefore deletes the tag payload function type and leaves the imported tag referencing a missing type.

Classification: **validation failure and direct-pass behavior gap**, not a nested-replay mismatch and not an accepted representation boundary.

Required next action:

1. add a red public-pipeline imported-tag-only type-liveness regression;
2. mark and remap imported tag type indices in the simple type-pruning helper;
3. add a defined-tag/imported-tag contrast or unrelated-unused-type positive so pruning still occurs;
4. replay saved case `case-000140-wasm-smith`, the focused DAE suite, all pass tests, native build, and fresh direct compare evidence.

## Remaining gap after this slice

The DAE audit stays active. Remaining broad owners include:

- imported-tag type liveness correctness;
- fuller fallthrough/local-worklist coverage and the real public `precompute-propagate` contract;
- Binaryen-shaped touched-function default replay and remaining scheduler guards;
- broader operand localization;
- GC parameter refinement;
- result refinement;
- the final selected/artifact-helper inventory and classification;
- the full four-lane closeout matrix and source/docs cross-check.
