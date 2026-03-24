# Generated Pre-Lift Dead Branch-Tail Cleanup

Status: fresh rebuilt release-artifact parity recheck after repairing raw-to-typed conversion in `src/validate/env.mbt`.

## Scope
- Input artifact:
  - `_build/wasm/release/build/cmd/cmd.wasm`
- Shared pass prefix under recheck:
  1. `DuplicateFunctionElimination`
  2. `RemoveUnusedModuleElements`
  3. `MemoryPacking`
  4. `OnceReduction`
  5. `DeadCodeElimination`
- Goal:
  - determine whether the earlier fresh-artifact `DeadCodeElimination` parity gap from `docs/0059-2026-03-23-dfe-rume-memory-packing-once-dce-fresh-artifact-parity.md` was a real DCE omission or an earlier generated-path canonicalization bug

## Current Behavior

Focused generated-path witness:

- nested raw control bodies inside `block` / `loop` / `if` / `try_table` are now truncated after the first stack-polymorphic terminator during raw-to-typed conversion
- the top-level generated validation path still preserves stack-polymorphic tails after `unreachable`, so the existing validator coverage for that behavior stays intact
- the minimized `block { i32.const 1; br 1; drop }` fixture now lowers without the dead `drop` even when `run_generated_pipeline_with_options` runs with an empty pipeline

Fresh artifact commands:

```bash
moon run src/cmd --target native -- \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --memory-packing \
  --once-reduction \
  --out /tmp/starshine-dfe-rume-mp-once-fresh-postfix.wasm \
  _build/wasm/release/build/cmd/cmd.wasm

moon run src/cmd --target native -- \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --memory-packing \
  --once-reduction \
  --dead-code-elimination \
  --out /tmp/starshine-dfe-rume-mp-once-dce-fresh-postfix.wasm \
  _build/wasm/release/build/cmd/cmd.wasm

wasm-opt _build/wasm/release/build/cmd/cmd.wasm \
  --all-features \
  --duplicate-function-elimination \
  --remove-unused-module-elements \
  --memory-packing \
  --once-reduction \
  -o /tmp/binaryen-dfe-rume-mp-once-fresh.wasm

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

| Tool | `... -> OnceReduction` | `... -> DCE` | Delta | Code bytes | Validates |
| --- | ---: | ---: | ---: | ---: | --- |
| Starshine | `2352785` | `2352785` | `0` | `2165100` | yes |
| Binaryen | `2374787` | `2374783` | `-4` | `2187726` | yes |

Important comparison against the prior Starshine checkpoint:

| Starshine prefix | Before fix | After fix | Delta |
| --- | ---: | ---: | ---: |
| `DFE -> RUME -> MP -> OnceReduction` | `2353318` | `2352785` | `-533` |
| `DFE -> RUME -> MP -> OnceReduction -> DCE` | `2353318` | `2352785` | `-533` |

Byte-for-byte checks:

```bash
cmp -s /tmp/starshine-dfe-rume-mp-once-fresh-postfix.wasm /tmp/starshine-dfe-rume-mp-once-dce-fresh-postfix.wasm
cmp -s /tmp/binaryen-dfe-rume-mp-once-fresh.wasm /tmp/binaryen-dfe-rume-mp-once-dce-fresh.wasm
```

Results:

- Starshine `cmp`: equal
- Binaryen `cmp`: different

## Root Cause

The earlier `docs/0059` conclusion was too narrow.

The missing cleanup was not primarily in `DeadCodeElimination`. It was earlier in generated raw-to-typed conversion for nested control bodies:

- nested raw `block`, `loop`, `if`, and `try_table` body conversion consumed every raw sibling instruction even after a stack-polymorphic terminator like `br` had already ended the reachable tail
- that preserved dead raw instructions such as `drop` after `br`, which then survived into typed IR and made later explicit DCE comparison look like a pass-local parity miss

After truncating those raw tails during conversion, the exact fresh-artifact `br`-tail `drop` patterns that Binaryen later removes in `--dce` are already absent from Starshine's `... -> OnceReduction` output.

Inference: the old fresh-artifact `DeadCodeElimination` parity regression was a generated pre-lift canonicalization bug, not proof that the local DCE runner still lacks that cleanup.

## Correctness Constraints
- Do not preserve unreachable raw siblings just to force the cleanup to appear later in `DeadCodeElimination`; the typed IR boundary should already exclude dead raw tails.
- This is consistent with the current optimization policy: temporary invalid intermediate pass state is acceptable, but the generated-path cleanup boundary must not serialize dead raw instructions into typed IR.
- Keep the conclusion narrow: this closes the specific branch-tail `drop` parity claim from `docs/0059`, not the broader remaining artifact-size drift versus Binaryen.

## Validation
- `moon test src/cmd`
- `wasm-tools validate /tmp/starshine-dfe-rume-mp-once-fresh-postfix.wasm`
- `wasm-tools validate /tmp/starshine-dfe-rume-mp-once-dce-fresh-postfix.wasm`
- `cmp -s /tmp/starshine-dfe-rume-mp-once-fresh-postfix.wasm /tmp/starshine-dfe-rume-mp-once-dce-fresh-postfix.wasm`
- printed-WAT spot check: the fresh Starshine `... -> OnceReduction` artifact no longer contains the representative `local.tee 17; br 1; drop` tail that still exists in Binaryen before `--dce`

## Performance Impact
- The generated-path fix shrinks both fresh Starshine checkpoints by `533` bytes before DCE even runs.
- The remaining fresh-artifact cross-tool size gap is still large:
  - `... -> OnceReduction`: Binaryen `2374787` vs Starshine `2352785`
  - `... -> DCE`: Binaryen `2374783` vs Starshine `2352785`
- That remaining gap is no longer evidence of this specific DCE miss.

## Open Questions
- How much of the remaining `code` gap comes from other safe early canonicalization differences versus the older serializer/layout drift already visible after direct DFE?
- Should additional raw-to-typed conversion cases truncate other unreachable sibling shapes beyond the current stack-polymorphic terminator rule, or is this now aligned with the intended invariant?
- What is the next real shared-pass parity blocker on the fresh artifact after this reclassification?
