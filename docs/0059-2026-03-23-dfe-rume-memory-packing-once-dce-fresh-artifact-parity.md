# Fresh-Artifact `DFE -> RUME -> MemoryPacking -> OnceReduction -> DCE` Parity Checkpoint

Status: fresh rebuilt release-artifact checkpoint after the direct `DuplicateFunctionElimination` parity repair in commit `74614a6`.

## Scope
- Input artifact:
  - `_build/wasm/release/build/cmd/cmd.wasm`
- Shared pass prefix:
  1. `DuplicateFunctionElimination`
  2. `RemoveUnusedModuleElements`
  3. `MemoryPacking`
  4. `OnceReduction`
  5. `DeadCodeElimination`
- Goal:
  - determine whether `DeadCodeElimination` is the first later shared pass with a real fresh-artifact parity or correctness gap after the repaired DFE prefix

## Current Behavior

Commands:

```bash
moon run src/cmd --target native -- \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --memory-packing \
  --once-reduction \
  --dead-code-elimination \
  --out /tmp/starshine-dfe-rume-mp-once-dce-fresh.wasm \
  _build/wasm/release/build/cmd/cmd.wasm

wasm-opt _build/wasm/release/build/cmd/cmd.wasm \
  --all-features \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --memory-packing \
  --once-reduction \
  --dce \
  -o /tmp/binaryen-dfe-rume-mp-once-dce-fresh.wasm
```

Observed outputs:

| Tool | Prior prefix size | With DCE | Delta | Code bytes | Validates |
| --- | ---: | ---: | ---: | ---: | --- |
| Starshine | `2353318` | `2353318` | `0` | `2165633` | yes |
| Binaryen | `2374787` | `2374783` | `-4` | `2187726` | yes |

Byte-for-byte checks against the prior prefix:

```bash
cmp -s /tmp/starshine-dfe-rume-mp-once-fresh.wasm /tmp/starshine-dfe-rume-mp-once-dce-fresh.wasm
cmp -s /tmp/binaryen-dfe-rume-mp-once-fresh.wasm /tmp/binaryen-dfe-rume-mp-once-dce-fresh.wasm
```

Results:

- Starshine `cmp`: `0`
- Binaryen `cmp`: nonzero

## First Concrete Divergence

Diffing Binaryen's printed WAT before and after DCE shows a small but real cleanup:

- two dead `drop` instructions immediately after unconditional `br 1` tails are removed
- no visible data/table/element changes occur
- the observed size effect is entirely in the `code` section (`-4` bytes)

Representative hunk:

```wat
local.get 6
i32.const 1
i32.add
local.tee 17
br 1 (;@3;)
drop
```

becomes:

```wat
local.get 6
i32.const 1
i32.add
local.tee 17
br 1 (;@3;)
```

Inference: this is a real missing DCE cleanup in Starshine, not a serializer-only difference.

## Correctness Constraints
- Treat this as the first real later-pass optimization gap on the fresh artifact, not as a module-validity problem; both outputs validate.
- Keep the conclusion narrow: the current evidence is dead branch-tail cleanup after unconditional `br`, not a broad DCE correctness failure.
- Do not conflate this with the preexisting serializer/layout drift that already exists before DCE runs.

## Validation Plan
1. Minimize the observed branch-tail shape into a direct DCE whitebox fixture with a dead instruction after an unconditional `br` inside nested control flow.
2. Confirm whether current Starshine DCE already handles the minimal shape; if it does, continue reducing until the artifact-specific missed pattern is exposed.
3. After a fix, rerun the exact fresh-artifact five-pass prefix and confirm Starshine is no longer byte-identical to the `... -> OnceReduction` checkpoint.

## Performance Impact
- Starshine currently misses a small fresh-artifact cleanup opportunity that Binaryen takes (`-4` bytes).
- The gap is tiny, but it is the first later shared-pass proof that the remaining parity drift is not purely earlier-prefix layout noise.

## Open Questions
- Is the missed cleanup reducible to a simple nested-`if` / unconditional-`br` tail truncation case, or does it depend on a more specific typed shape?
- Does fixing this one branch-tail cleanup expose additional fresh-artifact DCE savings immediately afterward?
- After this DCE gap is closed, does the remaining fresh-artifact divergence return entirely to the older serializer/layout difference?
