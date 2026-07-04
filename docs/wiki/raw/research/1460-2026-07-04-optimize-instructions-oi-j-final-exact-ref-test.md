# OI-J final-heap exact `ref.test` slice

Date: 2026-07-04

## Scope

This finite OI-J exactness/useful-type-info slice tightens ordinary exact `ref.test` behavior for same-heap inexact operands:

```wat
(module
  (type $f (sub final (struct (field i32))))
  (type $open (sub (struct (field i32))))
  (func $test-final (param $x (ref $f)) (result i32)
    (ref.test (ref (exact $f)) (local.get $x)))
  (func $test-open (param $x (ref $open)) (result i32)
    (ref.test (ref (exact $open)) (local.get $x)))
)
```

Binaryen `version_130` folds same-heap inexact `ref.test` to true only when the source heap is final, because no strict-subtype value can appear at runtime. The same predicate on an explicit non-final `(sub ...)` heap stays as `ref.test` because a future strict subtype may fail the exact target. Starshine now matches that distinction: exact tests on already-exact operands still fold to true, final-heap inexact operands fold to true when nullability makes every possible value match, nullable final operands tested against non-null exact targets lower to the existing null check, and non-final same-heap inexact operands remain fail-closed.

Out of scope: exact `ref.cast` erasure on final heaps, descriptor casts, `ref.test_desc`, descriptor BrOn variants, arbitrary useful-type-info beyond exact/final/subtype/null-only proofs, TNH/IIT behavior, and generalized descriptor effect/control localization.

## Binaryen evidence

Probe directory: `.tmp/oi-j-next-probes/final-exact-target-20260704/`.

Commands:

```text
wasm-tools validate --features all .tmp/oi-j-next-probes/final-exact-target-20260704/input.wat
wasm-opt --all-features .tmp/oi-j-next-probes/final-exact-target-20260704/input.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/final-exact-target-20260704/binaryen.wat
wasm-tools validate --features all .tmp/oi-j-next-probes/final-exact-target-20260704/input2.wat
wasm-opt --all-features .tmp/oi-j-next-probes/final-exact-target-20260704/input2.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/final-exact-target-20260704/binaryen2.wat
```

Observed Binaryen behavior:

- non-null `(ref $f)` tested against `(ref (exact $f))` folds to dropped operand plus `i32.const 1`;
- nullable `(ref null $f)` tested against `(ref null (exact $f))` folds to dropped operand plus `i32.const 1`;
- nullable `(ref null $f)` tested against non-null `(ref (exact $f))` lowers to `i32.eqz(ref.is_null(x))`;
- final-heap exact casts remain as `ref.cast (ref (exact $f))` / `ref.cast (ref null (exact $f))`;
- explicit non-final same-heap `(ref $open)` tested against `(ref (exact $open))` remains `ref.test`.

## Implementation

`src/passes/optimize_instructions.mbt` adds a final-heap proof for exact `ref.test` success:

- `optimize_instructions_heap_is_final(...)` recognizes concrete final heaps from module subtype metadata, including compact `CompTypeSubType` entries and explicit `SubType(true, ...)` entries.
- `optimize_instructions_ref_operand_matches_final_exact_test_target(...)` proves that every possible operand value matches the exact target when the operand heap equals the target heap, the target is nullable or the operand is non-null, and the heap is final.
- The ordinary successful-test path no longer uses broad inexact heap matches when the target immediate is exact. Exact targets now require an already-exact operand or the final-heap proof. This keeps explicit non-final same-heap exact tests fail-closed.
- The existing nullable-source/non-null-target rewrite can use the final-heap proof to lower nullable final exact tests to `ref.is_null`/`eqz` instead of leaving a redundant exact heap test.

The implementation deliberately does not apply the final-heap proof to `ref.cast`: local Binaryen keeps final-heap exact casts, so Starshine keeps them too unless a future source-backed slice proves another cast behavior.

## Tests

Added red-first focused tests:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions keeps non-final inexact exact ref.test checks`
- `src/passes/optimize_instructions_test.mbt::optimize-instructions folds final heap exact ref.test matches`

Red results before the final implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions keeps non-final inexact exact ref.test checks'
=> failed because Starshine folded the non-final exact test to dropped operand plus i32.const 1

moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds final heap exact ref.test matches'
=> failed with residual ref.test on the effectful nullable-final exact-target case before the final-heap proof was added
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*exact ref.test*'
=> Total tests: 6, passed: 6, failed: 0.
```

The existing `optimize-instructions folds exact ref.test on already exact operands` test was corrected so its inexact same-heap positive uses a final heap, matching the Binaryen probe that motivated that older claim. The new boundary test locks explicit non-final `(sub ...)` heaps as non-foldable.

## Validation

Completed in this slice:

- Binaryen probe commands above passed.
- Red-first focused tests above failed before the implementation/final boundary correction.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*exact ref.test*'` passed `6/6`.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- Full `moon test` passed `7434/7434`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Probe replay using `wasm-tools parse`, native `cmd.exe --optimize-instructions`, `wasm-tools validate --features all`, and `wasm-tools print` emitted validating Starshine output matching Binaryen's final/non-final split: final exact tests folded, explicit non-final exact test remained, nullable-final-to-non-null became `ref.is_null`/`eqz`, and final exact casts remained.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-final-exact-ref-test-genvalid-10000-20260704 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache hits/misses `10000/0`.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice fixes the same-heap exact `ref.test` breadth around final versus explicit non-final heaps, but does not close descriptor-cast behavior, useful-type-info and exactness breadth beyond exact/final/strict-subtype/null-only proofs, broader TNH/IIT escaping/control descriptor surfaces, arbitrary ordinary cast targets, escaping labels, payload prefixes, effectful/control operands, EH/control descriptor surfaces, multivalue children, or generalized descriptor effect/control localization. The `ref.test_desc` and descriptor BrOn forms remain the unsupported/tooling/representation boundaries documented in note `1456`.
