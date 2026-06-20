# Optimize-instructions OI-I self-local ref.eq

## Question

Can Starshine match Binaryen's local `optimize-instructions` behavior for `ref.eq` when both operands are the same local reference value?

## Classification

Completed nineteenth `[O4Z-AUDIT-OI-I]` reference sub-slice as a narrow reference identity proof.

Starshine now folds `ref.eq(local.get N, local.get N)` to `i32.const 1` for local reference operands. This applies to nullable and non-null local reference types because the same local read produces the same reference value, including the same null value when the local is null.

The proof is deliberately narrow. It only recognizes two direct `local.get` operands with the same local index. It does not claim arbitrary SSA value identity, local.set-derived flow facts, constructor identity, allocation dropping, descriptor/exactness/TNH/IIT behavior, or broader subtype-lattice equality reasoning.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps remaining reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]`.
- `docs/wiki/raw/research/0765-2026-06-20-optimize-instructions-oi-i-i31-ref-eq.md` covered only immediate literal `ref.i31(i32.const)` equality.
- `docs/wiki/raw/research/0771-2026-06-20-optimize-instructions-oi-i-impossible-i31-struct-eq.md` and `docs/wiki/raw/research/0772-2026-06-20-optimize-instructions-oi-i-impossible-struct-array-eq.md` covered narrow impossible equality proofs, not same-reference identity.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-ref-eq-same-local.wat <<'EOF'
(module
  (func (export "nullable") (param eqref) (result i32)
    local.get 0
    local.get 0
    ref.eq)
  (func (export "non-null") (param (ref eq)) (result i32)
    local.get 0
    local.get 0
    ref.eq)
)
EOF
wasm-opt .tmp/oi-ref-eq-same-local.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded both nullable and non-null self-local equality functions to `i32.const 1`.

## Tests and implementation

Added focused WAT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds self equality on local refs`
  - checks nullable `eqref` self-local equality; and
  - checks non-null `(ref eq)` self-local equality.

Implementation changes in `src/passes/optimize_instructions.mbt`:

- added a direct same-local predicate for `ref.eq` operands; and
- folded matching `ref.eq(local.get N, local.get N)` nodes to `i32.const 1` before the existing literal-i31 and impossible-equality cases.

TDD evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*self equality*'
# Initial failure: nullable function still contained ref.eq.
```

After the implementation, focused tests passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*self equality*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq*'
# Total tests: 1, passed: 1, failed: 0.
```

## Broader validation

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 27, passed: 27, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 157, passed: 157, failed: 0.

moon fmt
# Passed.

moon test src/passes
# Total tests: 2669, passed: 2669, failed: 0.

moon build --target native --release src/cmd
# Passed with existing pass-manager unused-function warnings.

moon info
# Passed with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

First compare attempt timed out before writing `result.json`:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-self-local-ref-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-self-local-ref-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Rerun completed:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-self-local-ref-eq-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-self-local-ref-eq-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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
- command failure class: cached known `binaryen-rec-group-zero` tool/Binaryen failure
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Agent mismatch classification: the `28` raw mismatches are the same known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping the final out dir found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks direct same-local `ref.eq` identity. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null, literal `ref.i31`, self-local, definitely-non-null `i31` versus non-`i31` local, and absolute non-null struct/array-local subsets; other definitely successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, `(ref i31)` local-supertype, and absolute `struct`/`array` local-supertype subsets; broader failed cast/test cases beyond the local `ref.i31` and absolute struct/array sibling miss proofs; broader unreachable/drop-child preservation; and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
