# `-O4z` Five-Pass Parity Audit

Status: release-artifact parity audit for the only five currently fully implemented Starshine optimize passes, compared directly against Binaryen `wasm-opt version 125`.

## Scope
- Input artifact:
  - `tests/node/dist/starshine-optimized-wasi.wasm`
- Investigated pass surface:
  1. `DuplicateFunctionElimination`
  2. `RemoveUnusedModuleElements`
  3. `MemoryPacking`
  4. `OnceReduction`
  5. `DeadCodeElimination`
- Investigation goals:
  - identify correctness failures
  - identify missing optimizations
  - identify remaining parity / methodology problems that affect comparison quality

## Current Behavior

Tracing Starshine's real `-O4z` run on the release artifact with:

```bash
_build/native/release/build/cmd/cmd.exe \
  --tracing pass \
  --debug-serial-passes \
  --optimize -O4z \
  --out /tmp/starshine-o4z-release.wasm \
  tests/node/dist/starshine-optimized-wasi.wasm
```

shows:

- `pass_count=48`
- the first five visible generated groups are:
  1. `DuplicateFunctionElimination`
  2. `RemoveUnusedModuleElements`
  3. `MemoryPacking`
  4. `OnceReduction`
  5. grouped function stage beginning with `SSANoMerge, Flatten, SimplifyLocalsNoTeeNoStructure, LocalCSE, DeadCodeElimination, ...`

For this audit, the Binaryen side does **not** use a preset because `wasm-opt version 125` rejects `-O4z` as a CLI flag. The shared comparison therefore replays only the ordered five-pass prefix explicitly:

```bash
bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-optimized-wasi.wasm \
  --out-dir /tmp/starshine-parity-prefixes-20260322/prefixN \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --memory-packing \
  --once-reduction \
  --dead-code-elimination
```

and inspects each cumulative prefix manually.

## Prefix Matrix

Input size: `7834197` bytes  
Input validation: `wasm-tools validate` passes

| Prefix | Passes | Binaryen size | Starshine size | Starshine validates | Binaryen validates |
| --- | --- | ---: | ---: | --- | --- |
| 01 | `DFE` | `7101082` | `7249242` | no | yes |
| 02 | `DFE -> RUME` | `7101082` | `7249242` | no | yes |
| 03 | `DFE -> RUME -> MP` | `7098802` | `7246962` | no | yes |
| 04 | `... -> OnceReduction` | `7098802` | `7246962` | no | yes |
| 05 | `... -> DCE` | `7098017` | `7246962` | no | yes |

Observed per-tool changes:

- Starshine:
  - `01 -> 02`: no change
  - `02 -> 03`: changed
  - `03 -> 04`: no change
  - `04 -> 05`: no change
- Binaryen:
  - `01 -> 02`: no change
  - `02 -> 03`: changed
  - `03 -> 04`: no change
  - `04 -> 05`: changed

Additional evidence:

- `cmp` shows Starshine `prefix1 == prefix2`
- `cmp` shows Starshine `prefix3 == prefix4 == prefix5`
- the size gap is already `148160` bytes after the first shared pass and grows to `148945` bytes after Binaryen's DCE step

## Correctness Issues

### 1. `DuplicateFunctionElimination` already emits an invalid module

The checked-in input artifact validates cleanly, but the first Starshine prefix does not:

```text
error: func 305 failed to validate

Caused by:
    0: type mismatch: expected i32 but nothing on stack (at offset 0xb9ea)
```

That means the primary correctness blocker is not a late DCE cleanup issue. It is already present immediately after `DuplicateFunctionElimination`.

### 2. The invalidity persists through every later shared prefix

- `RemoveUnusedModuleElements` does not change the broken DFE output.
- `MemoryPacking` shrinks the module, but the result is still invalid.
- `OnceReduction` is a no-op on this artifact.
- `DeadCodeElimination` is also a no-op on the Starshine side for this artifact.

So the entire five-pass comparison is currently downstream of an unresolved prefix-1 validity failure.

### 3. The failure is broader than one isolated bad tail

`wasm-validate -v` on the first Starshine prefix reports a large cluster of type mismatches in typed loop contexts, not a single local issue. Representative errors include repeated:

```text
type mismatch at end of loop, expected [] but got [i32]
type mismatch in loop, expected [i32] but got []
```

Inference from the raw WAT diff: the first broken output is structurally very close to the input function bodies, but it contains widespread call-index rewrites from DFE. That makes the DFE rewrite / remap logic the most likely root cause, not later cleanup policy.

### 4. Later pass parity claims are provisional until prefix-1 validity is fixed

Because Starshine is already invalid after the first shared pass, later stage comparisons can still be used for size and change attribution, but they are not yet trustworthy semantic parity checkpoints.

## Missing Optimizations

### 1. `DuplicateFunctionElimination` is far less effective than Binaryen on this artifact

After the first shared pass:

- Binaryen: `7101082`
- Starshine: `7249242`
- gap: `148160` bytes

The raw printed artifacts also show a large structural gap after that first pass:

- input raw WAT function count: `9933`
- Starshine prefix-1 raw WAT function count: `8348`
- Binaryen prefix-1 raw WAT function count: `7722`

So even aside from the correctness failure, Starshine's first-pass DFE is materially less profitable on this artifact.

### 2. `MemoryPacking` profitability matches this artifact's shrink, but not the earlier gap

`MemoryPacking` reduces both tools by exactly `2280` bytes on this artifact:

- Binaryen: `7101082 -> 7098802`
- Starshine: `7249242 -> 7246962`

That suggests the currently implemented `MemoryPacking` slice is finding the same coarse shrink opportunity here, but it does not reduce the preexisting DFE gap at all.

### 3. `DeadCodeElimination` misses a real Binaryen cleanup

At the fifth prefix:

- Binaryen changes the module: `7098802 -> 7098017`
- Starshine does not change the module: `7246962 -> 7246962`

The Starshine `prefix4` and `prefix5` outputs are byte-identical, so the current DCE implementation contributes no additional shrink on this artifact while Binaryen still finds `785` bytes.

### 4. `RemoveUnusedModuleElements` and `OnceReduction` are no-ops on this artifact

That is not a parity problem by itself. It just means this artifact does not currently exercise meaningful shrink opportunities for those two passes.

## Other Parity Problems

### 1. There is no direct Binaryen `-O4z` CLI parity target

Binaryen `wasm-opt version 125` rejects `-O4z` as an option, so the correct shared comparison method for this question is:

- trace Starshine's real `-O4z` schedule
- extract the first five fully implemented passes
- replay exactly those five passes, in order, on both tools

Any doc that phrases this as a literal `Starshine -O4z` vs `Binaryen -O4z` comparison would be overstating what Binaryen can actually run.

### 2. The five-pass comparison is only a prefix of Starshine's real `-O4z` schedule

The real traced Starshine `-O4z` run schedules `48` passes. After the first four standalone groups, the next grouped stage already includes many cleanup / canonicalization passes beyond the five fully implemented ones:

- `RemoveUnusedNames`
- `RemoveUnusedBrs`
- `OptimizeInstructions`
- `PickLoadSigns`
- `PrecomputePropagate`
- `TupleOptimization`
- `Vacuum`
- `ReorderLocals`
- `MergeLocals`
- `CoalesceLocals`
- `CodeFolding`
- `MergeBlocks`
- `RedundantSetElimination`

So even after the current five implemented passes are fixed, full-pipeline `-O4z` parity will still remain blocked on the broader unimplemented cleanup surface.

### 3. The compare harness degrades poorly when one side is invalid

`scripts/self-optimize-compare.ts` currently aborts while trying to normalize the invalid Starshine output with `wasm-opt --print`. That means invalid runs do not automatically produce:

- `result.json`
- `commands.txt`
- a complete normalized WAT pair

For parity work, that is a tooling problem: the harness should preserve partial artifacts and explicit validation results even when one side fails.

## Correctness Constraints

- Treat the prefix-1 DFE invalidity as the first blocker for this artifact.
- Do not claim later pass parity until the first shared pass produces a validating module.
- Keep the comparison method explicit: shared ordered five-pass replay, not a fictional Binaryen `-O4z` preset.
- Once DFE is fixed, rerun the entire prefix matrix before attributing any remaining gap to DCE or later missing cleanup passes.

## Validation Plan

1. Add a focused regression that runs `DuplicateFunctionElimination` on the release artifact or a minimized extracted fixture and asserts `wasm-tools validate` still passes.
2. Minimize one of the broken DFE-rewritten typed-loop functions from the release artifact into a direct whitebox fixture so the invalid remap can be reproduced without the full self-optimized module.
3. Update `scripts/self-optimize-compare.ts` so it validates outputs before normalization and always writes a partial result summary when one side is invalid.
4. Re-run the five-prefix matrix after the DFE fix, then separately measure how much of the remaining gap is due to DCE and how much is due to later unimplemented cleanup passes.

## Performance Impact

- Current shared-prefix final sizes:
  - Binaryen: `7098017`
  - Starshine: `7246962`
  - gap: `148945` bytes
- Of that visible five-pass gap:
  - `148160` bytes already exist immediately after DFE
  - `785` additional bytes come from Binaryen's DCE step that Starshine currently misses
- `MemoryPacking` contributes the same `2280` byte shrink in both tools on this artifact.

## Open Questions

1. Is the DFE invalidity caused by incorrect function-index remapping, incorrect callee-signature matching during deduplication, or stale typed control signatures that the rewrite path fails to repair?
2. After the DFE validity bug is fixed, how much of the remaining `148160` byte first-pass gap is still true DFE profitability loss versus later Binaryen canonicalization that should not be attributed to DFE itself?
3. Should the five-pass compare harness grow an artifact-minimization helper for the first invalid function so parity investigations can move faster when a self-optimized module breaks early?
