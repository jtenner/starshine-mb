# O4z optimize-instructions OI-F boolean/select shell audit

Date: 2026-06-19

## Question

`[O4Z-AUDIT-OI-F]` asked to classify Binaryen `OptimizeInstructions.cpp` boolean/select/ternary shell behavior and widen the locally implementable Starshine subset without hiding branch-hint or pass-option metadata boundaries.

## Source anchors

- Current source/lit owner map: `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`.
- Starshine implementation: `src/passes/optimize_instructions.mbt`.
- Focused tests: `src/passes/optimize_instructions_test.mbt`.
- Living dossier: `docs/wiki/binaryen/passes/optimize-instructions/index.md` and `docs/wiki/binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md`.

## Classification

Starshine already had a useful HOT subset before this slice:

- `if` condition cleanup for `i32.eqz`, `i32.eq/ne 0`, and nested boolean condition trees.
- Constant-`if` folding. This remains a Starshine HOT/precompute-adjacent win rather than literal Binaryen OI phase ownership.
- Boolean value-`if` negation and wrapping in `i32.eqz` when the value is consumed by a unique local set/tee use.
- Duplicate branch collapse in simple then-region shells.
- Dead-region suffix cleanup after escaping control.

This slice widened the missing `select` shell subset:

- `select(true_arm, false_arm, i32.const 0)` becomes `false_arm` when the dropped true arm is side-effect-free.
- `select(true_arm, false_arm, nonzero i32.const)` becomes `true_arm` when the dropped false arm is side-effect-free.
- The chosen arm may be effectful only when it has a unique use, avoiding duplicated observable effects in shared HOT graphs.
- An effectful dropped arm, such as a call result, keeps the `select` because WebAssembly evaluates both value operands before applying the condition.

## Boundaries recorded for OI-F

Starshine still does not model Binaryen expression-level branch-hint/code metadata for this pass. Until that support exists, Binaryen `BranchHints::copyTo`, `copyFlippedTo`, `flip`, `applyAndTo`, `applyOrTo`, and hint-clearing behavior are explicit metadata boundaries, not hidden behavior-parity claims.

Starshine also does not expose a Binaryen-equivalent `optimize-instructions-never-fold-or-reorder` pass argument. The direct `optimize-instructions` pass therefore performs its ordinary safe folds and reorderings unconditionally. Reopening criteria: add a pass-arg/options surface, thread it through the CLI/registry/pipeline context, and add positive and negative tests showing the option blocks the same fold/reorder families Binaryen blocks.

Full recursive `optimizeBoolean(...)`, broad `optimizeTernary(...)`, and all branch-hint-sensitive transformations remain reopenable if future compare evidence or source review identifies a concrete semantic parity gap. This slice closes the current OI-F audit item by documenting the boundary and adding the locally safe constant-select shell, not by claiming every upstream AST boolean helper is ported line-for-line.

## Tests added

- `optimize-instructions folds select with constant false and pure dead arm`
- `optimize-instructions folds select with constant true and pure dead arm`
- `optimize-instructions preserves select when constant dead arm has call effects`

Red-first evidence: before implementation, the two positive tests failed because the root stayed a `select`; the call-effect negative already passed and was kept as the safety boundary.

## Implementation notes

`src/passes/optimize_instructions.mbt` now has:

- `optimize_instructions_replace_with_node_id(...)` for replacing a HOT node by an arbitrary existing child node shape.
- `optimize_instructions_try_fold_const_select(...)` for constant-condition `select` cleanup.
- A `HotOp::Select` visitor arm in `optimize_instructions_visit_node(...)`.

The dropped arm must be `optimize_instructions_is_side_effect_free_expr(...)`. This is stricter than pure value equivalence because WebAssembly `select` evaluates both arms. The chosen arm can be copied only if it is side-effect-free or uniquely used.

## Evidence

Commands run serially:

1. Red-first focused select filter:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*select*'`
   - Initial result after adding tests: `3` tests run, `2` expected positive failures, `1` negative passed.
2. Final focused select filter:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*select*'`
   - Passed: `Total tests: 3, passed: 3, failed: 0.`
3. Focused optimize-instructions filter:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
   - Passed: `Total tests: 101, passed: 101, failed: 0.`
4. `moon fmt`
   - Passed.
5. `moon test src/passes`
   - Passed: `Total tests: 2613, passed: 2613, failed: 0.`
6. `moon build --target native --release src/cmd`
   - Passed with existing unused-function warnings in `pass_manager.mbt`.
7. `moon info`
   - Passed with existing unused trait/function warnings in `validate/gen_valid*.mbt`.
8. Direct compare lane:
   - Final command: `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-f-select-safe-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
   - Requested `10000`; compared `54/10000` before the default failure ceiling.
   - Normalized matches: `27`.
   - Cleanup-normalized matches: `0`.
   - Raw mismatches: `27`.
   - Validation failures: `0`; property failures: `0`; generator failures: `0`.
   - Command failures: `1`, classified as the known Binaryen/tool `binaryen-rec-group-zero` failure.
   - Jobs: `16`.
   - Cache: wasm-smith `28` hits / `0` misses; Binaryen `54` hits / `0` misses; Binaryen failures `1` hit / `0` misses.

An earlier compare attempt using `.tmp/pass-fuzz-optimize-instructions-oi-f-select-10000` timed out during generation and then failed when rerun in place. Treat `.tmp/pass-fuzz-optimize-instructions-oi-f-select-safe-10000` as the final OI-F evidence directory.

## Agent mismatch classification

The `27` raw mismatches in the final compare lane are classified by agent judgment as the same known Starshine-win output-shape families from OI-E, not new select-shell semantic failures:

- Starshine constant-`if` folding where Binaryen OI leaves a larger shape for a neighboring pass.
- Starshine redundant sign-extension cleanup from OI-E.

Sample canonical wasm sizes remain smaller for Starshine on inspected recurring cases:

- `case-000002-gen-valid`: Binaryen `4161` bytes, Starshine `4120` bytes.
- `case-000004-gen-valid`: Binaryen `5539` bytes, Starshine `5481` bytes.
- `case-000006-gen-valid`: Binaryen `5559` bytes, Starshine `5496` bytes.

No validation failures or true semantic mismatches were observed in this slice's direct evidence.

## Remaining work

`[O4Z-AUDIT-OI-G]` is next: implement and classify memory and bulk-memory OI surfaces. Later OI slices remain open for `call_ref`, reference/cast/descriptor/null-trap, GC constructors/fields/arrays/atomics, tuple extraction, repair boundaries, and final direct/O4z closeout.
