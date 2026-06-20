# Optimize-instructions OI-H argument select call_ref localization

## Question

Can Starshine safely cover the Binaryen `version_130` `visitCallRef(...)` family where a `call_ref` / `return_call_ref` has already-evaluated call arguments and a typed `select` callee whose arms are direct `ref.func` targets?

## Classification

Completed narrow positive `[O4Z-AUDIT-OI-H]` sub-slice: Starshine now rewrites argument-bearing `call_ref` and `return_call_ref` sites whose callee-reference child is a typed `select` of direct `ref.func` arms into a block that localizes the already-evaluated call arguments, then an `if` that performs direct `call` / `return_call` in each arm.

This supersedes the fail-closed boundary recorded in [`0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md`](0753-2026-06-19-optimize-instructions-oi-h-argument-select-call-ref-boundary.md) for the single-result argument subset covered here. Broader type/effect negatives remain open.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitCallRef(...)` to `[O4Z-AUDIT-OI-H]` and records select-of-known-target and localization behavior as upstream-owned optimize-instructions surface.
- Local Binaryen oracle probe with `wasm-opt version_130` confirmed the argument-bearing spelling: both `call_ref` and `return_call_ref` forms first store the argument in a temporary local, then branch on the original select condition and call the selected direct target with `local.get` of the temporary.

Probe command:

```sh
wasm-opt .tmp/oi-h-argument-select-call-ref.wat --enable-gc --enable-reference-types --enable-tail-call --optimize-instructions -S --print
```

## Implementation

- Added `optimize_instructions_call_ref_localize_args(...)` in `src/passes/optimize_instructions.mbt`.
- The helper handles only call arguments that have exactly one result type. Each argument is evaluated into a fresh appended body local, preserving the original evaluation order before the callee select condition.
- Widened the select-known-target branch in `optimize_instructions_try_directize_ref_func_call_ref(...)` from zero-argument-only to localized argument lowering:
  - direct `call_ref` becomes a result block containing argument `local.set`s followed by a result `if` with direct `call` arms;
  - `return_call_ref` becomes a void block containing argument `local.set`s followed by a void `if` with direct `return_call` arms.
- The rewrite still requires both select arms to be direct `ref.func` nodes and the condition to be live.

## Tests

Updated `optimize-instructions localizes argument select call_ref targets before direct calls` in `src/passes/optimize_instructions_test.mbt` from the previous fail-closed boundary into a positive test.

The direct-core fixture keeps one argument-bearing `call_ref` and one `return_call_ref` whose callee is a typed `select` between two direct `ref.func` targets. The test now asserts that both optimized callers contain argument localization (`local.set` / `local.get`), an `if`, and direct `call` / `return_call` arms, while removing `call_ref`, `return_call_ref`, `select`, and dead `ref.func` nodes from the caller body.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*localizes argument select call_ref*'
# Failed before implementation: optimized caller still contained select + call_ref and no localization.
```

Focused evidence after implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*localizes argument select call_ref*'
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

The first direct compare attempt timed out after 600 seconds before writing `result.json`:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-argument-select-call-ref-localization-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-argument-select-call-ref-localization-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Final rerun command:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-argument-select-call-ref-localization-10000-rerun2 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-argument-select-call-ref-localization-10000-rerun2 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `52/10000`
- normalized matches: `26`
- cleanup-normalized matches: `0`
- raw mismatches: `26`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- jobs: `16`
- cache: wasm-smith `27` hits / `0` misses; Binaryen `52` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `26` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new `call_ref` semantic failures. Grepping final failure WAT/text artifacts for `call_ref`, `return_call_ref`, `ref.func`, `select`, `call_indirect`, and `return_call_indirect` found no WAT/text occurrences; raw grep hits were JSON `selected_profile` metadata only.

## Remaining OI-H work

`[O4Z-AUDIT-OI-H]` remains open for broader type/effect negatives around select-known-target and fallthrough-known shapes, plus any unsupported `return_call_ref` surface future fixtures expose. This slice does not claim full `visitCallRef(...)` parity beyond direct `ref.func`, `table.get`, zero-argument select, localized single-result-argument select, and zero-argument fallthrough-known block targets.
