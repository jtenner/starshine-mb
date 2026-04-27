---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md
  - ../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/ir/use_def.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./single-load-chains-and-bailouts.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-added-constants/index.md
  - ../simplify-locals/index.md
---

# Starshine port-readiness and validation for `avoid-reinterprets`

## Purpose

This page turns the source-backed `avoid-reinterprets` dossier into an implementation-readiness map.
It answers a narrower question than [`./starshine-strategy.md`](./starshine-strategy.md):

> if Starshine later ports this removed pass, what should the first safe slice be, which local code should a developer read, and how should the port be validated without overgeneralizing Binaryen's contract?

The first direct-load slice is now implemented in Starshine as an active module pass.
The remaining implementation debt is the indirect `reinterpret(local.get <- load)` helper-local family.

## Beginner mental model

Binaryen `avoid-reinterprets` does not generally remove every reinterpret.
It only avoids some reinterprets of full-width loads.

Two families matter:

1. direct case: `reinterpret(load)` can become a load of the reinterpreted type;
2. indirect case: `reinterpret(local.get)` can use a helper local only when the `local.get` is proven to come from one full-width source load.

Starshine has landed the direct case; a future slice should attempt the harder local-chain proof only after documenting the LocalGraph-equivalent provenance rule.

## Current local status

- `avoid-reinterprets` is now an active module pass in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The dispatcher routes it through [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
- The implementation lives in [`src/passes/avoid_reinterprets.mbt`](../../../../../src/passes/avoid_reinterprets.mbt).
- Focused coverage lives in [`src/passes/avoid_reinterprets_test.mbt`](../../../../../src/passes/avoid_reinterprets_test.mbt).
- It is intentionally not part of the default `optimize` / `shrink` presets yet.

## Landed first implementation slice: direct load flips

The current implementation handles direct `reinterpret(load)` shapes only.

### Target shape

```wat
(f32.reinterpret_i32 (i32.load (i32.const 16)))
```

becomes:

```wat
(f32.load (i32.const 16))
```

and the same direct family exists for:

- `i32.reinterpret_f32 (f32.load ...) -> i32.load ...`
- `f64.reinterpret_i64 (i64.load ...) -> f64.load ...`
- `i64.reinterpret_f64 (f64.load ...) -> i64.load ...`

### Why this should be first

This slice avoids Binaryen's hardest proof obligation.
It does not need `LocalGraph`, local SSA, helper locals, copy chains, or wrapper fallthrough.
It only needs to recognize:

- one of the four reinterpret unary opcodes,
- one direct full-width `Load` child,
- and a result type pair that matches the reinterpret.

### Local code to read first

- Reinterpret opcode representation:
  - [`src/lib/types.mbt:3920-3936`](../../../../../src/lib/types.mbt#L3920-L3936)
  - [`src/lib/types.mbt:5862-5878`](../../../../../src/lib/types.mbt#L5862-L5878)
- WAT-to-lib lowering:
  - [`src/wast/lower_to_lib.mbt:1280-1283`](../../../../../src/wast/lower_to_lib.mbt#L1280-L1283)
- Validation rules for the four reinterprets:
  - [`src/validate/typecheck.mbt:3457-3461`](../../../../../src/validate/typecheck.mbt#L3457-L3461)
- HOT lift/lower roundtrip surface:
  - [`src/ir/hot_lift.mbt:947-952`](../../../../../src/ir/hot_lift.mbt#L947-L952)
  - [`src/ir/hot_lower.mbt:1082-1088`](../../../../../src/ir/hot_lower.mbt#L1082-L1088)
- HOT node builders:
  - [`src/ir/hot_builders.mbt:533-546`](../../../../../src/ir/hot_builders.mbt#L533-L546) for loads
  - [`src/ir/hot_builders.mbt:608-618`](../../../../../src/ir/hot_builders.mbt#L608-L618) for unary nodes
- Binary encoding:
  - [`src/binary/encode.mbt:2557-2560`](../../../../../src/binary/encode.mbt#L2557-L2560)

### Reduced tests for slice 1

Add focused fixtures before changing the registry category:

| Fixture | Expected result |
| --- | --- |
| direct `f32.reinterpret_i32 (i32.load ...)` | direct `f32.load ...` |
| direct `i32.reinterpret_f32 (f32.load ...)` | direct `i32.load ...` |
| direct `f64.reinterpret_i64 (i64.load ...)` | direct `f64.load ...` |
| direct `i64.reinterpret_f64 (f64.load ...)` | direct `i64.load ...` |
| direct partial load, such as `i32.load16_u` | unchanged |
| reinterpret of non-load expression | unchanged |

Compare those fixtures against Binaryen with `wasm-opt --avoid-reinterprets` before moving on.

## Second implementation slice: indirect local-get users

The direct slice is green; the next Starshine slice should implement Binaryen's indirect family:

```wat
(local.set $x (i32.load (i32.const 16)))
(drop (f32.reinterpret_i32 (local.get $x)))
```

Binaryen rewrites this by:

1. saving the pointer in a helper local,
2. loading the same address as the alternate type into another helper local,
3. preserving the original load result for ordinary users,
4. replacing proven reinterpret users with the alternate helper local.

## The missing Starshine proof obligation

The indirect family is not just a use-def lookup.
Binaryen's `getSingleLoad(...)` requires:

- exactly one reaching set,
- no `nullptr` entry / parameter source,
- fallthrough normalization of the reaching-set value,
- copy-chain following through `local.get`,
- a successful terminal `Load`,
- cycle bailout for unreachable-copy loops,
- and full-width reachable-load filtering after the provenance proof.

Starshine currently has useful pieces, but no documented exact equivalent:

- [`src/ir/use_def.mbt:29-31`](../../../../../src/ir/use_def.mbt#L29-L31) stores local read/write lists and write-block sets.
- [`src/ir/use_def.mbt:82-94`](../../../../../src/ir/use_def.mbt#L82-L94) records `LocalGet`, `LocalSet`, and `LocalTee` nodes.
- [`src/ir/use_def.mbt:390-395`](../../../../../src/ir/use_def.mbt#L390-L395) exposes local read-node queries.
- [`src/ir/ssa_local.mbt:96-118`](../../../../../src/ir/ssa_local.mbt#L96-L118) maps local gets and writes to SSA values.
- [`src/ir/ssa_local.mbt:291-301`](../../../../../src/ir/ssa_local.mbt#L291-L301) creates entry definitions for locals.
- [`src/ir/ssa_local.mbt:329-352`](../../../../../src/ir/ssa_local.mbt#L329-L352) exposes local-get and local-write value IDs.
- [`src/ir/ssa_local.mbt:388-393`](../../../../../src/ir/ssa_local.mbt#L388-L393) exposes uses of an SSA value.

The port should choose one of these strategies explicitly:

1. a small pass-local reaching-set proof just for `avoid-reinterprets`,
2. a documented HOT local-SSA classifier with exact Binaryen-compatible behavior,
3. or a shared LocalGraph-like helper for future locals-family ports.

Do not describe existing use-def or HOT SSA as a drop-in `LocalGraph` equivalent until the entry, merge, wrapper, and unreachable-cycle rules are proven.

## Helper-local rewrite requirements

For the indirect slice, the local output shape needs these local primitives:

- local get/set/tee builders at [`src/ir/hot_builders.mbt:296-333`](../../../../../src/ir/hot_builders.mbt#L296-L333),
- load builders at [`src/ir/hot_builders.mbt:533-546`](../../../../../src/ir/hot_builders.mbt#L533-L546),
- fresh body-local allocation at [`src/ir/hot_mutate.mbt:196-201`](../../../../../src/ir/hot_mutate.mbt#L196-L201),
- memarg side-table access through the HOT load builder and `HotMemArg` side table.

Preserve these Binaryen rules:

- one alternate helper local should be shared by all proven reinterpret users of one source load;
- ordinary users of the original load must still see the original type;
- partial loads must stay unchanged;
- non-fallthrough wrappers must stay unchanged;
- parameter/default-entry and multi-source merge cases must stay unchanged;
- memory64 pointer helper locals must be `i64`, not hardcoded `i32`.

## Validation ladder

### 0. Registry honesty

Before the transform exists, keep removed-name rejection green.
When the transform lands, change registry category and tests in the same change.

### 1. Direct-load fixtures

Prove all four direct reinterpret/load pairs and partial-load no-ops.
This is the first implementation slice.

### 2. Single indirect user

Prove one `local.set` from one full-width load and one reinterpret user.
Inspect the output shape for pointer helper and alternate typed helper locals.

### 3. Shared helper local

Prove two reinterpret users of the same source load share one alternate helper local.

### 4. Mixed original and reinterpret uses

Prove ordinary original-type uses remain valid while reinterpret users switch to the alternate helper.

### 5. Copy chains

Prove a simple `load -> local.set x -> local.set y (local.get x) -> reinterpret(local.get y)` chain only after the single-load proof can explain why it is unique.

### 6. Bailout matrix

Keep no-op fixtures for:

- partial loads,
- params and default-entry values,
- multiple reaching definitions,
- non-fallthrough wrappers,
- unreachable or cyclic unsupported local webs,
- non-load origins.

### 7. Memory64

Mirror the indirect fixtures under memory64 and assert the pointer helper local is `i64`.
Use Binaryen's `avoid-reinterprets64.wast` as the oracle shape family.

### 8. Binaryen oracle comparison

Once reduced fixtures are green, compare against official Binaryen for the dedicated lit families:

- `avoid-reinterprets.wast`
- `avoid-reinterprets64.wast`

Then use the pass-targeted harness if the pass is promoted into the local registry.

### 9. Fuzz only after reduced fixtures

Fuzzing is useful only after reduced fixtures separate known classes:

- direct positives,
- indirect positives,
- helper sharing,
- mixed-use preservation,
- local-chain bailouts,
- memory64 pointer typing.

Otherwise failures will not tell whether the bug is opcode recognition, width filtering, local provenance, helper-local construction, or lowering.

## Cross-pass boundaries

### `optimize-added-constants`

[`../optimize-added-constants/index.md`](../optimize-added-constants/index.md) also rewrites load syntax, but it folds address arithmetic into memory offsets.
`avoid-reinterprets` changes the loaded view type and may duplicate a same-address load.
Do not share a vague “memory-load optimizer” contract between them.

### `simplify-locals`

[`../simplify-locals/index.md`](../simplify-locals/index.md) may clean up local traffic around the helper locals created here.
That cleanup is a later interaction, not part of `avoid-reinterprets` correctness.
The pass itself must preserve both original and alternate views before any cleanup runs.

## Bottom line

`avoid-reinterprets` is ready for future Starshine implementation planning, but not implemented.
The source-backed first slice is direct full-width reinterpret/load flipping.
The second slice requires a documented single-load provenance helper before Starshine should add Binaryen's indirect helper-local rewrite.
