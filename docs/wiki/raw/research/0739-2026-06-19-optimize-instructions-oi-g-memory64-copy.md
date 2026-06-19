# Optimize-instructions OI-G memory64 copy fixture slice

## Question

Can the existing exact tiny `memory.copy` lowering be covered for memory64 modules, and what remains blocked for memory64 bulk-memory fixtures?

## Classification

This is the eighth `[O4Z-AUDIT-OI-G]` sub-slice. It is mostly a fixture/evidence slice rather than a new transform: `optimize_instructions_const_memory_size(...)` already accepts nonnegative `i64.const` sizes that fit in the local `Int` range, and `optimize_instructions_try_expand_tiny_memory_copy(...)` already rebuilds exact load/store pairs through `MemArg` and the original memory index. What was missing was a fixture proving that the lowered copy remains valid when the selected memory is memory64 and the destination/source addresses are `i64`.

The slice deliberately uses direct core module construction instead of WAT text. A first attempted WAT fixture with `(memory i64 1)` failed in the local WAST parser with `expected minimum limit`, even though `wasm-tools parse` accepts that syntax. That confirms the existing WAST text-surface gap for memory64 authoring and keeps direct core/binary fixtures as the right local evidence layer for this sub-slice.

## Test changes

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions expands memory64 tiny memory.copy preserving i64 addresses`.
  - Builds a direct core module with `MemType::new(Limits::i64(1UL, None))` and a function taking two `i64` address params.
  - Covers `i64.const 1` and `i64.const 8` length operands.
  - Asserts `memory.copy` disappears and the lowered instruction order preserves the `i64` address operands before `i32.load8u`/`i32.store8` and `i64.load`/`i64.store`.
- Added `optimize-instructions keeps memory64 memory.copy outside exact tiny lowering boundary`.
  - Covers an oversized constant length `i64.const 2147483648` and a nonconstant `i64` length.
  - Asserts both `memory.copy` instructions remain and no exact load lowering appears.
  - This is an intentional fail-closed boundary for the exact tiny lowering proof.

No implementation change was required: the existing lowering already had the needed memory-index and address-width preservation for memory64 copies. The initial WAT-based attempt and a string-spelling assertion mismatch both failed before the final direct-core fixtures passed; no red implementation failure was expected once the right fixture layer was selected.

## Memory64 fill caveat

This slice does **not** claim memory64 `memory.fill` coverage. A direct core attempt using a memory64 module and `i64` length operands for `memory.fill` currently fails local validation with `func[0]: type mismatch`. That matches the previously noted `typecheck_memory_fill(...)` memory64 length caveat. Memory64 fill coverage should stay open until the validator/typechecker surface is clarified or fixed in its own slice.

## Focused evidence

Commands run:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory64*'
```

Result:

```text
Total tests: 2, passed: 2, failed: 0.
```

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
```

Result:

```text
Total tests: 14, passed: 14, failed: 0.
```

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Result:

```text
Total tests: 115, passed: 115, failed: 0.
```

## Broader validation

```sh
moon fmt
```

Passed.

```sh
moon test src/passes
```

Result:

```text
Total tests: 2627, passed: 2627, failed: 0.
```

```sh
moon build --target native --release src/cmd
```

Passed with `moon: no work to do`.

```sh
moon info
```

Passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Direct compare evidence

Command:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-memory64-copy-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `53/10000`
- normalized matches: `26`
- cleanup-normalized matches: `0`
- raw mismatches: `27`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- jobs: `16`
- cache: wasm-smith `27` hits / `0` misses; Binaryen `53` hits / `0` misses; Binaryen failures `1` hit / `0` misses
- command failure class: `binaryen-rec-group-zero` (`1`)

Agent classification:

- Command failure: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).
- Raw mismatches: known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI-E/OI-F work, not new memory64-copy semantic failures.
- A grep of failure artifacts found `0` occurrences of `memory.copy` or `memory.fill`.
- Sample canonical wasm sizes still favored Starshine for the familiar mismatch family:
  - `case-000002-gen-valid`: Binaryen `4161` bytes vs Starshine `4120`
  - `case-000004-gen-valid`: Binaryen `5539` bytes vs Starshine `5481`
  - `case-000006-gen-valid`: Binaryen `5559` bytes vs Starshine `5496`

## Remaining OI-G work

This sub-slice does not close `[O4Z-AUDIT-OI-G]`. Remaining OI-G work includes:

- memory64 `memory.fill` coverage after the local validator/typechecker memory64 length caveat is resolved or explicitly classified;
- general load/store canonicalization;
- effect/trap negatives for additional fill/copy/load/store cases where useful;
- decision on whether any memory/load/call shapes should escape the current `load-call-optimize-instructions-noop` raw gate.

Zero-size `memory.copy` and `memory.fill` cleanup remains blocked unless Starshine grows explicit local ignore-traps / TNH / IIT-equivalent mode support or the user accepts a different trap-mode policy with focused tests.
