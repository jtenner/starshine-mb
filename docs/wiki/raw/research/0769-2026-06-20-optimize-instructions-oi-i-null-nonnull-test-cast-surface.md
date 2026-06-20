# Optimize-instructions OI-I non-null null-operand ref.test/ref.cast surface

## Question

Does Starshine's public validation/type surface now allow the non-null-target `ref.test` / `ref.cast` null-operand cases that Binaryen folds, so the existing `optimize-instructions` null-operand implementation can be covered directly?

## Classification

Completed thirteenth `[O4Z-AUDIT-OI-I]` reference sub-slice as a coverage/type-surface audit slice.

This slice does not add a new optimizer rewrite. It closes the previously-open public non-null null-operand `ref.test` / `ref.cast` coverage question by adding a direct-core fixture that validates through `@validate.validate_module(...)` and then runs the public hot pipeline. The existing `optimize_instructions_try_fold_ref_test_null(...)` / `optimize_instructions_try_fold_ref_cast_null(...)` behavior is now locked for:

- `ref.test (ref T)` fed by a known `ref.null T`, which folds to `i32.const 0`; and
- `ref.cast (ref T)` fed by a known `ref.null T`, which rewrites to `unreachable`.

The fixture is intentionally narrow. It only covers ordinary absolute `eq` heap targets with a literal null operand. It does not claim broader failed cast/test reasoning, descriptor casts, exactness, TNH/IIT behavior, nullable-local flow, indexed/recursive heap targets, or arbitrary subtype facts.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]` and descriptor/exactness/TNH/IIT behavior under `[O4Z-AUDIT-OI-J]`.
- `docs/wiki/raw/research/0761-2026-06-20-optimize-instructions-oi-i-null-ref-test-cast.md` recorded the nullable null-operand implementation and left public non-null null-operand coverage as a follow-up because earlier direct-core attempts were rejected by the then-current validation/type surface.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-null-nonnull-test-cast.wat <<'EOF'
(module
  (func (export "test") (result i32)
    ref.null eq
    ref.test (ref eq))
  (func (export "cast") (result (ref eq))
    ref.null eq
    ref.cast (ref eq)))
EOF
wasm-opt .tmp/oi-null-nonnull-test-cast.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded the non-null null-operand `ref.test` to `i32.const 0` and the non-null null-operand `ref.cast` to `unreachable`.

## Tests

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds non-null ref.test and ref.cast on known null refs`
  - validates a module containing `ref.null eq; ref.test (ref eq)` and `ref.null eq; ref.cast (ref eq)`;
  - runs `optimize-instructions` through the same helper used by the other direct-core OI-I fixtures;
  - asserts the test arm no longer contains `ref.test` and contains `I32(0)`; and
  - asserts the cast arm no longer contains `ref.cast` and contains `unreachable`.

The fixture uses direct core builders because the current Starshine WAT parser does not yet support ordinary `ref.test (ref T)` / `ref.cast (ref T)` text forms.

TDD note:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null ref.test*'
# Total tests: 1, passed: 1, failed: 0.
```

This was a coverage/type-surface audit slice, not a new positive implementation gap: the test passed immediately because the optimizer's non-null null-operand branch already existed and the current validator now accepts this direct-core shape. The durable result is that the previously listed public non-null null-operand coverage follow-up is no longer open.

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null ref.test*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 23, passed: 23, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 151, passed: 151, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2663, passed: 2663, failed: 0.

moon build --target native --release src/cmd
# Finished; no work to do.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-null-nonnull-test-cast-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-null-nonnull-test-cast-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `55/10000`
- normalized matches: `27`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0` reported by the CLI summary; `result.json` leaves this field absent/null
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping final failure artifacts for `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, and `ref.func` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks the ordinary non-null null-operand `ref.test` / `ref.cast` type-surface coverage for literal null operands. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null and literal-i31 subsets, other definitely-successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, and `(ref i31)` local-supertype subsets, broader failed cast/test cases, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
