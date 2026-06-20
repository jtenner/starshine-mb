# Optimize-instructions OI-I nullable ref.as_non_null ref.eq trap preservation

## Question

Can Starshine match Binaryen's local `optimize-instructions` behavior for same-local `ref.eq` when one or both operands are `ref.as_non_null(local.get N)` over a nullable reference local, without dropping the default-mode null trap?

## Classification

Completed twenty-second `[O4Z-AUDIT-OI-I]` reference sub-slice as a narrow trap-preserving same-reference proof.

Starshine now rewrites same-local nullable `ref.as_non_null` equality to a trap-preserving block that drops one original `ref.as_non_null(local.get N)` check and then returns `i32.const 1`. This covers:

- `ref.eq(ref.as_non_null(local.get N), local.get N)`; and
- `ref.eq(ref.as_non_null(local.get N), ref.as_non_null(local.get N))`.

The slice deliberately preserves one null check instead of folding directly to `i32.const 1`, because default-mode WebAssembly must still trap if the nullable local is null. It does not claim arbitrary `ref.as_non_null` skipping, non-local SSA identity, local.set-derived flow facts, allocation identity, subtype-lattice equality, descriptor/exactness/TNH/IIT behavior, or trap removal.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps remaining reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]`.
- `docs/wiki/raw/research/0758-2026-06-20-optimize-instructions-oi-i-ref-as-non-null.md` covered constructor/null `ref.as_non_null` basics but not `ref.eq` preservation around nullable-local traps.
- `docs/wiki/raw/research/0775-2026-06-20-optimize-instructions-oi-i-self-local-ref-eq.md` covered direct same-local reference identity.
- `docs/wiki/raw/research/0777-2026-06-20-optimize-instructions-oi-i-noop-cast-ref-eq.md` covered only trap-free nullable no-op `ref.cast` equality.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-as-non-null-eq-probe.wat <<'EOF'
(module
  (func (export "nonnull-left") (param (ref eq)) (result i32)
    local.get 0
    ref.as_non_null
    local.get 0
    ref.eq)
  (func (export "nullable-left") (param (ref null eq)) (result i32)
    local.get 0
    ref.as_non_null
    local.get 0
    ref.eq)
  (func (export "nullable-both") (param (ref null eq)) (result i32)
    local.get 0
    ref.as_non_null
    local.get 0
    ref.as_non_null
    ref.eq)
)
EOF
wasm-opt .tmp/oi-as-non-null-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded the non-null-local case directly to `i32.const 1`, rewrote the nullable single-`ref.as_non_null` case to `drop(ref.as_non_null(local.get 0)); i32.const 1`, and rewrote the nullable double-`ref.as_non_null` case to one trapped non-null check plus `i32.const 1`.

## Tests and implementation

Added focused WAT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves trap while folding same-local nullable ref.as_non_null equality`
  - checks the single wrapped operand form;
  - checks both operands wrapped in `ref.as_non_null`; and
  - requires `ref.eq` to disappear while `ref.as_non_null`, `drop`, and `I32(1)` remain.

Implementation changes in `src/passes/optimize_instructions.mbt`:

- added `optimize_instructions_ref_eq_same_local_as_non_null_operand(...)` to recognize direct locals and immediate `ref.as_non_null(local.get N)` operands;
- added `optimize_instructions_ref_eq_same_local_as_non_null_trap(...)` to require the same local index and select one nullable-local trap operand to preserve; and
- added `optimize_instructions_replace_with_drop_then_const_i32(...)` so the `ref.eq` node becomes a value block containing `drop(ref.as_non_null(...))` followed by `i32.const 1`.

TDD evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable ref.as_non_null*'
# Red run failed because the optimized function still contained ref.eq.
```

After implementation, focused tests passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable ref.as_non_null*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 30, passed: 30, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 160, passed: 160, failed: 0.
```

## Broader validation

```sh
moon fmt
# Passed.

moon test src/passes
# Total tests: 2672, passed: 2672, failed: 0.

moon build --target native --release src/cmd
# Passed with existing pass-manager unused-function warnings.

moon info
# Passed with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

The first direct compare attempt timed out before writing `result.json`:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-as-non-null-ref-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-as-non-null-ref-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
# Timed out after 600 seconds with no result.json.
```

The rerun completed:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-as-non-null-ref-eq-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-as-non-null-ref-eq-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `56/10000`
- normalized matches: `28`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0` in CLI output (`result.json` key was null)
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: cached known `binaryen-rec-group-zero` tool/Binaryen failure (`case-000029-wasm-smith`)
- jobs: `16`
- cache: wasm-smith `29` hits / `0` misses; Binaryen `56` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Agent mismatch classification: the `28` raw mismatches are the same known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping the final failure directory found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks same-local equality through immediate nullable-local `ref.as_non_null` while preserving one null trap. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null, literal `ref.i31`, same-local direct reference, same-local i31 value, same-local nullable no-op cast, definitely-non-null `i31` versus non-`i31` local, and absolute non-null struct/array-local subsets; other definitely successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, `(ref i31)` local-supertype, and absolute `struct`/`array` local-supertype subsets; broader failed cast/test cases beyond the local `ref.i31` and absolute struct/array sibling miss proofs; broader unreachable/drop-child preservation; and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
