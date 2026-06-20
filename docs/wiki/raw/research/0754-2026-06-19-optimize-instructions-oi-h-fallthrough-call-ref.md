# Optimize-instructions OI-H fallthrough call_ref directization

## Question

Does Starshine's `optimize-instructions` cover the Binaryen `version_130` `visitCallRef(...)` family where the `call_ref` / `return_call_ref` target expression has a known direct `ref.func` fallthrough value but may also contain target-side effects that must still execute?

## Classification

Completed narrow positive `[O4Z-AUDIT-OI-H]` sub-slice: Starshine now rewrites zero-argument `call_ref` and `return_call_ref` sites whose callee-reference child is a block ending in a direct `ref.func` into a dropped target expression followed by a direct `call` or `return_call`.

This deliberately matches the Binaryen-observed effect-preserving shape for the local covered family: the target expression is still evaluated and dropped, so target-side effects and traps remain before the direct call, while the actual dynamic call target becomes known. Argument-bearing forms remain outside this sub-slice because moving the direct call after a dropped target expression would reorder already-evaluated call arguments; they need the same future localization support as argument-bearing select-known-target lowering.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitCallRef(...)` to `[O4Z-AUDIT-OI-H]`, including `ref.func` direct call, `table.get` indirect call, fallthrough-known direct target, and select-of-known targets.
- Earlier OI-H notes cover direct `ref.func`, direct `table.get`, zero-argument select-of-`ref.func`, and the argument-bearing select localization boundary.
- Local Binaryen oracle probe with `wasm-opt version_130` confirmed the fallthrough-known spelling:
  - `call_ref $target (block (result (ref $target)) (call $side (local.get 0)) (ref.func $target))` becomes `drop(block ... ref.func $target); call $target`.
  - the same target under `return_call_ref $target` becomes `drop(block ... ref.func $target); return_call $target`.

Probe command:

```sh
wasm-opt .tmp/oi-h-fallthrough-call-ref.wat --enable-gc --enable-reference-types --enable-tail-call --optimize-instructions -S --print
```

## Implementation

- Added `optimize_instructions_try_directize_fallthrough_ref_func_call_ref(...)` in `src/passes/optimize_instructions.mbt`.
- The new branch runs from `optimize_instructions_try_directize_ref_func_call_ref(...)` only when:
  - the node is a `CallRef` or `ReturnCallRef`;
  - the callee-reference child is live;
  - there are zero call arguments;
  - the callee-reference child is a `Block` whose last root is a live `RefFunc`.
- The rewrite builds a new block:
  - first root: `drop` of the original target expression, preserving target-side effects and traps;
  - second root: direct `call` or `return_call` to the known fallthrough `ref.func` target.
- The existing direct `ref.func`, `table.get`, and zero-argument `select` directization branches remain unchanged.

## Tests

Added `optimize-instructions directizes fallthrough ref.func call_ref targets and preserves target effects` in `src/passes/optimize_instructions_test.mbt`.

The direct-core fixture declares:

- target type `(result i32)`;
- side-effect helper type `(param i32)`;
- caller type `(param i32) (result i32)`;
- one target function returning a constant;
- one side-effect helper that consumes the caller parameter;
- one `call_ref` caller and one `return_call_ref` caller whose target is a typed block containing the side-effect helper call followed by `ref.func` of the target.

The test asserts that both optimized callers preserve the side-effect helper call, replace `call_ref` / `return_call_ref` with direct `call` / `return_call`, and keep the dropped target block's `ref.func` as part of the effect-preserving target evaluation.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fallthrough ref.func call_ref*'
# Failed before implementation: optimized caller still contained the target block followed by call_ref.
```

Final focused evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fallthrough ref.func call_ref*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*call_ref*'
# Total tests: 5, passed: 5, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 135, passed: 135, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2647, passed: 2647, failed: 0.

moon build --target native --release src/cmd
# Finished with existing pass_manager unused-function warnings.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

Command:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-fallthrough-call-ref-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-fallthrough-call-ref-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `56/10000`
- normalized matches: `28`
- cleanup-normalized matches: `0`
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- jobs: `16`
- cache: wasm-smith `29` hits / `0` misses; Binaryen `56` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new `call_ref` semantic failures. Grepping final failure WAT/text artifacts for `call_ref`, `return_call_ref`, `ref.func`, `select`, `call_indirect`, and `return_call_indirect` found no WAT/text occurrences; raw grep hits were JSON `selected_profile` metadata only.

## Remaining OI-H work

`[O4Z-AUDIT-OI-H]` remains open for:

- a future positive argument-bearing select-of-known-targets lowering that localizes already-evaluated arguments before introducing the `if`;
- broader type/effect negatives around fallthrough-known and select-known-target shapes;
- any unsupported `return_call_ref` surface if future fixtures expose representation gaps.

This slice closes only the zero-argument fallthrough-known direct-target family with preserved target-side effects.
