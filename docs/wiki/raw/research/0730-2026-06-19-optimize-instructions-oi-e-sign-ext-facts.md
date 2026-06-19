# Optimize-instructions OI-E sign-extension facts

_Date:_ 2026-06-19  
_Status:_ completed implementation slice for `[O4Z-AUDIT-OI-E]`

## Scope

This slice adds the first local `LocalScanner`-style width/sign fact substrate for Starshine `optimize-instructions`, focused on sign-extension facts that are locally safe in HOT IR. It does not claim the full Binaryen `LocalScanner` contract for all `maxBits`, masks, compares, or control-flow joins.

## Implemented behavior

Changed `src/passes/optimize_instructions.mbt`:

- Added `OptimizeInstructionsScratch.sign_ext_bits_by_node` plus a lazy sign-extension fact scan.
- Initializes params pessimistically and body locals optimistically by type default:
  - params start with no sign-extension facts;
  - non-param `i32` / `i64` locals start as default-zero values and therefore carry the minimal 8-bit sign-extension fact until a write invalidates or updates them.
- Records local-get facts through straight-line root order.
- Updates a local fact after a fallthrough `local.set` / `local.tee` whose value has a known sign-extension width.
- Recognizes sign-extending loads and explicit sign-extension operators as fact sources.
- Conservatively invalidates writes inside `block`, `loop`, and `if` control subtrees for this first slice instead of pretending to model joins or loop-carried values.
- Removes redundant `i32.extend8_s`, `i32.extend16_s`, `i64.extend8_s`, `i64.extend16_s`, and `i64.extend32_s` when the operand is already known sign-extended from an equal-or-narrower lane.
- Rewrites the first explicit sign-extension idiom family:
  - `i32.shr_s (i32.shl x 24) 24 -> i32.extend8_s x`
  - `i32.shr_s (i32.shl x 16) 16 -> i32.extend16_s x`
  - matching `i64` 56/48/32-bit idioms are implemented through the same helper.
- Made the exact-unary replacement helper choose `i64` result type for i64 sign-extension operators.

Changed `src/passes/optimize_instructions_test.mbt`:

- Added signed-load redundant-extension removal coverage.
- Added straight-line local-set fallthrough sign fact coverage.
- Added param pessimism coverage.
- Added constant-lane safety coverage so `i32.const 255 i32.extend8_s` is not removed as if `255` were already sign-extended from 8 bits.
- Added loop-carried/control-write preservation coverage.
- Added shift-sign-extension idiom rewrite coverage.

## Safety notes

The scanner is intentionally conservative. It is not a CFG dataflow analysis and does not join facts across structured control. A control subtree that contains local writes invalidates those locals for following straight-line roots, which keeps loop-carried and branch-carried cases out of this first slice.

The new direct operand facts are pure semantic equalities: signed loads already sign-extend their loaded lane, explicit sign-extension operators make their result sign-extended by construction, default locals are zero, and constants are assigned the narrowest lane that preserves the exact value under sign extension. Removing a redundant sign extension or replacing shift-left/arithmetic-shift-right idioms with the corresponding sign-extension operator preserves WebAssembly behavior and reduces canonical output size in sampled compare diffs.

## Evidence

Focused command that initially caught implementation errors:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*sign*'
```

The first run failed to compile because the new helper compared `HotOp` read-only constructors with `==`. A later constant-lane negative caught an unsafe first interpretation of constant sign facts (`255` must not be treated as already sign-extended from 8 bits). The implementation now tracks the narrowest lane that preserves each integer constant and removes an extension only when the known lane is equal-or-narrower than the requested lane. Final result:

```text
Total tests: 12, passed: 12, failed: 0.
```

Focused optimize-instructions suite:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Result:

```text
Total tests: 98, passed: 98, failed: 0.
```

Repository pass tests and formatting:

```sh
moon fmt
moon test src/passes
```

Result:

```text
Finished. moon: ran 2 tasks, now up to date
Total tests: 2610, passed: 2610, failed: 0.
```

Native command build:

```sh
moon build --target native --release src/cmd
```

Result: passed, with the existing unused-function warnings in `src/passes/pass_manager.mbt`.

Direct compare lane:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-e-sign-ext-safe-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

```text
Compared cases: 53/10000
Normalized matches: 26
Compare-normalized matches: 0
Validation failures: 0
Property failures: 0
Cache: wasm-smith 27 hits/0 misses; Binaryen 53 hits/0 misses; Binaryen failures 1 hits/0 misses
Generator failures: 0
Command failures: 1
Mismatches: 27
```

`result.json` records `requestedCount=10000`, `cleanupNormalizedMatchCount=0`, `jobs=16`, and command failure class `binaryen-rec-group-zero: 1`.

An earlier same-slice compare attempt reused `.tmp/pass-fuzz-optimize-instructions-oi-e-sign-ext-10000` before the constant-lane safety correction and then failed during GenValid batch emission when rerun in-place. The final evidence directory is `.tmp/pass-fuzz-optimize-instructions-oi-e-sign-ext-safe-10000`.

## Agent mismatch classification

- Command failure: `case-000029-wasm-smith` is the known **tool/Binaryen failure** `binaryen-rec-group-zero`.
- The 27 raw mismatches are agent-classified **Starshine-win** output-shape differences, not true semantic mismatches:
  - sampled cases still include the OI-D constant-if folding differences;
  - this slice also exposes redundant sign-extension removal on constants, e.g. Binaryen keeps dropped `i32.extend8_s (i32.const 127)` / `i64.extend32_s (i64.const 2147483647)` shapes while Starshine drops only the already sign-extended constants;
  - sampled canonical wasm sizes are smaller for Starshine, e.g. `case-000002-gen-valid` Binaryen `4161` bytes vs Starshine `4120`, `case-000004-gen-valid` `5539` vs `5481`, and `case-000006-gen-valid` `5559` vs `5496`.

No validation failures, property failures, or generator failures were reported.

## Remaining OI work

`[O4Z-AUDIT-OI-E]` is complete for this first local sign-extension fact slice. Later OI work should not treat this as a full Binaryen `LocalScanner` port: `maxBits` masks, compare proofs, CFG joins, more load/store/memory families, and broad boolean/select/memory/reference/GC surfaces remain open under `[O4Z-AUDIT-OI-F]` and later slices.
