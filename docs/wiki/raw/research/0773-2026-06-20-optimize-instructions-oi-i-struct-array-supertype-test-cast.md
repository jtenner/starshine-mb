# Optimize-instructions OI-I struct/array supertype ref.test/ref.cast

## Question

Can Starshine match Binaryen's local `optimize-instructions` behavior for definitely non-null absolute `struct` / `array` locals tested or cast against their absolute `eq` / `any` supertypes?

## Classification

Completed seventeenth `[O4Z-AUDIT-OI-I]` reference sub-slice as a narrow definitely-successful cast/test implementation.

Starshine now folds `ref.test` to `i32.const 1` and rewrites matching `ref.cast` to the original `local.get` when the operand is a declared non-null local whose absolute heap is `struct` or `array`, and the target heap is absolute `eq` or `any`.

The proof is deliberately narrow. It only trusts local declaration metadata, requires a non-null local reference type, and only recognizes the absolute GC aggregate heaps `struct` / `array` against absolute supertypes `eq` / `any`. It does not claim nullable-local flow facts, indexed/defined heap subtype reasoning, arbitrary subtype-lattice cast/test success, function-reference supertypes, descriptor/exactness/TNH/IIT-sensitive behavior, or constructor allocation/effect reasoning.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps remaining reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]`.
- `docs/wiki/raw/research/0767-2026-06-20-optimize-instructions-oi-i-non-null-local-test-cast.md` covered only exact same-heap declared non-null local cast/test success.
- `docs/wiki/raw/research/0768-2026-06-20-optimize-instructions-oi-i-non-null-local-i31-supertype-test-cast.md` covered only declared non-null `(ref i31)` locals against `eq` / `any` target supertypes.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-struct-supertypes.wat <<'EOF'
(module
  (func (export "test-eq") (param (ref struct)) (result i32)
    local.get 0
    ref.test (ref eq))
  (func (export "cast-eq") (param (ref struct)) (result (ref eq))
    local.get 0
    ref.cast (ref eq))
  (func (export "test-any") (param (ref array)) (result i32)
    local.get 0
    ref.test (ref any))
  (func (export "cast-any") (param (ref array)) (result (ref any))
    local.get 0
    ref.cast (ref any))
)
EOF
wasm-opt .tmp/oi-struct-supertypes.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded `test-eq` and `test-any` to `i32.const 1`, and rewrote `cast-eq` / `cast-any` to the original local.

## Tests and implementation

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds successful ref.test and ref.cast on non-null struct array supertypes`
  - checks a non-null `(ref struct)` local against absolute `eq` for both `ref.test` and `ref.cast`; and
  - checks a non-null `(ref array)` local against absolute `any` for both `ref.test` and `ref.cast`.

Implementation changes in `src/passes/optimize_instructions.mbt`:

- added a narrow absolute `struct` / `array` to `eq` / `any` target predicate; and
- taught the existing known-match `ref.test` / `ref.cast` path to use that predicate for declared non-null locals.

TDD evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct array supertypes*'
# Initial failure: the first optimized function still contained ref.test.
```

After the implementation, the focused test passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct array supertypes*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.test and ref.cast*'
# Total tests: 8, passed: 8, failed: 0.
```

## Broader validation

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 25, passed: 25, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 155, passed: 155, failed: 0.

moon fmt
# Passed.

moon test src/passes
# Total tests: 2667, passed: 2667, failed: 0.

moon build --target native --release src/cmd
# Passed with existing pass-manager unused-function warnings.

moon info
# Passed with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

The first direct compare attempt timed out before writing `result.json`. The rerun completed to the expected known Binaryen/tool command-failure ceiling:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-struct-array-supertype-test-cast-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-struct-array-supertype-test-cast-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `56/10000`
- normalized matches: `28`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `29` hits / `0` misses; Binaryen `56` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are the same known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping the final out dir found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks a narrow definitely-successful cast/test proof for declared non-null absolute `struct` / `array` locals against absolute `eq` / `any` target supertypes. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null, literal `ref.i31`, definitely-non-null `i31` versus non-`i31` local, and absolute non-null struct/array-local subsets; other definitely successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, `(ref i31)` local-supertype, and absolute `struct`/`array` local-supertype subsets; broader failed cast/test cases beyond the local `ref.i31` miss proof; broader unreachable/drop-child preservation; and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
