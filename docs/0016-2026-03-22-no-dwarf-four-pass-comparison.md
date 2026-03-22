# No-DWARF Four-Pass Comparison

Status: comparison baseline for the first four no-DWARF optimize passes against Binaryen `wasm-opt version 125`.

## Update

The generated pipeline now type-lifts decoded raw `Func` bodies before any generated optimize entry runs, and the explicit CLI flags for these four passes now route through the same generated pipeline surface.

After rerunning the direct comparison:

- `examples/modules/*.wat` still match Binaryen at normalized WAT level for the first four passes.
- The focused `memory-only` fixture now also matches Binaryen at normalized WAT level and binary size.
- The only remaining focused-fixture diff is in `OnceReduction`: Starshine removes the now-redundant `global.set once, 1` in trivial once bodies, while Binaryen keeps it.
- That remaining diff makes Starshine smaller on the targeted once fixtures:
  - `once-only`: Binaryen `59` bytes, Starshine `56` bytes
  - `four-pass-combo`: Binaryen `135` bytes, Starshine `132` bytes

So the original CLI reachability blocker for `OnceReduction` and `MemoryPacking` is resolved. The remaining question is whether Starshine should preserve Binaryen's exact once-body shape, or keep the smaller Starshine output.

## Scope

Compare the first four passes in the no-DWARF optimize pipeline:

1. `duplicate-function-elimination`
2. `remove-unused-module-elements`
3. `memory-packing`
4. `once-reduction`

The goal is not just pass-order parity. The goal is to see what Starshine actually does on real CLI input and whether matching Binaryen would improve optimizer output.

## Current Pipeline Shape

Binaryen `-O2 --debug` reports the first four no-DWARF passes in this exact order:

1. `duplicate-function-elimination`
2. `remove-unused-module-elements`
3. `memory-packing`
4. `once-reduction`

Starshine's generated optimize pipeline matches that order in `src/optimization/optimization.mbt`:

1. `DuplicateFunctionElimination`
2. `RemoveUnusedModuleElements`
3. `MemoryPacking`
4. `OnceReduction`

Important comparison detail:

- The generated `--optimize` surface remains the canonical no-DWARF comparison path.
- The explicit Starshine flags for these four passes now also route through the generated pipeline, so they no longer miss the typed implementations.

For a direct first-four-pass Starshine run, use:

```bash
STARSHINE_OPTIMIZE_MAX_PASSES=4 moon run src/cmd --target native --release -- --optimize -O2 --out out.wasm input.wat
```

For Binaryen, the direct pass match is:

```bash
wasm-opt input.wat \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --memory-packing \
  --once-reduction \
  -o out.wasm
```

I normalized outputs with `wasm-opt --print`, using `--all-features` or `--enable-bulk-memory` where needed.

## Comparison Corpus

### 1. Checked-in examples

Compared `examples/modules/*.wat` through:

- Binaryen explicit four-pass run
- Starshine generated pipeline truncated to four passes

Result:

- `feature_mix`: normalized WAT matched
- `memory64_data`: normalized WAT matched
- `simd_lane_mix`: normalized WAT matched
- `simple`: normalized WAT matched
- `table_dispatch`: normalized WAT matched

Observed size deltas with matched WAT:

- `feature_mix`: Binaryen `105` bytes, Starshine `108` bytes
- `memory64_data`: Binaryen `90` bytes, Starshine `87` bytes
- `simd_lane_mix`: both `55` bytes
- `simple`: both `55` bytes
- `table_dispatch`: both `87` bytes

So the first-four-pass semantics already line up on the checked-in example corpus. Remaining byte differences there are encoder/layout differences, not pass-behavior differences.

### 2. Focused synthetic fixtures

I used three targeted WAT fixtures:

- `once-only`: isolates `once-reduction`
- `memory-only`: isolates `remove-unused-module-elements` + `memory-packing`
- `four-pass-combo`: exercises all four passes together

## Findings

### 1. `DuplicateFunctionElimination` matches on the focused fixture

On the combined fixture:

- Binaryen merged the duplicate `nop` functions.
- Starshine merged the duplicate `nop` functions.
- The caller's second call target was rewritten the same way.

This lines up with the example-corpus parity result.

### 2. `RemoveUnusedModuleElements` also matches the visible dead-item cleanup

On the combined fixture, Starshine matched Binaryen on:

- removing the dead function,
- removing the dead global,
- removing the unused second passive data segment.

Again, this lines up with the example-corpus parity result.

### 3. Historical blocker: `OnceReduction` did not fire on CLI-decoded modules

`once-only` result:

- Binaryen removes the second direct call to the once function.
- Starshine keeps both calls.

`four-pass-combo` result:

- Binaryen rewrites the second once-call to `nop`.
- Starshine keeps the second once-call.

The code-level reason is concrete:

- `src/binary/decode.mbt` decodes code bodies as raw `Func::new(...)`.
- `run_once_reduction` only analyzes and rewrites `@lib.TFunc`.
- So the CLI path (`wat` -> bytes -> `decode_module`) never reaches the typed once-reduction logic on ordinary user inputs.

This blocker is now fixed by pre-lifting raw decoded functions before the generated pipeline runs.

### 4. Historical blocker: `MemoryPacking` only applied its full rewrite on typed bodies

`memory-only` result:

- Binaryen shrinks the passive segment payload from 25 bytes to `HELLO`.
- Binaryen inserts the drop-state global and rewrites the body into `memory.fill` + split `memory.init`.
- Starshine only removes the dead second passive segment and leaves the used segment payload and `memory.init`/`data.drop` sequence structurally unchanged.

`four-pass-combo` shows the same pattern.

The code path explains why:

- `optimization_memory_packing_apply_replacements` has a non-typed rewrite path that only remaps `DataIdx`.
- The real split rewrite lives in `optimization_memory_packing_rewrite_typed_segment_ops_func`.
- That typed rewrite only runs for `TFunc`.
- CLI-decoded modules use raw `Func`, so the full rewrite never runs there.

This blocker is also fixed by the same pre-lift path.

## Output Quality Implication

There are now two different conclusions here.

### Binaryen parity gap

The old CLI reachability gap is closed. The remaining parity delta on focused fixtures is smaller:

- `MemoryPacking` now matches Binaryen on the targeted passive-segment rewrite fixture.
- `OnceReduction` still differs on trivial once bodies because Starshine removes an extra now-redundant `global.set`.

### Optimizer-output question

Binaryen parity is not automatically a size win.

On the tiny focused memory fixture:

- Binaryen output: `100` bytes
- Starshine output: `85` bytes

On the combined four-pass fixture:

- Binaryen output: `138` bytes
- Starshine output: `127` bytes

Binaryen is doing more semantic work there, but the inserted `memory.fill` / guard-global machinery outweighs the saved segment bytes on tiny modules.

So the next step should not be "blindly copy Binaryen output." The next step should be:

1. decide whether exact Binaryen parity for trivial once bodies is worth preserving,
2. benchmark whether Binaryen-faithful `memory-packing` thresholds are actually desirable for Starshine's target corpus.

## Correctness Constraints

- Keep the no-DWARF generated-pass order stable.
- Do not compare new pass behavior through the legacy explicit-pass surface.
- Preserve the existing typed pass tests for `once-reduction` and `memory-packing`.
- If the fix is "type-lift before typed-only passes," validate the lift against both WAT inputs and decoded wasm binaries.
- If the fix is "add raw-body rewrites," keep typed and raw paths aligned and add direct regression tests for both.

## Validation Plan

1. Add integration coverage that runs `STARSHINE_OPTIMIZE_MAX_PASSES=4 --optimize -O2` on focused WAT fixtures and diffs the normalized output against expected Starshine snapshots.
2. Keep one explicit decode-path test proving that a CLI-loaded raw `Func` module is pre-lifted before generated pipeline passes run.
3. After the pipeline/input-shape fix lands, rerun the Binaryen comparison on:
   - `once-only`
   - `memory-only`
   - `four-pass-combo`
   - `examples/modules/*.wat`
4. Benchmark full-corpus size impact before treating Binaryen-faithful `memory-packing` output as an unconditional improvement.

## Performance Impact

- `OnceReduction`: the CLI path now removes redundant once-calls; the remaining parity delta is that Starshine also removes a redundant once-global set in trivial once bodies.
- `MemoryPacking`: the CLI path now reaches the full split rewrite, and the targeted passive-segment fixture matches Binaryen.

That leaves exact `OnceReduction` parity and broader `MemoryPacking` profitability as the remaining output-quality questions.

## Open Questions

1. Should Starshine keep its smaller trivial-once-body rewrite, or preserve Binaryen's exact retained `global.set` shape for closer textual parity?
2. Do Starshine's target corpora actually want Binaryen's current `memory-packing` profitability policy once broader benchmarks are rerun?
