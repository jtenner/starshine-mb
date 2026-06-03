---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md
  - ../../../raw/research/0456-2026-05-05-avoid-reinterprets-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md
  - ../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/avoid_reinterprets.mbt
  - ../../../../../src/passes/avoid_reinterprets_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/ir/use_def.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../alignment-lowering/index.md
  - ../optimize-added-constants/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./single-load-chains-and-bailouts.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../alignment-lowering/index.md
  - ../optimize-added-constants/index.md
---

# Starshine Strategy For `avoid-reinterprets`

Use this page together with the raw primary-source manifests in [`../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`](../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md), [`../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md), and [`../../../raw/binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md).
The goal here is not to re-explain upstream Binaryen, but to show the current Starshine status, local code surfaces, and remaining parity boundary.

## Current status

`avoid-reinterprets` is now **active-partial** in Starshine.
The landed implementation covers the safe first slice: direct full-width load-plus-reinterpret pairs.
The harder Binaryen family, indirect `reinterpret(local.get <- load)` helper-local rewriting, remains future work because it needs a documented single-load provenance proof.

Current local facts:

- implementation owner: [`src/passes/avoid_reinterprets.mbt`](../../../../../src/passes/avoid_reinterprets.mbt#L1-L80)
- focused tests: [`src/passes/avoid_reinterprets_test.mbt`](../../../../../src/passes/avoid_reinterprets_test.mbt#L1-L89)
- active module-pass registry entry: [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt#L258-L261)
- dispatcher arm: [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt#L8922-L8924)
- CLI spelling coverage: [`src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt#L159-L165) and [`src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt#L297-L309)
- no default `optimize` / `shrink` preset slot yet
- no dedicated active `agent-todo.md` follow-up slice yet

## Landed scope

The current pass rewrites these direct adjacent instruction pairs inside function bodies, including nested block/loop/if/try-table bodies:

- `f32.load; i32.reinterpret_f32 -> i32.load`
- `f64.load; i64.reinterpret_f64 -> i64.load`
- `i32.load; f32.reinterpret_i32 -> f32.load`
- `i64.load; f64.reinterpret_i64 -> f64.load`

It intentionally preserves:

- partial loads such as `i32.load16_u`
- reinterpret operations over constants or other non-load values
- all indirect local-chain cases

## Remaining Starshine-specific uncertainty

Binaryen's indirect correctness proof is not just “this value came from a load.”
It asks `LocalGraph` for a single reaching set, rejects entry/parameter values, follows only fallthrough values, rejects cycles, and checks that the source load is reachable and full-width.

Starshine still needs to decide whether to:

1. build a small pass-local reaching-set proof just for this pass,
2. reuse HOT local SSA after documenting exact behavior for params, default values, merges, unreachable cycles, and wrapper fallthrough,
3. or add a LocalGraph-like helper shared with future locals-family ports.

Until that decision lands, the active pass should remain direct-only and outside presets.

## Nearby HOT-IR surfaces for the future indirect slice

The repo already has several low-level tools that will likely matter if the indirect family is ported later:

- node builders for local and load/unary shapes:
  - [`src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt)
- fresh local allocation:
  - [`src/ir/hot_mutate.mbt`](../../../../../src/ir/hot_mutate.mbt)
- local read/write discovery:
  - [`src/ir/use_def.mbt`](../../../../../src/ir/use_def.mbt)
- SSA-like local value mapping:
  - [`src/ir/ssa_local.mbt`](../../../../../src/ir/ssa_local.mbt)

Those files are **not** a finished indirect port.
They identify plausible building blocks for the future single-load provenance proof.

## Boundaries to keep distinct

### `alignment-lowering`

See [`../alignment-lowering/index.md`](../alignment-lowering/index.md).

Both passes touch memory-adjacent syntax, but they prove different things:

- `avoid-reinterprets` changes the loaded value type to avoid reinterpret users.
- `alignment-lowering` legalizes weak alignment by splitting scalar loads/stores into smaller aligned accesses.

### `optimize-added-constants`

See [`../optimize-added-constants/index.md`](../optimize-added-constants/index.md).

Both can rewrite load syntax, but their operands and safety proofs differ:

- `avoid-reinterprets` changes the loaded value type and may later duplicate a same-address load.
- `optimize-added-constants` rewrites address arithmetic into memarg offsets under low-memory safety constraints.

## Validation ladder

Current direct-slice evidence should include:

1. focused WAT-shape tests for all four full-width direct pairs plus non-load no-ops;
2. `moon test src/cmd` for CLI/dispatcher routing;
3. `moon build --target native --release src/cmd` before long compare lanes;
4. `bun scripts/pass-fuzz-compare.ts --pass avoid-reinterprets --generator gen-valid --count 10000 --min-compared 10000 --out-dir .tmp/pass-fuzz-ar-genvalid-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`;
5. a mixed-generator compare-pass run with explicit `--jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`, classifying command failures separately from semantic mismatches;
6. `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --avoid-reinterprets` using a native `cmd` binary when needed for runtime.

Future indirect-slice validation must add positive and negative reduced fixtures for one indirect reinterpret user, multiple users sharing one helper local, mixed original/reinterpret users, copy chains, merge/param/no-fallthrough bailouts, and memory64 pointer-temp typing.

## Bottom line

Current Starshine `avoid-reinterprets` strategy is active but intentionally narrow:

- **direct full-width `reinterpret(load)` flips are implemented**
- **indirect `reinterpret(local.get <- load)` is not implemented**
- **the pass is not in default presets**
- **the future proof obligation is single-load provenance, not generic local propagation**
