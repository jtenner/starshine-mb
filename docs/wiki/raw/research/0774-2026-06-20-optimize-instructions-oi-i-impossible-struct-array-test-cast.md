# Optimize-instructions OI-I impossible struct/array ref.test/ref.cast

## Question

Can Starshine match Binaryen's local `optimize-instructions` behavior for definitely non-null absolute `struct` / `array` locals tested or cast against the disjoint absolute `array` / `struct` sibling heap?

## Classification

Completed eighteenth `[O4Z-AUDIT-OI-I]` reference sub-slice as a narrow failed-cast/test implementation.

Starshine now folds `ref.test` to `i32.const 0` and rewrites matching `ref.cast` to `unreachable` when the operand is a declared non-null local whose absolute heap is `struct` and the target heap is absolute `array`, or vice versa.

The proof is deliberately narrow. It only trusts local declaration metadata, requires a non-null local reference type, and only recognizes the absolute GC aggregate sibling heaps `struct` and `array`. It does not claim nullable-local flow facts, indexed/defined heap subtype reasoning, arbitrary subtype-lattice disjointness, descriptor/exactness/TNH/IIT-sensitive behavior, constructor allocation/effect reasoning, or function-reference hierarchy facts.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps remaining reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]`.
- `docs/wiki/raw/research/0770-2026-06-20-optimize-instructions-oi-i-impossible-i31-test-cast.md` covered only local `ref.i31` miss proofs against `struct` / `array` / indexed targets.
- `docs/wiki/raw/research/0772-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-eq.md` covered only `ref.eq` between absolute local `struct` / `array` refs when at least one side is declared non-null.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-struct-array-miss.wat <<'EOF'
(module
  (func (export "test-struct-array") (param (ref struct)) (result i32)
    local.get 0
    ref.test (ref array))
  (func (export "cast-struct-array") (param (ref struct)) (result (ref array))
    local.get 0
    ref.cast (ref array))
  (func (export "test-array-struct") (param (ref array)) (result i32)
    local.get 0
    ref.test (ref struct))
  (func (export "cast-array-struct") (param (ref array)) (result (ref struct))
    local.get 0
    ref.cast (ref struct))
)
EOF
wasm-opt .tmp/oi-struct-array-miss.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded both `ref.test` functions to `i32.const 0` and rewrote both `ref.cast` functions to `unreachable`.

## Tests and implementation

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds impossible ref.test and ref.cast between non-null struct array locals`
  - checks non-null `(ref struct)` local against absolute `array` for both `ref.test` and `ref.cast`; and
  - checks non-null `(ref array)` local against absolute `struct` for both `ref.test` and `ref.cast`.

Implementation changes in `src/passes/optimize_instructions.mbt`:

- reused the existing absolute `struct` / `array` disjointness predicate; and
- taught the known-miss `ref.test` / `ref.cast` path to use that predicate for declared non-null locals.

TDD evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct array locals*'
# Initial failure: the first optimized function still contained ref.test.
```

After the implementation, focused tests passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct array locals*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.test and ref.cast*'
# Total tests: 9, passed: 9, failed: 0.
```

## Broader validation

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 26, passed: 26, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 156, passed: 156, failed: 0.

moon fmt
# Passed.

moon test src/passes
# Total tests: 2668, passed: 2668, failed: 0.

moon build --target native --release src/cmd
# Passed with existing pass-manager unused-function warnings.

moon info
# Passed with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-struct-array-miss-test-cast-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-struct-array-miss-test-cast-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `55/10000`
- normalized matches: `27`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0` in CLI output (`result.json` key was null)
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are the same known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping the final out dir found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks a narrow failed cast/test proof for declared non-null absolute `struct` / `array` locals against the other absolute aggregate sibling. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null, literal `ref.i31`, definitely-non-null `i31` versus non-`i31` local, and absolute non-null struct/array-local subsets; other definitely successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, `(ref i31)` local-supertype, and absolute `struct`/`array` local-supertype subsets; broader failed cast/test cases beyond the local `ref.i31` and absolute struct/array sibling miss proofs; broader unreachable/drop-child preservation; and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
