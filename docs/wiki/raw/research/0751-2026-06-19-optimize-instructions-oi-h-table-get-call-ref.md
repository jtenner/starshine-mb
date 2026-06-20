# Optimize-instructions OI-H table.get call_ref indirectization

## Question

Does Starshine's `optimize-instructions` cover the Binaryen `version_130` `visitCallRef(...)` family where a `call_ref` / `return_call_ref` consumes a function reference loaded with `table.get`?

## Classification

Completed narrow positive `[O4Z-AUDIT-OI-H]` sub-slice: Starshine now rewrites `table.get` targets under `call_ref` and `return_call_ref` to `call_indirect` and `return_call_indirect` respectively.

This is intentionally only the direct `table.get` target subset. Fallthrough-known direct targets with preserved target-side effects, select-of-known-targets lowering, and broader type/effect negatives remain open under `[O4Z-AUDIT-OI-H]`.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitCallRef(...)` to `[O4Z-AUDIT-OI-H]`, including `ref.func` direct call, `table.get` indirect call, fallthrough-known direct target, and select-of-known targets.
- Local Binaryen oracle probe with `wasm-opt version_130` confirmed the covered spelling:
  - `local.get; i32.const 0; table.get 0; call_ref $t0` becomes `call_indirect 0 (type $t0)`.
  - `local.get; i32.const 0; table.get 0; return_call_ref $t0` becomes `return_call_indirect 0 (type $t0)`.

Probe command:

```sh
wasm-opt .tmp/oi-h-table-get-call-ref.wat --enable-gc --enable-reference-types --enable-tail-call --optimize-instructions -S --print | grep -E 'func|call|ref.func|table.get|return_call|call_indirect|local.get|i32.const'
```

The probe needed a typed function table:

```wat
(table 1 (ref null $t0))
(elem (i32.const 0) (ref null $t0) (item (ref.func $target)))
```

## Implementation

- Extended `optimize_instructions_try_directize_ref_func_call_ref(...)` in `src/passes/optimize_instructions.mbt`.
- The matcher still only accepts `CallRef` / `ReturnCallRef` nodes whose final callee-reference child is live.
- For a final `TableGet` child with one live index child, the rewrite:
  - preserves argument children in order;
  - reuses the `table.get` index child as the indirect-call callee index;
  - copies the `call_ref` type index from the HOT call signature;
  - copies the table index from the `table.get` immediate;
  - rebuilds as `CallIndirect` / `ReturnCallIndirect` and drops the now-redundant `table.get` node from the call tree.
- The direct `ref.func` branch from `0750` remains unchanged.

## Tests

Added `optimize-instructions lowers table.get call_ref targets to indirect calls` in `src/passes/optimize_instructions_test.mbt`.

The fixture uses direct core builders because Starshine's high-level WAST parser still lacks ordinary `call_ref` text support. The module declares a `(i32)->(i32)` type, a typed nullable function-reference table, an active typed element segment containing `ref.func 0`, one direct target function, one `call_ref` caller, and one `return_call_ref` caller. The test asserts the optimized callers contain `call_indirect (Type 0) (Table 0)` / `return_call_indirect (Type 0) (Table 0)` and no longer contain `call_ref`, `return_call_ref`, or `table.get`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*table.get call_ref*'
```

failed before implementation with the caller still containing `local.get`, `i32.const`, `table.get`, and `call_ref`.

Final focused evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*table.get call_ref*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*call_ref*'
# Total tests: 2, passed: 2, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 132, passed: 132, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2644, passed: 2644, failed: 0.

moon build --target native --release src/cmd
# Finished with existing pass_manager unused-function warnings.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-table-get-call-ref-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-table-get-call-ref-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `54/10000`
- normalized matches: `27`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- raw mismatches: `27`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `54` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `27` raw mismatches are the known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new `call_ref` semantic failures. Grepping the final failure artifacts for `call_ref`, `return_call_ref`, `table.get`, `ref.func`, `call_indirect`, and `return_call_indirect` found no occurrences.

## Remaining OI-H work

`[O4Z-AUDIT-OI-H]` remains open for:

- fallthrough-known direct targets with preserved target-side effects;
- select-of-known-targets lowering;
- type/effect negatives around those broader shapes;
- any unsupported `return_call_ref` surface if future fixtures expose representation gaps.

`[O4Z-AUDIT-OI-G]` also remains active for any further memory/load-store work listed in `agent-todo.md`.
