# Fresh-Artifact `DFE -> RUME -> MemoryPacking` Parity Checkpoint

Status: fresh rebuilt release-artifact checkpoint after the direct `DuplicateFunctionElimination` parity repair in commit `74614a6`.

## Scope
- Input artifact:
  - `_build/wasm/release/build/cmd/cmd.wasm`
- Shared pass prefix:
  1. `DuplicateFunctionElimination`
  2. `RemoveUnusedModuleElements`
  3. `MemoryPacking`
- Goal:
  - determine whether adding `MemoryPacking` after the aligned `DFE -> RUME` prefix introduces a fresh parity or correctness gap versus Binaryen

## Current Behavior

Commands:

```bash
moon run src/cmd --target native -- \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --memory-packing \
  --out /tmp/starshine-dfe-rume-mp-fresh.wasm \
  _build/wasm/release/build/cmd/cmd.wasm

wasm-opt _build/wasm/release/build/cmd/cmd.wasm \
  --all-features \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --memory-packing \
  -o /tmp/binaryen-dfe-rume-mp-fresh.wasm
```

Observed outputs:

| Tool | Size | Defined funcs | Types | Elements | Data bytes | Data segments | Validates |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Starshine `DFE -> RUME` | `2355110` | `2892` | `109` | `1192` | `176566` | `1` | yes |
| Starshine `DFE -> RUME -> MP` | `2353318` | `2892` | `109` | `1192` | `174773` | `936` | yes |
| Binaryen `DFE -> RUME` | `2376579` | `2892` | `110` | `562` | `176566` | `1` | yes |
| Binaryen `DFE -> RUME -> MP` | `2374787` | `2892` | `110` | `562` | `174773` | `936` | yes |

Per-tool delta from the prior prefix:

- Starshine: `2355110 -> 2353318` (`-1792`)
- Binaryen: `2376579 -> 2374787` (`-1792`)

Visible section changes on both tools:

- `code` section: unchanged
- `data count` section: `1` byte -> `2` bytes
- `data` section: `176566` bytes / `1` segment -> `174773` bytes / `936` segments

## Correctness Constraints
- Treat this as a clean parity checkpoint for this artifact, not as proof that `MemoryPacking` is fully parity-complete on every module shape.
- Keep the fresh-artifact conclusion narrow: after the repaired direct DFE pass, `MemoryPacking` produces the same coarse observable shrink as Binaryen on this module and does not introduce a validation failure.
- Do not attribute the remaining Starshine/Binaryen gap on this artifact to `MemoryPacking`; the shrink delta is matched exactly.

## Validation Plan
1. Reuse the same fresh rebuilt artifact for the next shared pass prefix (`DFE -> RUME -> MP -> OnceReduction`).
2. Preserve exact before/after byte comparisons against the `DFE -> RUME -> MP` checkpoint so later no-op passes are distinguishable from preexisting serializer/layout drift.
3. If a later prefix diverges, compare section deltas first to determine whether the first real difference is code cleanup, element/table rewrites, or another representation issue.

## Performance Impact
- Positive and matched on this artifact: both tools reduce the module by `1792` bytes.
- The shrink comes from identical data-segment repacking effects, not from function/code changes.

## Open Questions
- Does another artifact expose a real `MemoryPacking` profitability or correctness gap that this fresh rebuilt release artifact does not?
- Is the remaining `109` vs `110` type-count difference entirely serializer/layout drift, or does Starshine still normalize one safe-but-non-Binaryen type identity after the shared prefix?
- Does `OnceReduction` become the first later shared pass with a real fresh-artifact Starshine/Binaryen behavior delta?
