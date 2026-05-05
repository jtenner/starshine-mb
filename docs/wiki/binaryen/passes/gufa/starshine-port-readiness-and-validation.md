---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-gufa-current-main-recheck.md
  - ../../../raw/research/0471-2026-05-05-gufa-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-gufa-primary-sources.md
  - ../../../raw/research/0313-2026-04-24-gufa-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_flags.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./content-oracle-variants-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa-optimizing/index.md
  - ../gufa-cast-all/index.md
  - ../type-refining/normal-vs-gufa-and-fixups.md
---

# `gufa` Starshine port-readiness and validation

## Current hold point

Plain `gufa` is still **boundary-only** in Starshine.

The current local hold point is:

- registry name present in `src/passes/optimize.mbt`
- explicit pipeline rejection in `src/cmd/cmd.mbt`
- lower-level hot-pipeline boundary-only rejection in `src/passes/optimize.mbt`
- no `gufa` dispatcher case in `src/passes/pass_manager.mbt`
- no dedicated `src/passes/gufa*.mbt` owner file
- no active preset placement
- no active backlog slice in `agent-todo.md`

## Exact local code map

| Local surface | Current role |
| --- | --- |
| `src/passes/optimize.mbt:127-146` | boundary-only registry names include `gufa`, `gufa-optimizing`, and `gufa-cast-all`. |
| `src/passes/optimize.mbt:307-310` | boundary-only names are added to the registry as non-active entries. |
| `src/passes/optimize.mbt:518-520` | lower-level hot-pipeline expansion rejects boundary-only names as not implemented. |
| `src/cmd/cmd.mbt:618` | the CLI still reports unknown pass flags explicitly. |
| `src/passes/pass_manager.mbt:8933-8936` | active module dispatch currently covers plain `global-struct-inference` and neighboring module passes, not `gufa`. |
| `src/lib/types.mbt:762-4188` | the IR already understands `RefCastDescEq`, so later GUFA-style cast work has a validated instruction surface. |
| `src/ir/hot_core.mbt:70-74` | HOT op vocabulary already includes `RefCastDescEq`. |
| `src/ir/hot_lift.mbt:612-615` / `:764-767` | HOT lifting already maps `RefCastDescEq`. |
| `src/ir/hot_lower.mbt:1080-1083` | HOT lowering already preserves `RefCastDescEq`. |
| `src/ir/hot_flags.mbt` | local effect flags are available for side-effect preservation, but they are not a whole-program oracle. |
| `src/ir/effects.mbt` | function-local effect tracking is available for dropped-child preservation. |
| `src/validate/typecheck.mbt:3266-3267` | validator support already exists for `RefCastDescEq`. |
| `src/binary/encode.mbt:2942-2952` | binary encoding already supports descriptor-equality casts. |
| `src/binary/decode.mbt:3197` | binary decoding already recognizes descriptor-equality casts. |
| `src/wast/lower_to_lib.mbt:2476` | WAT lowering already emits `ref_cast_desc_eq(...)`. |

## What a faithful future port needs

A real Starshine `gufa` port needs a **module-wide contents oracle**, not just more HOT peepholes.

Minimum required pieces:

1. a module owner that can build a closed-world contents oracle
2. a representation for the source-backed result families: no contents, one literal, one global/function identity, one reference cone, and many/unknown
3. a rewrite worker that preserves side effects when replacing expressions by `unreachable`
4. explicit `ref.eq`, `ref.test`, and existing-`ref.cast` specialization
5. a validation/re-finalization step after each function rewrite
6. a separate sibling path for `gufa-optimizing`
7. a separate sibling path for `gufa-cast-all`

## What not to blur together

Do **not** collapse plain `gufa` into any of these:

- ordinary constant folding
- `precompute`
- a generic `ref.cast` insertion pass
- `gufa-optimizing`
- `gufa-cast-all`
- `type-refining-gufa`
- a local boundary-only no-op

Those are different contracts.

## Validation ladder for a future port

A good first validation ladder would be:

1. add a real owner file and dispatch case before accepting the pass flag
2. prove the plain `gufa.wast` families:
   - unreachable parameter / no-contents rewrite
   - one known helper result
   - impossible `ref.eq`
   - guaranteed / impossible `ref.test`
   - existing `ref.cast` narrowing
3. add negative tests for:
   - tuple-typed results
   - ordered atomics / synchronization-sensitive sites
   - known-but-not-materializable `global.get` / `ref.func` type mismatches
   - export / open-world boundaries
4. add the `gufa-optimizing` cleanup delta
5. add the `gufa-cast-all` cast-materialization delta
6. compare against Binaryen with a pass-targeted fuzz lane once the oracle is broad enough

## Starshine page map

- [`./index.md`](./index.md) — overview, invariants, and current status.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) — upstream `ContentOracle` and sibling split.
- [`./content-oracle-variants-and-boundaries.md`](./content-oracle-variants-and-boundaries.md) — oracle result families and bailout boundaries.
- [`./wat-shapes.md`](./wat-shapes.md) — concrete before/after families.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) — upstream owner/test map.
- [`./starshine-strategy.md`](./starshine-strategy.md) — current local status and future-port map.

## Current local conclusion

Starshine should keep plain `gufa` boundary-only until a module-wide contents oracle exists. The IR / HOT / validation / binary surfaces already support the needed instruction vocabulary, but they do not replace the missing oracle and rewrite ownership.
