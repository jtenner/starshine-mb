# Starshine Wasm Implemented-Pass Comparison

Status: direct comparison of the currently implemented generated optimize passes on the checked-in Starshine wasm artifacts against Binaryen `wasm-opt version 125`.

## Scope
- Input artifacts:
  - `tests/node/dist/starshine-debug-wasi.wasm`
  - `tests/node/dist/starshine-optimized-wasi.wasm`
- Compare only passes that currently route to live generated runners in `src/optimization/optimization.mbt`:
  - `DuplicateFunctionElimination`
  - `RemoveUnusedModuleElements`
  - `MemoryPacking`
  - `OnceReduction`
  - `DeadCodeElimination`
  - `StringGathering`
- Binaryen comparison tool:
  - `wasm-opt version 125 (version_125)`

## Executed Pass Surface On This Artifact

Tracing the release artifact with:

```bash
STARSHINE_OPTIMIZE_MAX_PASSES=200 \
_build/native/release/build/cmd/cmd.exe \
  --tracing pass \
  --debug-serial-passes \
  --optimize -O2 \
  --out /tmp/release-trace-star.wasm \
  tests/node/dist/starshine-optimized-wasi.wasm
```

shows this implemented pass sequence for the current Starshine wasm artifact:

1. `DuplicateFunctionElimination`
2. `RemoveUnusedModuleElements`
3. `MemoryPacking`
4. `OnceReduction`
5. `DeadCodeElimination`
6. `DuplicateFunctionElimination` (post)
7. `RemoveUnusedModuleElements` (post)

Notes:
- There is no GC-only extra pre-pass `RemoveUnusedModuleElements` on this artifact.
- `StringGathering` is not scheduled on this artifact because the feature detection path does not report strings here.
- Everything else in the default `-O2` schedule is currently a no-op shell for this comparison.

## Debug Artifact Blocker

The direct pass-prefix comparison is blocked on `tests/node/dist/starshine-debug-wasi.wasm` because Starshine fails to encode any optimized output for that artifact:

```text
error: encode failed for tests/node/dist/starshine-debug-wasi.wasm: Encode(InvalidNameMapOrder)
```

Observed behavior:
- `STARSHINE_OPTIMIZE_MAX_PASSES=1` through `=40` all fail the same way.
- Plain `--optimize -O2` also fails the same way on the debug artifact.
- That means the debug artifact currently cannot be used for a direct emitted-output parity run.

Because of that, the complete emitted-output comparison below uses the release artifact `tests/node/dist/starshine-optimized-wasi.wasm`, which does encode successfully through all tested pass prefixes.

## Release Artifact Change Matrix

Input: `tests/node/dist/starshine-optimized-wasi.wasm` (`7834197` bytes)

Prefix commands:
- Starshine: `STARSHINE_OPTIMIZE_MAX_PASSES=<N> _build/native/release/build/cmd/cmd.exe --optimize -O2 --out ... tests/node/dist/starshine-optimized-wasi.wasm`
- Binaryen: `wasm-opt tests/node/dist/starshine-optimized-wasi.wasm --all-features <implemented-pass-prefix> -o ...`

Stage results:

| Stage | Implemented pass prefix | Binaryen size | Starshine size | Same normalized WAT |
| --- | --- | ---: | ---: | --- |
| 01 | `DFE` | `7101082` | `7096917` | no |
| 02 | `DFE -> RUME` | `7101082` | `7096917` | no |
| 03 | `DFE -> RUME -> MP` | `7098802` | `7094637` | no |
| 04 | `... -> OnceReduction` | `7098802` | `7094637` | no |
| 05 | `... -> DCE` | `7098017` | `7094637` | no |
| 06 | `... -> DFE(post)` | `6943532` | `7094637` | no |
| 07 | `... -> RUME(post)` | `6943532` | `7094637` | no |

Per-tool stage activity:

- Starshine:
  - `01 -> 02`: no change
  - `02 -> 03`: changed
  - `03 -> 04`: no change
  - `04 -> 05`: no change
  - `05 -> 06`: no change
  - `06 -> 07`: no change
- Binaryen:
  - `01 -> 02`: no change
  - `02 -> 03`: changed
  - `03 -> 04`: no change
  - `04 -> 05`: changed
  - `05 -> 06`: changed
  - `06 -> 07`: no change

Immediate reading:
- `RemoveUnusedModuleElements` has no observable effect at either cleanup site on this artifact for either tool.
- `MemoryPacking` changes both tools on this artifact.
- `OnceReduction` has no observable effect on this artifact for either tool.
- `DeadCodeElimination` changes Binaryen but not Starshine on this artifact.
- the second `DuplicateFunctionElimination` changes Binaryen but not Starshine on this artifact.

## Parity Findings

### 1. The debug artifact has an encode blocker before pass parity can even be measured

This is the first concrete blocker from the direct artifact run:
- Starshine cannot emit any optimized output for `tests/node/dist/starshine-debug-wasi.wasm`.
- The failure is stable across truncated prefixes and the full optimize run.
- That is a toolchain-output blocker, not a mere textual-diff issue.

### 2. Starshine diverges from Binaryen already after the first implemented pass

Even on the release artifact, `DuplicateFunctionElimination` does not match Binaryen.

After coarse normalization that strips numeric `$<id>` names, the first surviving semantic diff still includes body-shape differences, for example:
- Binaryen keeps explicit trailing `unreachable` sentinels in at least one function where Starshine drops them.
- the resulting normalized WAT still differs after the first pass, so this is not just encoder byte layout or type-index numbering noise.

### 3. `MemoryPacking` changes both tools, but the earlier mismatch survives through it

`MemoryPacking` is active in both tools on the release artifact:
- Binaryen: `7101082 -> 7098802`
- Starshine: `7096917 -> 7094637`

However, the normalized outputs still do not match after that stage. So this artifact does not support a “first mismatch only appears in MemoryPacking” reading; the disagreement is already present and remains live through `MemoryPacking`.

### 4. `DeadCodeElimination` is a real parity gap on this artifact

At the DCE stage:
- Binaryen changes the module: `7098802 -> 7098017`
- Starshine does not change the module at all: `7094637 -> 7094637`

The normalized diff shows concrete control-shape mismatches in a branch-heavy function:
- Binaryen rewrites some `if` / `loop` forms to non-result versions and leaves explicit `unreachable` sentinels.
- Starshine keeps result-typed control forms in the same region and omits those explicit `unreachable` tails.

So the current local `DeadCodeElimination` implementation is not just “smaller scope in theory”; it is observably missing Binaryen changes on the Starshine release artifact itself.

### 5. The post-function `DuplicateFunctionElimination` is another large parity gap

At the second DFE slot:
- Binaryen changes the module: `7098017 -> 6943532`
- Starshine still does nothing: `7094637 -> 7094637`

The normalized diff shows repeated wrapper-style functions still present in Starshine output after the post pass, while Binaryen has already merged or removed the corresponding duplicates.

This is the largest size delta in the comparison:
- Binaryen final implemented-prefix output: `6943532`
- Starshine final implemented-prefix output: `7094637`
- gap: `151105` bytes

### 6. `StringGathering` was not exercised by this artifact

The current Starshine wasm artifact does not schedule `StringGathering` in the default implemented sequence, so this comparison cannot say anything about Binaryen parity for that pass on this input.

## Correctness Constraints
- Fix the debug-artifact `InvalidNameMapOrder` encode failure before using that artifact as the canonical self-optimization parity target.
- Keep comparing through the generated pipeline surface, not the legacy explicit-pass no-op surface.
- Treat the release-artifact DCE and post-DFE gaps as separate blockers:
  - DCE body-shape parity
  - post-DFE duplicate cleanup parity
- Do not collapse these into “layout-only” differences; the normalized diffs still show real structural mismatches.

## Validation Plan
1. Add a regression harness that runs Starshine pass-prefix optimize on `tests/node/dist/starshine-optimized-wasi.wasm` and records:
   - output size
   - whether the prefix changes the module
2. Add a direct regression for the debug-artifact optimize encode failure so `InvalidNameMapOrder` is fixed intentionally instead of rediscovered ad hoc.
3. Add focused parity fixtures extracted from the release-artifact diffs for:
   - the DCE result-typed `if` / `loop` region
   - the post-DFE repeated wrapper-function cluster
4. Re-run the full direct artifact comparison after those blockers land.

## Performance Impact
- The current largest missed optimization on the release artifact is the post-DFE cleanup gap: Binaryen is `151105` bytes smaller after the implemented-pass prefix sequence.
- Binaryen also finds an extra DCE shrink step (`785` bytes) that Starshine currently misses on this artifact.
- The debug-artifact encode failure prevents any self-optimization output measurement there.

## Open Questions
1. Is `InvalidNameMapOrder` caused by the pass transforms themselves, or by encoder/name-section repair that the optimize path is currently skipping?
2. Which specific release-artifact duplicate wrapper cluster is Binaryen collapsing in the second DFE slot that Starshine still misses?
3. For the release-artifact DCE mismatch, should Starshine copy Binaryen’s exact unreachable/control-shape policy, or is a smaller alternate shape acceptable if the effect is proven equivalent and the later passes still recover the same cleanups?
