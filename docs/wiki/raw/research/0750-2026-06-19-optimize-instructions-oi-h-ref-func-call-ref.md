# Optimize-instructions OI-H ref.func call_ref directization

## Question

Does Starshine's `optimize-instructions` cover Binaryen `version_130` `visitCallRef(...)` for the simplest known-target family, where a `call_ref` / `return_call_ref` consumes a direct `ref.func` target?

## Classification

Completed narrow positive `[O4Z-AUDIT-OI-H]` sub-slice: Starshine now rewrites direct `ref.func` targets under `call_ref` and `return_call_ref` to direct `call` and `return_call` respectively.

This is intentionally only the `ref.func` known-target subset. `table.get` to indirect call, fallthrough-known direct targets with target-side effects, select-of-known-targets lowering, and type/effect negatives remain open under `[O4Z-AUDIT-OI-H]`.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitCallRef(...)` to `[O4Z-AUDIT-OI-H]`, including `ref.func` direct call, `table.get` indirect call, fallthrough-known direct target, and select-of-known targets.
- Local Binaryen oracle probe with `wasm-opt version_130` confirmed the covered spelling:
  - `local.get; ref.func $target; call_ref $t0` becomes `call $target`.
  - `local.get; ref.func $target; return_call_ref $t0` becomes `return_call $target`.

Probe command:

```sh
wasm-opt .tmp/oi-h-call-ref-direct.wat --enable-gc --enable-reference-types --enable-tail-call --optimize-instructions -S --print | grep -E 'func|call|ref.func|local.get|return_call'
```

## Implementation

- Added `optimize_instructions_try_directize_ref_func_call_ref(...)` in `src/passes/optimize_instructions.mbt`.
- The matcher only accepts `CallRef` / `ReturnCallRef` nodes whose final callee-reference child is a live `RefFunc` node.
- The rewrite preserves argument children in order, drops only the pure `ref.func` callee child, and rebuilds the node as direct `Call` / `ReturnCall` to the referenced function index.
- The direct `Call` preserves the original result type list via `@ir.hot_type_results(...)`; `ReturnCall` remains void/terminal.

## Tests

Added `optimize-instructions directizes ref.func call_ref targets` in `src/passes/optimize_instructions_test.mbt`.

The fixture uses direct core builders rather than WAT text because Starshine's high-level WAST parser still lacks ordinary `call_ref` text support. The module declares a function type, a target function, a declarative element for `ref.func` validity, one `call_ref` caller, and one `return_call_ref` caller. The test asserts the optimized output contains direct `call (Func 0)` / `return_call (Func 0)` and no longer contains `call_ref`, `return_call_ref`, or `ref.func` in those functions.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.func call_ref*'
```

failed before implementation with the caller still containing `local.get`, `ref.func`, and `call_ref`.

Final focused evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.func call_ref*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*call_ref*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 131, passed: 131, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2643, passed: 2643, failed: 0.

moon build --target native --release src/cmd
# Finished with existing pass_manager unused-function warnings.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

The first direct compare command timed out after 600 seconds before writing `result.json`:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-ref-func-call-ref-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-ref-func-call-ref-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

The rerun completed to the default failure ceiling:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-ref-func-call-ref-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-ref-func-call-ref-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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

Agent mismatch classification: the `27` raw mismatches are the known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new `call_ref` semantic failures. Grepping the final failure artifacts for `call_ref`, `return_call_ref`, `ref.func`, `call_indirect`, and `return_call_indirect` found no occurrences.

## Remaining OI-H work

`[O4Z-AUDIT-OI-H]` remains open for:

- `table.get` target to `call_indirect` / `return_call_indirect`;
- fallthrough-known direct target with preserved target-side effects;
- select-of-known-targets lowering;
- type/effect negatives around those broader shapes;
- any unsupported `return_call_ref` surface if future fixtures expose representation gaps.

`[O4Z-AUDIT-OI-G]` also remains active for any further memory/load-store work listed in `agent-todo.md`.
