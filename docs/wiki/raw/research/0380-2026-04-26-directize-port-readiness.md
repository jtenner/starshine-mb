---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-directize-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-directize-current-main-recheck.md
  - ../binaryen/2026-04-22-directize-primary-sources.md
  - ../../binaryen/passes/directize/index.md
  - ../../binaryen/passes/directize/binaryen-strategy.md
  - ../../binaryen/passes/directize/implementation-structure-and-tests.md
  - ../../binaryen/passes/directize/table-info-and-immutability.md
  - ../../binaryen/passes/directize/wat-shapes.md
  - ../../binaryen/passes/directize/starshine-strategy.md
  - ../../binaryen/passes/directize/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/ir/hot_side_tables.mbt
  - ../../../../src/ir/hot_lower.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `directize` port-readiness bridge

## Why this follow-up exists

`directize` already had the standard living dossier: overview, Binaryen strategy, implementation/test map, table-info guide, WAT-shape catalog, and Starshine status page. The health issue was subtler: the tracker still classified the folder as `dossier` while neighboring late-tail blockers had been promoted to `deep`, and the Starshine side still made future implementers infer the first slice and validation ladder from scattered local parser / IR / binary / validation surfaces.

This follow-up keeps the existing dossier as the canonical home and adds one missing bridge:

- `docs/wiki/binaryen/passes/directize/starshine-port-readiness-and-validation.md`

## Primary source added

New raw primary-source bridge:

- `docs/wiki/raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md`

It reuses and rechecks the official Binaryen source families that matter for port planning:

- `Directize.cpp`
- `call-utils.h`
- `table-utils.{h,cpp}`
- `type-updating.h`
- `pass.cpp`
- `passes.h`
- `directize_all-features.wast`
- `directize-gc.wast`
- `directize-wasm64.wast`

The source bridge did not find a new teaching-relevant algorithm drift from the 2026-04-25 current-main bridge. Its value is the explicit mapping from Binaryen source seams to Starshine port slices.

## Durable findings

### 1. Table-info analysis is the first real slice

A future Starshine implementation should not start with a direct `call_indirect` peephole. Binaryen computes table facts first and only then rewrites callsites. The minimum local slice should therefore prove:

- table import/export conservatism,
- flat active element-segment discovery,
- mutation barriers for `table.set`, `table.fill`, destination `table.copy`, and `table.init`,
- ordinary mode versus `directize-initial-contents-immutable`, and
- whole-pass no-op behavior when no table is entry-optimizable.

### 2. The target classifier should be a named local seam

The correct future local unit is a classifier that answers `Known`, `Trap`, or `Unknown`. That seam is easier to validate than a monolithic rewrite function, and it keeps the hardest Binaryen rules visible:

- constant target extraction,
- known hole versus beyond-known-prefix,
- subtype compatibility,
- non-flat table bailout,
- ordinary mutable-table conservatism.

### 3. The first rewrite ladder is finite

The first Starshine rewrite slice should be limited to the source-backed families:

- constant target -> direct `call` / `return_call`,
- known trap -> side-effect-preserving `unreachable`,
- unsupported target -> unchanged `call_indirect`,
- supported `select` -> `if` with one evaluation of operands.

Do not teach or implement generic `call_ref` directization, broad symbolic solving, or partial one-known-arm `select` lowering as part of this pass.

### 4. Existing Starshine primitives are enough for a planned port, but not enough for the pass

The repo already has representations and codecs for the relevant shapes:

- indirect and tail-indirect calls in `src/lib/types.mbt`, `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/wast/parser.mbt`, and `src/wast/lower_to_lib.mbt`,
- table/element/mutation instructions in `src/lib/types.mbt` and WAT lowering,
- HOT side-table / lower support for indirect-call signatures,
- call-indirect validation and negative tests.

Those are prerequisites, not the pass itself. The current pass status remains boundary-only request rejection.

### 5. The folder can now be marked `deep`

With the new port-readiness page, the `directize` folder has the same durable coverage level as neighboring no-DWARF / saved-`O4z` blockers:

- pass overview,
- Binaryen strategy,
- transformed-shape catalog,
- source/test map,
- focused table-info guide,
- Starshine status / code map,
- Starshine port-readiness and validation ladder,
- raw primary-source bridge,
- research archive entry.

## Living pages refreshed

- `docs/wiki/binaryen/passes/directize/index.md`
- `docs/wiki/binaryen/passes/directize/starshine-strategy.md`
- `docs/wiki/binaryen/passes/directize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/directize/wat-shapes.md`
- `docs/wiki/binaryen/passes/directize/starshine-port-readiness-and-validation.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-up rule

Future `directize` implementation work should start with the new Starshine port-readiness page, then read the Binaryen strategy and table-info guide. If a later source check changes table-info gating, target classification, `select` lowering, trap preservation, or type repair, update the port-readiness page and tracker together rather than adding a parallel planning page.
