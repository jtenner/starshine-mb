# Fresh-Artifact `DFE -> RUME` Parity Checkpoint

Status: fresh rebuilt release-artifact checkpoint after the direct `DuplicateFunctionElimination` parity repair in commit `74614a6`.

## Scope
- Input artifact:
  - `_build/wasm/release/build/cmd/cmd.wasm`
- Shared pass prefix:
  1. `DuplicateFunctionElimination`
  2. `RemoveUnusedModuleElements`
- Goal:
  - determine whether adding `RemoveUnusedModuleElements` after the now-aligned direct DFE pass introduces a fresh parity gap versus Binaryen

## Current Behavior

Commands:

```bash
moon run src/cmd --target native -- \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --out /tmp/starshine-dfe-rume-fresh.wasm \
  _build/wasm/release/build/cmd/cmd.wasm

wasm-opt _build/wasm/release/build/cmd/cmd.wasm \
  --all-features \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  -o /tmp/binaryen-dfe-rume-fresh.wasm
```

Observed outputs:

| Tool | Size | Defined funcs | Types | Elements | Validates |
| --- | ---: | ---: | ---: | ---: | --- |
| Starshine `DFE -> RUME` | `2355110` | `2892` | `109` | `1192` | yes |
| Binaryen `DFE -> RUME` | `2376579` | `2892` | `110` | `562` | yes |

Byte-for-byte checks against the direct DFE outputs:

```bash
cmp -s /tmp/starshine-dfe-single-pass-bodycanon.wasm /tmp/starshine-dfe-rume-fresh.wasm
cmp -s /tmp/binaryen-dfe-direct-fresh.wasm /tmp/binaryen-dfe-rume-fresh.wasm
```

Both `cmp` calls return `0`.

## Correctness Constraints
- Treat this as a no-op checkpoint, not a proof that `RemoveUnusedModuleElements` is fully parity-complete on all artifacts.
- Keep the fresh-artifact conclusion narrow: after the repaired direct DFE pass, `RemoveUnusedModuleElements` does not introduce any new behavior on this module in either tool.
- Do not attribute the remaining fresh-artifact size delta to `RemoveUnusedModuleElements`; it already exists before this pass runs.

## Validation Plan
1. Reuse the same fresh rebuilt artifact for the next shared pass prefix (`DFE -> RUME -> MemoryPacking`).
2. Preserve exact byte comparisons against the prior prefix to distinguish a real pass effect from existing serializer/layout drift.
3. If a later prefix diverges, compare first against the immediately previous fresh-artifact checkpoint before reopening DFE or RUME.

## Performance Impact
- None on this artifact: `RemoveUnusedModuleElements` is byte-identical to the aligned direct DFE output on both tools.
- The wall-clock overhead is still present because the pass executes, but there is no observed code-size or section-layout change here.

## Open Questions
- Does another fresh artifact or a minimized fixture expose a real `RemoveUnusedModuleElements` parity gap that this module does not?
- Is the remaining `109` vs `110` type-count difference entirely serializer/layout drift, or does Starshine still canonicalize one safe-but-non-Binaryen type identity after DFE?
- Which later shared pass is now the first fresh-artifact prefix that produces a real Starshine/Binaryen behavior delta after the DFE direct-pass repair?
