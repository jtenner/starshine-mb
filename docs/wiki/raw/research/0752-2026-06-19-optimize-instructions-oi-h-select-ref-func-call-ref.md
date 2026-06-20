# Optimize-instructions OI-H select ref.func call_ref lowering

## Question

Does Starshine's `optimize-instructions` cover the Binaryen `version_130` `visitCallRef(...)` family where a `call_ref` / `return_call_ref` consumes a typed `select` whose arms are known direct `ref.func` targets?

## Classification

Completed narrow positive `[O4Z-AUDIT-OI-H]` sub-slice: Starshine now rewrites zero-argument `select(ref.func A, ref.func B, cond)` targets under `call_ref` and `return_call_ref` into an `if` that directly calls or tail-calls the selected function.

This is intentionally the zero-argument direct-target subset. Binaryen can localize arguments to preserve evaluation order for broader arities; Starshine does not yet implement that localizing form here, so fallthrough-known direct targets with preserved target-side effects, argument-bearing select-of-known-targets lowering, and broader type/effect negatives remain open under `[O4Z-AUDIT-OI-H]`.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitCallRef(...)` to `[O4Z-AUDIT-OI-H]`, including `ref.func` direct call, `table.get` indirect call, fallthrough-known direct target, and select-of-known targets.
- Local Binaryen oracle probe with `wasm-opt version_130` confirmed the covered zero-argument spelling:
  - `ref.func $a; ref.func $b; local.get 0; select (result (ref $t0)); call_ref $t0` becomes an `if (result i32)` with direct `call $a` / `call $b` arms.
  - the same target under `return_call_ref $t0` becomes an `if` with direct `return_call $a` / `return_call $b` arms.

Probe command:

```sh
wasm-opt .tmp/oi-h-select-call-ref-noargs.wat --enable-gc --enable-reference-types --enable-tail-call --optimize-instructions -S --print
```

A broader argument-bearing probe showed Binaryen first localizes the already-evaluated argument before moving the condition into the `if`; this is why the Starshine slice is limited to zero-argument calls until a localizing lowering is added.

## Implementation

- Extended `optimize_instructions_try_directize_ref_func_call_ref(...)` in `src/passes/optimize_instructions.mbt`.
- The matcher still only accepts `CallRef` / `ReturnCallRef` nodes whose final callee-reference child is live.
- Existing direct `RefFunc` and direct `TableGet` branches remain in force.
- New `Select` branch requires:
  - zero call arguments, avoiding argument duplication or evaluation-order changes;
  - exactly three live select children;
  - both select value arms are direct `RefFunc` nodes.
- The rewrite builds:
  - `call_ref` as an `if` with the original condition and one direct `call` per arm;
  - `return_call_ref` as a void `if` with one direct `return_call` per arm.
- Because the helper now replaces a plain call node with an `if` control node for this branch, it rehomes the generated control label to the replacement node before deleting the temporary node.

## Tests

Added `optimize-instructions lowers select ref.func call_ref targets to direct if calls` in `src/passes/optimize_instructions_test.mbt`.

The fixture uses direct core builders because Starshine's high-level WAST parser still lacks ordinary `call_ref` text support. The module declares a zero-argument `(result i32)` target type and a `(param i32) (result i32)` caller type, two target functions, one `call_ref` caller, and one `return_call_ref` caller. Each caller selects between `ref.func 0` and `ref.func 1` using its condition parameter. The test asserts the optimized callers contain an `if` with direct calls or tail calls to both targets and no longer contain `call_ref`, `return_call_ref`, `select`, or `ref.func`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*select ref.func call_ref*'
```

failed before implementation with the caller still containing `ref.func`, typed `select`, and `call_ref`.

Final focused evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*select ref.func call_ref*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*call_ref*'
# Total tests: 3, passed: 3, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 133, passed: 133, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2645, passed: 2645, failed: 0.

moon build --target native --release src/cmd
# Finished with existing pass_manager unused-function warnings.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

The first direct compare attempt timed out before writing `result.json`. The clean rerun was:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-select-ref-func-call-ref-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-select-ref-func-call-ref-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `56/10000`
- normalized matches: `28`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- jobs: `16`
- cache: wasm-smith `29` hits / `0` misses; Binaryen `56` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are the known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new `call_ref` semantic failures. Grepping final failure WAT/text artifacts for `call_ref`, `return_call_ref`, `ref.func`, `select`, `table.get`, `call_indirect`, and `return_call_indirect` found no occurrences.

## Remaining OI-H work

`[O4Z-AUDIT-OI-H]` remains open for:

- fallthrough-known direct targets with preserved target-side effects;
- argument-bearing select-of-known-targets lowering, including Binaryen-style argument localization;
- type/effect negatives around those broader shapes;
- any unsupported `return_call_ref` surface if future fixtures expose representation gaps.

`[O4Z-AUDIT-OI-G]` also remains active for any further memory/load-store work listed in `agent-todo.md`.
