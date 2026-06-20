# Optimize-instructions OI-I impossible struct/array ref.eq

## Question

Can Starshine match Binaryen's local `optimize-instructions` behavior for `ref.eq` values that are provably disjoint because one side is declared non-null `struct` and the other side is declared `array`?

## Classification

Completed sixteenth `[O4Z-AUDIT-OI-I]` reference sub-slice as a narrow impossible-equality implementation.

Starshine now folds `ref.eq` to `i32.const 0` when both operands are locals, at least one local is declared non-null, and the local declared heap types are the absolute GC aggregate siblings `struct` and `array` in either operand order.

The proof is deliberately narrow. It only trusts local declaration metadata, requires at least one non-null operand so both values cannot be the shared null reference, and only recognizes the absolute `struct` / `array` disjoint pair. It does not claim nullable-both equality folding, indexed/defined heap subtype reasoning, arbitrary subtype-lattice equality reasoning, constructor identity folding that might drop allocation or effects, non-local SSA, descriptor/exactness/TNH/IIT-sensitive behavior, function-reference equality, or broader GC reference identity reasoning.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps remaining reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]`.
- `docs/wiki/raw/research/0771-2026-06-20-optimize-instructions-oi-i-impossible-i31-struct-eq.md` covered only definitely non-null `i31` values versus local refs whose declared heap cannot be `i31`.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-struct-array-eq.wat <<'EOF'
(module
  (type $s (struct))
  (type $a (array i32))
  (func (export "struct-array") (param (ref null $s)) (param (ref null $a)) (result i32)
    local.get 0
    local.get 1
    ref.eq)
  (func (export "nonnull-array") (param (ref $s)) (param (ref null $a)) (result i32)
    local.get 0
    local.get 1
    ref.eq)
)
EOF
wasm-opt .tmp/oi-struct-array-eq.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle kept the nullable-both struct/array equality unchanged, but folded the non-null-struct versus nullable-array equality to `i32.const 0`.

A second oracle probe showed the absolute heap spellings used by the public Starshine WAT fixture are also Binaryen-owned:

```sh
cat > .tmp/oi-abs-struct-array-eq.wat <<'EOF'
(module
  (func (export "nonnull-abs") (param (ref struct)) (param (ref null array)) (result i32)
    local.get 0
    local.get 1
    ref.eq)
)
EOF
wasm-opt .tmp/oi-abs-struct-array-eq.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded the function to `i32.const 0`.

## Tests and implementation

Added focused WAT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds impossible equality between non-null struct and array locals`
  - compares a non-null `(ref struct)` local with a nullable `(ref null array)` local and expects `I32(0)` with no `ref.eq`; and
  - checks the reverse operand order through nullable array plus non-null struct params.

Implementation changes in `src/passes/optimize_instructions.mbt`:

- added a helper for local reference type lookup;
- added a narrow absolute `struct` / `array` heap-disjoint predicate; and
- taught the existing `ref.eq` rewrite path to fold local struct/array equality only when at least one side is declared non-null.

TDD evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null struct and array*'
# Initial failure: the optimized function still contained ref.eq.
```

After the implementation, the focused test passed.

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*impossible equality*'
# Total tests: 2, passed: 2, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 24, passed: 24, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 154, passed: 154, failed: 0.
```

## Broader validation

```sh
moon fmt
# Passed.

moon test src/passes
# Total tests: 2666, passed: 2666, failed: 0.

moon build --target native --release src/cmd
# Passed with existing pass-manager unused-function warnings.

moon info
# Passed with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-impossible-struct-array-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-impossible-struct-array-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `52/10000`
- normalized matches: `26`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- raw mismatches: `26`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `27` hits / `0` misses; Binaryen `52` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `26` raw mismatches are the same known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping the final out dir found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks a narrow impossible equality proof for absolute local `struct` / `array` types when at least one operand is declared non-null. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null, literal `ref.i31`, definitely-non-null `i31` versus non-`i31` local, and absolute non-null struct/array-local subsets; other definitely successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, and `(ref i31)` local-supertype subsets; broader failed cast/test cases beyond the local `ref.i31` miss proof; broader unreachable/drop-child preservation; and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
