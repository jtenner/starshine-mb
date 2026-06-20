# Optimize-instructions OI-I upcast ref.eq

Date: 2026-06-20

## Slice

Twenty-fourth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This sub-slice widens the same-local nullable `ref.cast` equality proof from exact same-heap no-op casts to a narrow absolute-heap nullable upcast:

```wat
local.get 0 ;; (ref null struct)
ref.cast (ref null eq)
local.get 0
ref.eq
```

and the both-operands variant where both sides are immediate nullable upcasts from the same local. A nullable upcast from absolute `struct` / `array` to an accepted absolute supertype preserves the reference identity and accepts null, so comparing the cast result against the original same local is always true.

## Binaryen oracle

Probe file: `.tmp/oi-upcast-ref-eq-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-upcast-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output folded both exported functions to a shared body containing only `i32.const 1`.

A smaller absolute-heap probe `.tmp/oi-abs-struct-upcast-ref-eq-probe.wat` confirmed the same fold for a `(ref null struct)` parameter cast to `(ref null eq)`.

## Starshine change

Updated `src/passes/optimize_instructions_test.mbt` with direct-core coverage for same-local equality through nullable upcast `ref.cast` from absolute `struct` to `eq`, covering both one-cast and both-cast operand shapes.

Updated `optimize_instructions_ref_eq_same_local_operand(...)` so nullable `ref.cast(local.get N)` can participate in the same-local identity proof when the cast target is either:

- exactly the local declared heap, or
- an accepted absolute `struct` / `array` supertype target from the existing aggregate helper.

## TDD note

Red-first was captured with:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable upcast ref.cast*'
```

The new test failed because the optimized function still contained the `ref.eq` / cast shape. After implementation the same focused test passed.

## Boundaries

This is still a narrow same-local identity proof. It does not add:

- arbitrary cast skipping,
- non-null target cast removal for nullable locals,
- indexed/defined heap subtype reasoning,
- local.set-derived or SSA value identity,
- descriptor/exactness/TNH/IIT-sensitive cast behavior,
- constructor allocation identity or allocation dropping,
- broader nullable-local flow facts.

The implemented widening is limited to immediate nullable `ref.cast(local.get N)` nodes whose target is an already-modeled absolute supertype of the local's declared absolute heap.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-upcast-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Folded one-cast and both-cast same-local upcast equality shapes to `i32.const 1`.
- Red-first focused test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable upcast ref.cast*'`
  - Failed before implementation because `ref.eq` remained.
- Focused tests after implementation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable upcast ref.cast*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 31, passed: 31, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 161, passed: 161, failed: 0.`

- `moon fmt`
  - Passed.
- `moon test src/passes`
  - Passed: `Total tests: 2673, passed: 2673, failed: 0.`
- `moon build --target native --release src/cmd`
  - Passed with existing pass-manager unused-function warnings.
- `moon info`
  - Passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check`
  - Passed.
- Direct compare:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-upcast-ref-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-upcast-ref-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `10000`, compared `55/10000`.
  - Normalized matches: `27`.
  - Cleanup-normalized matches: `0`.
  - Compare-normalized matches: CLI `0`, `result.json` key `null`.
  - Raw mismatches: `28`.
  - Validation/property/generator failures: `0`.
  - Command failures: `1`, classified as the known cached Binaryen/tool `binaryen-rec-group-zero` failure.
  - Cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses.
  - Agent classification: the `28` raw mismatches are the known Starshine-win constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures.
  - Grep of final failure artifacts found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
