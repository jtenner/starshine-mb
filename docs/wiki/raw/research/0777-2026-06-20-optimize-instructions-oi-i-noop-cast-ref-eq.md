# Optimize-instructions OI-I no-op cast ref.eq identity

## Question

Can Starshine match Binaryen's local `optimize-instructions` behavior for `ref.eq` when one same-local operand is wrapped in a nullable `ref.cast` that is a no-op for the local's declared heap type?

## Classification

Completed twenty-first `[O4Z-AUDIT-OI-I]` reference sub-slice as a narrow same-reference proof through a trap-free nullable cast.

Starshine now folds `ref.eq(ref.cast (ref null T) (local.get N), local.get N)` and the symmetric operand order to `i32.const 1` when the cast target heap exactly matches the local's declared heap type. This is a local extension of the direct same-local reference identity proof from `0775`, but it deliberately recognizes only immediate nullable `ref.cast` over a direct `local.get` with exact heap equality.

The slice does not claim non-null cast elision for nullable locals, arbitrary cast skipping, subtype-lattice cast removal, flow-sensitive nullable-local facts, local.set-derived facts, descriptor/exactness/TNH/IIT behavior, or arbitrary SSA identity.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps remaining reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]`.
- `docs/wiki/raw/research/0775-2026-06-20-optimize-instructions-oi-i-self-local-ref-eq.md` covered only direct `ref.eq(local.get N, local.get N)` reference identity.
- `docs/wiki/raw/research/0776-2026-06-20-optimize-instructions-oi-i-same-local-i31-ref-eq.md` covered same-local i31 value identity, not reference identity through casts.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-ref-eq-skip-cast.wat <<'EOF'
(module
  (func (export "left-cast") (param (ref null eq)) (result i32)
    local.get 0
    ref.cast (ref null eq)
    local.get 0
    ref.eq)
  (func (export "as-non-null") (param (ref eq)) (result i32)
    local.get 0
    ref.as_non_null
    local.get 0
    ref.eq)
)
EOF
wasm-opt .tmp/oi-ref-eq-skip-cast.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded both functions to `i32.const 1`. This Starshine slice implements the locally representable nullable no-op `ref.cast` equality case; it does not widen `ref.as_non_null` equality or general trap-sensitive cast skipping.

## Tests and implementation

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt` because high-level WAT parsing still does not accept ordinary `ref.cast` text in these fixtures:

- `optimize-instructions folds same-local equality through nullable no-op ref.cast`
  - builds two functions with an `eqref` parameter;
  - checks both left-cast and right-cast operand order; and
  - requires the optimized result to contain `I32(1)` with no remaining `ref.eq`.

Implementation changes in `src/passes/optimize_instructions.mbt`:

- added `optimize_instructions_ref_eq_same_local_operand(...)`; and
- taught the existing same-local `ref.eq` fold to treat a direct `local.get N` and an immediate nullable `ref.cast` of `local.get N` to the local's exact heap type as the same reference operand.

TDD evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable no-op ref.cast*'
# Initial WAT attempt failed at parse time, confirming the known text-surface gap.
# Direct-core red run then failed because the function still contained ref.eq.
```

After the implementation, focused tests passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable no-op ref.cast*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq*'
# Total tests: 1, passed: 1, failed: 0.
```

## Broader validation

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 29, passed: 29, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 159, passed: 159, failed: 0.

moon fmt
# Passed.

moon test src/passes
# Total tests: 2671, passed: 2671, failed: 0.

moon build --target native --release src/cmd
# Passed with existing pass-manager unused-function warnings.

moon info
# Passed with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-noop-cast-ref-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-noop-cast-ref-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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
- command failure class: cached known `binaryen-rec-group-zero` tool/Binaryen failure (`case-000029-wasm-smith`)
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `54` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Agent mismatch classification: the `27` raw mismatches are the same known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping the final out dir found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks same-local reference equality through a nullable exact no-op `ref.cast` over a direct local. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null, literal `ref.i31`, same-local direct reference, same-local i31 value, same-local nullable no-op cast, definitely-non-null `i31` versus non-`i31` local, and absolute non-null struct/array-local subsets; other definitely successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, `(ref i31)` local-supertype, and absolute `struct`/`array` local-supertype subsets; broader failed cast/test cases beyond the local `ref.i31` and absolute struct/array sibling miss proofs; broader unreachable/drop-child preservation; and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
