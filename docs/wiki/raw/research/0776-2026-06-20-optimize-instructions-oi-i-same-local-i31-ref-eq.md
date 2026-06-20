# Optimize-instructions OI-I same-local ref.i31 ref.eq

## Question

Can Starshine match Binaryen's local `optimize-instructions` behavior for `ref.eq` when both operands are `ref.i31` wrappers around the same `local.get` integer value?

## Classification

Completed twentieth `[O4Z-AUDIT-OI-I]` reference sub-slice as a narrow i31 value-identity proof.

Starshine now folds `ref.eq(ref.i31(local.get N), ref.i31(local.get N))` to `i32.const 1`. This extends the earlier immediate literal-i31 equality and direct same-local reference identity proofs, but it remains deliberately narrow: it recognizes only two immediate `ref.i31` operands whose direct child is `local.get` of the same local index.

The slice does not claim arbitrary SSA identity, local.set-derived flow facts, non-local i31 value analysis, constructor allocation dropping beyond `ref.i31`, descriptor/exactness/TNH/IIT behavior, or broader subtype-lattice equality reasoning.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps remaining reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]`.
- `docs/wiki/raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md` covered only immediate literal `ref.i31(i32.const)` equality.
- `docs/wiki/raw/research/0775-2026-06-20-optimize-instructions-oi-i-self-local-ref-eq.md` covered direct `ref.eq(local.get N, local.get N)` reference identity, not `ref.i31` value identity.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-ref-eq-local-i31.wat <<'EOF'
(module
  (func (export "same-local-i31") (param i32) (result i32)
    local.get 0
    ref.i31
    local.get 0
    ref.i31
    ref.eq)
  (func (export "same-expr-i31") (result i32)
    i32.const 7
    ref.i31
    i32.const 7
    ref.i31
    ref.eq)
)
EOF
wasm-opt .tmp/oi-ref-eq-local-i31.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded both functions to `i32.const 1`. The `same-expr-i31` case was already covered by `0765`; this slice implements only the same-local nonconstant value case.

## Tests and implementation

Added focused WAT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds same-local ref.i31 equality`
  - checks `ref.eq` over two immediate `ref.i31(local.get 0)` operands; and
  - requires the result to be `I32(1)` with no remaining `ref.eq`.

Implementation changes in `src/passes/optimize_instructions.mbt`:

- added a direct `ref.i31(local.get N)` operand recognizer; and
- folded matching same-local i31 equality to `i32.const 1` before the existing literal-i31 and impossible-equality cases.

TDD evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*same-local ref.i31*'
# Initial failure: the function still contained ref.eq.
```

After the implementation, focused tests passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*same-local ref.i31*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq*'
# Total tests: 1, passed: 1, failed: 0.
```

## Broader validation

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 28, passed: 28, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 158, passed: 158, failed: 0.

moon fmt
# Passed.

moon test src/passes
# Total tests: 2670, passed: 2670, failed: 0.

moon build --target native --release src/cmd
# Passed with existing pass-manager unused-function warnings.

moon info
# Passed with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-same-local-i31-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-same-local-i31-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `54/10000`
- normalized matches: `27`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0` in CLI output (`result.json` key was null)
- raw mismatches: `27`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: cached known `binaryen-rec-group-zero` tool/Binaryen failure
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `54` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Agent mismatch classification: the `27` raw mismatches are the same known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping the final out dir found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks same-local `ref.i31` value equality. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null, literal `ref.i31`, same-local reference, same-local i31 value, definitely-non-null `i31` versus non-`i31` local, and absolute non-null struct/array-local subsets; other definitely successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, `(ref i31)` local-supertype, and absolute `struct`/`array` local-supertype subsets; broader failed cast/test cases beyond the local `ref.i31` and absolute struct/array sibling miss proofs; broader unreachable/drop-child preservation; and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
