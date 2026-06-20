# Optimize-instructions OI-I impossible i31 ref.test/ref.cast

## Question

Can Starshine match Binaryen's local `optimize-instructions` behavior for definitely-failing `ref.test` / `ref.cast` cases where a known `ref.i31` value is tested or cast to the disjoint `struct` hierarchy?

## Classification

Completed fourteenth `[O4Z-AUDIT-OI-I]` reference sub-slice as a narrow failed-cast/test implementation plus validation-surface repair.

Starshine now handles the locally proven `i31`-vs-`struct` miss family:

- `ref.test (ref struct)` fed by a local `ref.i31` constructor folds to `i32.const 0`; and
- `ref.cast (ref struct)` fed by a local `ref.i31` constructor rewrites to `unreachable`.

The proof is intentionally narrow. It recognizes immediate `ref.i31` constructors, and declared non-null `(ref i31)` locals for the same miss relation, against `struct`, `array`, or indexed heap targets. It does not claim broader subtype-lattice disjointness, descriptor or exact casts, nullable-local flow facts, non-local SSA facts, arbitrary `eq`-hierarchy identity proofs, or TNH/IIT-specific cast removals.

This slice also fixes Starshine validation for ordinary non-descriptor `ref.test` / `ref.cast` in the `eq` hierarchy: disjoint sibling heap types such as `i31` and `struct` are valid operands/targets even though neither is a subtype of the other. The validator now accepts these when both heap types are in the `eq` hierarchy, while function-vs-eq-family casts remain rejected by the existing hierarchy checks.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps failed cast/test reasoning under `[O4Z-AUDIT-OI-I]` and descriptor/exactness/TNH/IIT-sensitive casts under `[O4Z-AUDIT-OI-J]`.
- `docs/wiki/raw/research/0762-2026-06-20-optimize-instructions-oi-i-successful-i31-test-cast.md` and `docs/wiki/raw/research/0763-2026-06-20-optimize-instructions-oi-i-i31-supertype-test-cast.md` covered only successful local `ref.i31` cast/test proofs.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-i31-failed-cast-abs.wat <<'EOF'
(module
  (func (export "test-struct") (result i32)
    i32.const 7
    ref.i31
    ref.test (ref struct))
  (func (export "cast-struct") (result (ref struct))
    i32.const 7
    ref.i31
    ref.cast (ref struct))
)
EOF
wasm-opt .tmp/oi-i31-failed-cast-abs.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded `test-struct` to `i32.const 0` and rewrote `cast-struct` to `unreachable`.

## Tests and implementation

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds impossible ref.test and ref.cast on local i31 refs`
  - builds a validating module with two functions;
  - feeds `i32.const 7; ref.i31` into `ref.test (ref struct)` and expects `I32(0)` with no `ref.test`; and
  - feeds `i32.const 7; ref.i31` into `ref.cast (ref struct)` and expects `unreachable` with no `ref.cast`.

Implementation changes:

- `src/validate/typecheck.mbt`
  - added a shared compatibility helper for ordinary `ref.test` / `ref.cast`;
  - preserved the existing bidirectional subtype acceptance; and
  - additionally accepts disjoint `eq`-hierarchy heap types so valid always-failing casts/tests can reach the optimizer.
- `src/passes/optimize_instructions.mbt`
  - added narrow known-miss recognition for local `ref.i31` values against `struct`, `array`, and indexed heap targets;
  - folds known-miss `ref.test` to `i32.const 0`; and
  - rewrites known-miss `ref.cast` to `unreachable`.

TDD evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*impossible ref.test*'
# Initial failure: fixture rejected by validation with "ref.test target does not match operand type".
```

After the validation compatibility repair, the same focused test reached the optimizer and failed red because `ref.test` remained. After the optimizer known-miss implementation, the focused test passed.

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*impossible ref.test*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 24, passed: 24, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 152, passed: 152, failed: 0.
```

## Broader validation

```sh
moon test src/validate
# Total tests: 1612, passed: 1612, failed: 0.

moon fmt
# Finished.

moon test src/passes
# Total tests: 2664, passed: 2664, failed: 0.

moon build --target native --release src/cmd
# Finished with existing warnings in pass_manager/pass_manager_wbtest.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

The first direct compare attempt timed out at the default 600-second tool limit before writing `result.json`. It was rerun with a longer timeout using the same command shape and a clean out dir:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-impossible-i31-cast-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-impossible-i31-cast-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `55/10000`
- normalized matches: `27`
- cleanup-normalized matches: `0`
- compare-normalized matches: absent/null in `result.json`
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are the same known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping the final failure artifacts found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences outside the Binaryen command-failure input/metadata.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only locks a narrow local `ref.i31`-vs-`struct` failed cast/test family and the supporting ordinary cast/test validation surface. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null and literal-i31 subsets, other definitely successful `ref.test` / `ref.cast` cases beyond the covered constructor, exact local, and `(ref i31)` local-supertype subsets, broader failed cast/test cases beyond this `i31` miss proof, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
