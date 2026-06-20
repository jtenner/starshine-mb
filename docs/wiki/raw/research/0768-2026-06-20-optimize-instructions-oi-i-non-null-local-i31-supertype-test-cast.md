# Optimize-instructions OI-I non-null local i31 ref.test/ref.cast supertype proof

## Question

Can Starshine reuse a declared non-null `(ref i31)` local type to fold definitely-successful `ref.test` and `ref.cast` when the target heap type is an absolute `i31` supertype (`eq` or `any`)?

## Classification

Completed twelfth positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice broadens the declared non-null local `ref.test` / `ref.cast` proof from exact same-heap locals to the narrow, source-backed `i31 <: eq <: any` family. It now covers:

- `ref.test (ref eq) (local.get $x)` and `ref.test (ref any) (local.get $x)` to `i32.const 1` when `$x : (ref i31)`; and
- `ref.cast (ref eq) (local.get $x)` and `ref.cast (ref any) (local.get $x)` to the original `local.get` when `$x : (ref i31)`.

The proof remains deliberately narrow. It only trusts declared non-null local type metadata and the absolute `i31` target-supertype relation already used for immediate local `ref.i31` constructors. It does not infer through nullable locals, `local.set` value flow, arbitrary SSA/non-local facts, indexed/recursive type relationships, arbitrary subtype-lattice facts beyond `i31` to `eq` / `any`, descriptor/exactness/TNH/IIT modes, failed cast/test behavior, or GC aggregate identity.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]` and descriptor/exactness/TNH/IIT behavior under `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-nonnull-local-i31-supertype-test-cast.wat <<'WAT'
(module
  (func (export "test-eq") (param (ref i31)) (result i32)
    local.get 0
    ref.test (ref eq))
  (func (export "cast-eq") (param (ref i31)) (result (ref eq))
    local.get 0
    ref.cast (ref eq))
  (func (export "test-any") (param (ref i31)) (result i32)
    local.get 0
    ref.test (ref any))
  (func (export "cast-any") (param (ref i31)) (result (ref any))
    local.get 0
    ref.cast (ref any)))
WAT
wasm-opt .tmp/oi-nonnull-local-i31-supertype-test-cast.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded both non-null local `ref.test` functions to `i32.const 1` and removed both supertype `ref.cast` nodes, returning the local directly.

- `src/passes/optimize_instructions.mbt` now lets `optimize_instructions_ref_is_known_match_for_target(...)` recognize `LocalGet` operands whose HOT local metadata type is non-null `(ref i31)` and whose cast/test target is the absolute heap type `i31`, `eq`, or `any`.

## Tests

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds declared non-null i31 local ref.test and ref.cast to supertypes`
  - asserts `(ref i31)` local `ref.test (ref eq)` and `ref.test (ref any)` become `I32(1)`; and
  - asserts matching `ref.cast (ref eq)` and `ref.cast (ref any)` are removed while preserving `local.get`.

The fixture uses direct core builders because the current Starshine WAT parser does not yet support the ordinary `ref.test (ref T)` / `ref.cast (ref T)` text forms used by the Binaryen oracle.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*declared non-null i31 local*'
# Before implementation: failed because the new eq-target non-null local ref.test still remained as `ref.test`.
```

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*declared non-null i31 local*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 22, passed: 22, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 150, passed: 150, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2662, passed: 2662, failed: 0.

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in src/passes/pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-nonnull-local-i31-supertype-test-cast-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-nonnull-local-i31-supertype-test-cast-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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

`[O4Z-AUDIT-OI-I]` remains open. This slice only adds the narrow declared non-null `(ref i31)` local proof for absolute target supertypes `eq` and `any`, reusing the already-covered local `i31` subtype relation. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null and literal-i31 subsets, public non-null `ref.test` / `ref.cast` null-operand validation/type-surface coverage, broader definitely-successful `ref.test` / `ref.cast` cases, broader failed cast/test cases, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
