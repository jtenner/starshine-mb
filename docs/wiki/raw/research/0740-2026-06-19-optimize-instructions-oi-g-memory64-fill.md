# Optimize-instructions OI-G memory64 fill validator and fixture slice

## Question

Can the OI-G memory64 `memory.fill` caveat be resolved and covered with a direct-core optimizer fixture?

## Classification

This is the ninth `[O4Z-AUDIT-OI-G]` sub-slice. It resolves the previously documented local validator/typechecker blocker for memory64 `memory.fill`: `typecheck_memory_fill(...)` used the selected memory address type for the destination but still required the length operand to be `i32`. For memory64, `memory.fill` length is address-typed like the destination, so direct-core modules with `i64` destination and `i64` length failed local validation before the optimizer could run.

The optimizer implementation did not need a new transform. Once validation accepts the memory64 operand stack, the existing exact tiny fill lowering already consumes `i64.const` sizes through `optimize_instructions_const_memory_size(...)` and preserves the original memory index/address operand when replacing `memory.fill` with an exact store.

## Test and implementation changes

Changed `src/validate/typecheck.mbt`:

- Updated `typecheck_memory_fill(...)` to pop `len:at`, `val:i32`, `dst:at`, where `at` is the selected memory's address type.
- Added `Typecheck MemoryFill memory64 length uses address type` to lock the memory64 stack shape `[i64, i32, i64]`.

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions expands memory64 tiny memory.fill preserving i64 address and length`.
- The fixture uses direct core module construction with `MemType::new(Limits::i64(1UL, None))`, one `i64` destination param, one `i32` fill-value param, and two `memory.fill` roots with `i64.const 1` and `i64.const 8` lengths.
- The test validates the input module, runs `optimize-instructions`, asserts `memory.fill` disappears, and checks the lowered order preserves the `i64` destination operand before `i32.store8` and `i64.store`.

## Red-first evidence

Before the typechecker fix, the new focused memory64 optimizer fixture failed during input validation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory64*'
```

Result excerpt:

```text
[jtenner/starshine] test passes/optimize_instructions_test.mbt:990 ("optimize-instructions expands memory64 tiny memory.fill preserving i64 address and length") failed: ... expected valid memory64 memory.fill input, got func[0]: type mismatch
Total tests: 3, passed: 2, failed: 1.
```

## Focused evidence

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory64*'
```

Result:

```text
Total tests: 3, passed: 3, failed: 0.
```

```sh
moon test --target native src/validate/typecheck.mbt --filter '*MemoryFill*'
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
Total tests: 15, passed: 15, failed: 0.
```

## Broader validation

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Result:

```text
Total tests: 116, passed: 116, failed: 0.
```

```sh
moon fmt
```

Passed.

```sh
moon test src/passes
```

Result:

```text
Total tests: 2628, passed: 2628, failed: 0.
```

```sh
moon test src/validate
```

Result:

```text
Total tests: 1611, passed: 1611, failed: 0.
```

```sh
moon build --target native --release src/cmd
```

Passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.

```sh
moon info
```

Passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Direct compare evidence

Command:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-memory64-fill-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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
- command failure class: `binaryen-rec-group-zero` (`1`)

Agent classification:

- Command failure: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).
- Raw mismatches: known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI-E/OI-F work, not new memory64-fill semantic failures.
- A grep of failure artifacts found `0` occurrences of `memory.copy` or `memory.fill`.
- Sample canonical wasm sizes still favored Starshine for the familiar mismatch family:
  - `case-000002-gen-valid`: Binaryen `4161` bytes vs Starshine `4120`
  - `case-000004-gen-valid`: Binaryen `5539` bytes vs Starshine `5481`
  - `case-000006-gen-valid`: Binaryen `5559` bytes vs Starshine `5496`

## Remaining OI-G work

This sub-slice does not close `[O4Z-AUDIT-OI-G]`. Remaining OI-G work includes:

- general load/store canonicalization;
- any further useful effect/trap negatives around memory/fill/copy/load/store shapes;
- decision on whether any memory/load/call shapes should escape the current `load-call-optimize-instructions-noop` raw gate.

Zero-size `memory.copy` and `memory.fill` cleanup remains blocked unless Starshine grows explicit local ignore-traps / TNH / IIT-equivalent mode support or the user accepts a different trap-mode policy with focused tests.
