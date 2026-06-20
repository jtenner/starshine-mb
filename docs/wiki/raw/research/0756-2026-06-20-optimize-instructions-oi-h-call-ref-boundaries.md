# Optimize-instructions OI-H call_ref boundary negatives

## Question

Which remaining Starshine `call_ref` directization boundaries should be locked before moving beyond the currently implemented `visitCallRef(...)` subset?

## Classification

Completed fail-closed `[O4Z-AUDIT-OI-H]` boundary sub-slice. This slice does not add a new positive transform. It adds direct-core tests proving that Starshine intentionally keeps two unsupported `call_ref` families unchanged:

1. typed `select` callees where at least one arm is not a direct `ref.func`; and
2. fallthrough-known block targets on argument-bearing `call_ref` / `return_call_ref` sites.

The first boundary keeps the current select lowering honest: the implemented local proof only handles select arms that are both direct `ref.func` nodes. The second boundary prevents a wrong extension of the zero-argument fallthrough lowering. For argument-bearing calls, the target expression is evaluated after the call arguments in the original stack order; replacing it with `drop(target); direct-call(args...)` without first localizing arguments would reorder evaluation.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitCallRef(...)` to `[O4Z-AUDIT-OI-H]` and records known-target directization as upstream-owned optimize-instructions surface.
- `src/passes/optimize_instructions.mbt` currently requires both select arms to be direct `RefFunc` nodes before select-known-target lowering, localizes only single-result call arguments for the covered select subset, and requires `args.length() == 0` before fallthrough-known block directization.
- `docs/wiki/raw/research/0755-2026-06-20-optimize-instructions-oi-h-argument-select-call-ref-localization.md` records why argument localization is required before introducing a direct-call `if` for argument-bearing select targets. The same evaluation-order issue blocks a naive argument-bearing fallthrough lowering.

## Tests

Added two fail-closed tests in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps select call_ref when an arm is not direct ref.func`
  - direct-core fixture with a typed select between a direct `ref.func` and a `table.get` result;
  - asserts the optimized caller still contains `call_ref`, `select`, `table.get`, and `ref.func`.
- `optimize-instructions intentionally keeps argument fallthrough call_ref targets`
  - direct-core fixture with both `call_ref` and `return_call_ref` consuming an effectful argument expression and a fallthrough block target that performs a target-side call before `ref.func`;
  - asserts both callers still contain `call_ref` / `return_call_ref`, both effect calls, and `ref.func`.

Focused evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*intentionally keeps*call_ref*'
# Total tests: 2, passed: 2, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*call_ref*'
# Total tests: 7, passed: 7, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 137, passed: 137, failed: 0.
```

These are boundary tests, so no red-first implementation failure was required; the test names explicitly mark the unsupported behavior as intentional.

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2649, passed: 2649, failed: 0.

moon build --target native --release src/cmd
# Finished; no work to do.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

Command:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-call-ref-boundaries-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-call-ref-boundaries-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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

Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new `call_ref` semantic failures. Grepping final failure WAT/text artifacts for `call_ref`, `return_call_ref`, `ref.func`, `select`, `call_indirect`, `return_call_indirect`, and `table.get` found no occurrences.

## Remaining OI-H work

`[O4Z-AUDIT-OI-H]` remains open. This slice locks local unsupported boundaries; it does not prove full upstream `visitCallRef(...)` parity. Remaining useful work includes any further source-backed known-target shapes beyond the direct `ref.func`, `table.get`, direct-`ref.func` select, localized single-result select-argument, and zero-argument fallthrough-known block subsets already covered.
