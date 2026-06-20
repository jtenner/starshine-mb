# Optimize-instructions OI-I impossible i31/struct ref.eq

## Question

Can Starshine match Binaryen's local `optimize-instructions` behavior for `ref.eq` values that are provably disjoint because one side is a definitely non-null `i31` reference and the other side is a struct-typed local?

## Classification

Completed fifteenth `[O4Z-AUDIT-OI-I]` reference sub-slice as a narrow impossible-equality implementation.

Starshine now folds these locally proven impossible equality shapes to `i32.const 0`:

- immediate `ref.i31` compared with a `local.get` whose declared heap type cannot be `i31`, such as `(ref null $struct)`; and
- declared non-null `(ref i31)` locals compared with such a non-`i31` local in either operand order.

The proof is intentionally narrow. It only trusts immediate `ref.i31` constructors and declared non-null `(ref i31)` locals as definitely non-null `i31` values, and only trusts local reference heap types whose heap cannot be `i31` (`struct`, `array`, or indexed/defined heap types) as the other side. It does not claim arbitrary subtype-lattice equality reasoning, nullable `(ref null i31)` local flow facts, struct/array constructor identity facts that could drop allocation effects, function-reference equality, non-local SSA, descriptor/exactness/TNH/IIT facts, or broader reference identity reasoning.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps remaining reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]`.
- `docs/wiki/raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md` covered only literal `ref.i31(i32.const)` equality.
- `docs/wiki/raw/research/0770-2026-06-20-optimize-instructions-oi-i-impossible-i31-test-cast.md` covered failed `ref.test` / `ref.cast` for local `ref.i31` values against `struct` / `array` / indexed heap targets.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-i31-struct-local-eq-both.wat <<'EOF'
(module
  (type $s (struct))
  (func (export "right") (param (ref null $s)) (result i32)
    i32.const 7
    ref.i31
    local.get 0
    ref.eq)
  (func (export "left") (param (ref i31)) (param (ref null $s)) (result i32)
    local.get 1
    local.get 0
    ref.eq)
)
EOF
wasm-opt .tmp/oi-i31-struct-local-eq-both.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded both exported functions to `i32.const 0`.

## Tests and implementation

Added focused WAT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds impossible equality between i31 and struct locals`
  - compares an immediate `ref.i31` against a nullable struct local and expects `I32(0)` with no `ref.eq`; and
  - compares a nullable struct local against a declared non-null `(ref i31)` local in the reverse operand order and expects `I32(0)` with no `ref.eq`.

Implementation changes in `src/passes/optimize_instructions.mbt`:

- added a helper for definitely non-null local `i31` values;
- added a helper for local reference values whose declared heap cannot be `i31`; and
- taught the existing `ref.eq` rewrite path to fold the narrow disjoint pair to `i32.const 0` before the generic null-equality rewrites.

TDD evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*impossible equality*'
# Initial failure: the optimized function still contained ref.eq.
```

After the implementation, the focused test passed.

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*impossible equality*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 24, passed: 24, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 153, passed: 153, failed: 0.
```

## Broader validation

```sh
moon fmt
# Passed.

moon test src/passes
# Total tests: 2665, passed: 2665, failed: 0.

moon build --target native --release src/cmd
# Passed with existing pass-manager unused-function warnings.

moon info
# Passed with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-impossible-i31-struct-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-impossible-i31-struct-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `53/10000`
- normalized matches: `26`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- raw mismatches: `27`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `27` hits / `0` misses; Binaryen `53` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `27` raw mismatches are the same known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping the final out dir found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks a narrow impossible equality proof between definitely non-null `i31` values and local refs whose declared heap cannot be `i31`. Remaining useful sub-slices include other definitely successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, and `(ref i31)` local-supertype subsets, broader failed cast/test cases beyond the local `ref.i31` miss proof, broader equality and identity proofs beyond this disjoint-local subset plus literal-i31 equality and null-vs-known-non-null equality, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
