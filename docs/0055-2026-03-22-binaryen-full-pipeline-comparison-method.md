# Binaryen Full-Pipeline Comparison Method

Status: method correction for Starshine wasm artifact parity against Binaryen `wasm-opt version 125`.

## Scope
- Clarify whether the current artifact comparison is using Binaryen's exact `-O2` behavior or an approximation.
- Record the artifact-local `wasm-opt -O2` pass surface that actually runs on the checked-in Starshine wasm artifacts.
- Define the comparison-method changes needed so future parity claims are against Binaryen's real optimize pipeline, not a hand-picked pass list.

## Current Behavior

`docs/0054-2026-03-22-starshine-wasm-implemented-pass-comparison.md` does **not** run Binaryen's full optimize pipeline.

Its Binaryen side uses explicit direct pass prefixes of the form:

```bash
wasm-opt tests/node/dist/starshine-optimized-wasi.wasm \
  --all-features \
  <implemented-pass-prefix> \
  -o ...
```

That isolates the currently implemented Starshine pass names, but it does **not** do exactly what `wasm-opt -O2` does on the artifact.

The missing surface is not trivial cleanup noise. Binaryen's real `-O2` run interleaves many cleanup and canonicalization passes between and after those headline passes, including repeated `remove-unused-names`, `remove-unused-brs`, `vacuum`, `merge-blocks`, `reorder-locals`, and nested optimizing subpipelines.

## Investigation

### 1. Binaryen documents the default optimizer as a pipeline, not a flat pass list

Binaryen's own README says the default optimization pipeline is set up by functions like `addDefaultFunctionOptimizationPasses`, not by a single fixed direct-pass list.

Relevant source references:
- https://github.com/WebAssembly/binaryen/blob/main/README.md
- https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp

### 2. Local `wasm-opt -O2 --debug` traces show the real artifact-local pass order

I traced both checked-in artifacts directly:

```bash
wasm-opt tests/node/dist/starshine-optimized-wasi.wasm \
  --all-features -O2 --debug \
  -o /tmp/binaryen-release-o2.wasm \
  2> /tmp/binaryen-release-o2.debug

wasm-opt tests/node/dist/starshine-debug-wasi.wasm \
  --all-features -O2 --debug \
  -o /tmp/binaryen-debug-o2.wasm \
  2> /tmp/binaryen-debug-o2.debug
```

Extracting the first visible pass names:

```bash
rg -o 'running pass: [^.]+' /tmp/binaryen-release-o2.debug | sed 's/.*running pass: //' | head -n 80
rg -o 'running pass: [^.]+' /tmp/binaryen-debug-o2.debug | sed 's/.*running pass: //' | head -n 80
```

Both artifacts share the same leading `-O2` surface:

1. `duplicate-function-elimination`
2. `remove-unused-module-elements`
3. `memory-packing`
4. `once-reduction`
5. `global-refining`
6. `remove-unused-module-elements`
7. `gsi`
8. `dce`
9. `remove-unused-names`
10. `remove-unused-brs`
11. `remove-unused-names`
12. `optimize-instructions`
13. `heap-store-optimization`
14. `pick-load-signs`
15. `precompute`
16. `code-pushing`
17. `tuple-optimization`
18. `simplify-locals-nostructure`
19. `vacuum`
20. `reorder-locals`
21. `remove-unused-brs`
22. `heap2local`
23. `optimize-casts`
24. `local-subtyping`
25. `coalesce-locals`
26. `simplify-locals`
27. `vacuum`
28. `reorder-locals`
29. `coalesce-locals`
30. `reorder-locals`
31. `vacuum`
32. `merge-blocks`
33. `remove-unused-brs`
34. `remove-unused-names`
35. `merge-blocks`
36. `precompute`
37. `optimize-instructions`
38. `heap-store-optimization`
39. `rse`
40. `vacuum`
41. `dae-optimizing`
42. nested optimizing cleanup prefix begins again

So the earlier direct-pass-prefix comparison in `docs/0054-2026-03-22-starshine-wasm-implemented-pass-comparison.md` omitted a large amount of Binaryen's real `-O2` behavior.

### 3. `Vacuum` is part of the real cleanup, but not the whole cleanup story

`Vacuum` is absolutely part of Binaryen's normal cleanup path, and it appears multiple times in the real trace. But it is only one member of a broader cleanup/canonicalization pack that also includes:

- `remove-unused-names`
- `remove-unused-brs`
- `merge-blocks`
- `reorder-locals`
- `simplify-locals`
- `optimize-instructions`
- `precompute`
- `rse`

So a comparison that runs only the headline implemented passes and skips those cleanup passes is not an exact Binaryen comparison.

### 4. Intermediate invalidity is not the comparison target; final output is

During this investigation, a one-pass Starshine DFE-only debug-artifact output was shown to be invalid by `wasm-tools validate`:

```bash
wasm-tools validate /tmp/starshine-debug-diagnostic-pass1.wasm
```

That is useful for local debugging, but it is **not** the parity contract by itself. The real parity target is the final emitted `--optimize -O2` result.

The relevant final-state finding is:
- Binaryen full `wasm-opt -O2` succeeds on both checked-in artifacts.
- Starshine full `--optimize -O2` still fails on `tests/node/dist/starshine-debug-wasi.wasm`.

That final-output failure is a real blocker. Intermediate temporary invalid states inside the pipeline are not.

## Required Method Changes

### 1. Separate final-output parity from stage-attribution parity

Future artifact comparisons should produce two distinct results:

1. `Final full-pipeline parity`
   - Starshine: full `--optimize -O2`
   - Binaryen: full `wasm-opt -O2`
   - this is the primary user-facing parity result

2. `Exact prefix attribution`
   - derived from the actual Binaryen `-O2 --debug` trace for that artifact
   - used only to explain where divergence first appears inside the real pipeline

The old direct implemented-pass prefix should not be treated as the main parity result anymore.

### 2. Stop using hand-picked Binaryen explicit pass lists as the canonical comparison

The old style:

```bash
wasm-opt input.wasm --all-features duplicate-function-elimination remove-unused-module-elements ...
```

is still useful for narrow experiments, but it is not the exact optimize-pipeline comparison and should be labeled as such if retained.

### 3. For stage-level comparisons, replay exact traced prefixes, not just implemented pass names

If we want stage checkpoints, the Binaryen side must replay prefixes extracted from the real traced `-O2` sequence, including cleanup passes that naturally occur between the implemented passes.

For example, after Binaryen's first visible `dce`, the exact prefix is not:

```text
DFE -> RUME -> MP -> OnceReduction -> DCE
```

It is at least:

```text
DFE -> RUME -> MP -> OnceReduction -> GlobalRefining -> RUME -> GSI -> DCE
```

and the next immediately visible cleanup steps are:

```text
RemoveUnusedNames -> RemoveUnusedBrs -> RemoveUnusedNames -> OptimizeInstructions -> ...
```

So any Binaryen checkpoint that skips those passes is not an exact `-O2` checkpoint.

### 4. Treat nested/convergence subpipelines as part of the real pass surface

The `-O2 --debug` traces show nested work for passes like:
- `duplicate-function-elimination`
- `memory-packing`
- `once-reduction`
- `dae-optimizing`

That means the real comparison surface is not a single flat list of top-level pass names. Future docs and harnesses should either:
- preserve those nested groups as opaque exact Binaryen stages, or
- reconstruct them faithfully from the trace when replaying prefixes.

They should not be silently discarded.

### 5. Artifact-local feature detection matters

The exact Binaryen schedule is feature-sensitive. The comparison harness must continue to run on the real artifact with its real enabled features:

```bash
wasm-opt <artifact> --all-features -O2 ...
```

and must not assume that one generic pass list covers every artifact.

## Updated Comparison Commands

### Full final-output comparison

Starshine:

```bash
_build/native/release/build/cmd/cmd.exe \
  --optimize -O2 \
  --out /tmp/starshine-final.wasm \
  tests/node/dist/starshine-optimized-wasi.wasm
```

Binaryen:

```bash
wasm-opt tests/node/dist/starshine-optimized-wasi.wasm \
  --all-features -O2 \
  -o /tmp/binaryen-final.wasm
```

### Exact traced-prefix extraction

```bash
wasm-opt tests/node/dist/starshine-optimized-wasi.wasm \
  --all-features -O2 --debug \
  -o /tmp/binaryen-final.wasm \
  2> /tmp/binaryen-o2.debug

rg -o 'running pass: [^.]+' /tmp/binaryen-o2.debug | sed 's/.*running pass: //'
```

### Exact prefix checkpoint replay

If stage replay is needed, build the Binaryen explicit pass prefix from the actual traced `-O2` prefix, not from the Starshine implemented-pass inventory.

## Correctness Constraints
- Do not call a Binaryen comparison "exact" unless the Binaryen side is a full `-O2` run or a prefix extracted from that actual traced `-O2` run.
- Do not treat intermediate invalid Starshine states as parity failures by themselves.
- Do treat final full-pipeline invalid output as a real parity blocker.
- Keep the Binaryen version pinned in the doc because pass order can change across releases.

## Validation Plan
1. Replace the primary Binaryen command in the artifact comparison doc with full `wasm-opt -O2`.
2. Add a second section that records the traced artifact-local Binaryen pass order from `--debug`.
3. If stage checkpoints are still needed, regenerate them from the traced exact prefix rather than from the direct implemented-pass list.
4. Re-run the debug and release artifact comparisons under that corrected method.
5. Reclassify any gap that disappears once Binaryen's cleanup passes are included; keep only the gaps that survive the exact full-pipeline comparison.

## Performance Impact
- The corrected method is more expensive because full `-O2 --debug` tracing is heavier than direct explicit pass replay.
- But it removes a methodology bug: previously we were attributing some differences against a Binaryen execution mode that is not the one users actually invoke with `-O2`.
- That should reduce false-positive parity gaps and sharpen the real remaining blockers.

## Open Questions
1. Should the repo keep the old direct implemented-pass-prefix comparison as a secondary micro-benchmark, as long as it is clearly labeled non-canonical?
2. Do we want a small harness that automatically converts `wasm-opt -O2 --debug` traces into reproducible exact Binaryen checkpoint prefixes?
3. For nested Binaryen pass groups, should Starshine docs report the top-level pass only, or preserve the nested cleanup subpipeline as a distinct comparison unit?
