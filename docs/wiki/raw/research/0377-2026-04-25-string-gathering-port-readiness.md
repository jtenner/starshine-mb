---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md
  - ../binaryen/2026-04-23-string-gathering-primary-sources.md
  - ../../binaryen/passes/string-gathering/index.md
  - ../../binaryen/passes/string-gathering/binaryen-strategy.md
  - ../../binaryen/passes/string-gathering/implementation-structure-and-tests.md
  - ../../binaryen/passes/string-gathering/reuse-naming-and-ordering.md
  - ../../binaryen/passes/string-gathering/wat-shapes.md
  - ../../binaryen/passes/string-gathering/starshine-strategy.md
  - ../../binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/ir/hot_builders.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `string-gathering` port-readiness follow-up

## Why this follow-up exists

The `string-gathering` dossier already had the required overview, Binaryen strategy, implementation/test map, reuse/order guide, WAT-shape catalog, and Starshine status page. It still had three practical gaps:

- most pages still had 2026-04-23 freshness wording even though this is a canonical no-DWARF late-tail gap;
- the Starshine page mapped the current status but did not give future implementers one first-slice / validation ladder page;
- several local line anchors were stale or too coarse for the current registry, string literal, HOT, and backlog surfaces.

This follow-up keeps the existing folder, adds a current-main source bridge, and adds a dedicated port-readiness page instead of creating a near-duplicate dossier.

## Primary source added

New raw source bridge:

- `docs/wiki/raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md`

It records official Binaryen current-`main` URLs checked for:

- `src/passes/StringLowering.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/string-utils.h`
- `src/passes/string-utils.cpp`
- `src/ir/module-utils.h`
- `src/wasm-traversal.h`
- `test/lit/passes/string-gathering.wast`
- neighboring `test/lit/passes/propagate-globals-globally.wast`

## Durable findings

### 1. No teaching-relevant drift from the tagged `version_129` contract

The focused current-main recheck did not find evidence that the existing living contract needs an algorithm rewrite. `string-gathering` remains:

- a standalone pass implemented inside `StringLowering.cpp`;
- the first phase reused by full `string-lowering`;
- an exact-`StringConst` slot scanner;
- a canonical immutable string-global chooser/creator;
- a direct slot rewrite from `StringConst` to `global.get`;
- a minimal validity-first global reorder before the later `reorder-globals` pass.

The recheck also preserves the main non-goals: no full lowering, no arbitrary `global.get` cleanup, no mutable/imported/nullable/nested-initializer reuse as defining globals, no final cost ordering, and no nested cleanup rerun owned by the pass.

### 2. The local registry gap is still the sharpest Starshine status issue

The current local status remains unimplemented, but the exact bookkeeping issue is clearer now:

- `src/passes/optimize.mbt:127-140` lists boundary-only names and omits `string-gathering`;
- `src/passes/optimize.mbt:144-151` lists removed names and also omits `string-gathering`.

That means explicit `--pass string-gathering` behavior is currently an unknown-pass gap, not the more honest boundary-only rejection used by many other late-tail ports. The new port-readiness page records that as the first safe implementation slice.

### 3. Starshine already has enough string literal substrate for a real first slice

The local source review confirmed exact prerequisite anchors:

- binary encode context and literal-index lookup: `src/binary/encode.mbt:72-103`;
- deterministic stringrefs collection: `src/binary/encode.mbt:1578-1645`;
- decode context and literal lookup: `src/binary/decode.mbt:148-171`;
- binary opcode decode to `Instruction::string_const`: `src/binary/decode.mbt:3078-3082`;
- WAT lowering of `string.const`: `src/wast/lower_to_lib.mbt:2389` and validation test at `:7238-7262`;
- HOT builder/lift/lower preservation: `src/ir/hot_builders.mbt:285-293`, `src/ir/hot_lift.mbt:1291-1294`, and `src/ir/hot_lower.mbt:196-197`.

Those are prerequisites, not the pass implementation itself. They are still valuable because Binaryen groups by literal payload, so Starshine must preserve literal identity before it can canonicalize repeated uses.

### 4. The recommended first implementation slice should be registry honesty before rewriting

The future port should not start by silently changing module bodies. The safe first slice is:

1. add the public spelling to the registry as boundary-only;
2. add a reduced request-guard test proving explicit requests fail honestly while the pass is still unimplemented;
3. only then add a module-pass owner and direct `StringConst` scan/rewrite tests.

This keeps the pass discoverable and makes the current unknown-pass status visible as technical debt rather than a hidden implementation surprise.

### 5. Validation should mirror Binaryen's proof split

The new port-readiness page keeps the validation ladder tied to the upstream file/test split:

- `string-gathering.wast` families first: repeated literals, reusable immutable globals, nullable/mutable non-reuse, first reusable global, nested global initializer rewrite, and validity-first reorder;
- source-derived module-code coverage second: any non-global module expression surfaces Starshine chooses to support;
- scheduler parity third: `string-gathering -> reorder-globals` ordering plus strings feature gating;
- artifact comparison fourth: the `[SG]002` backlog item and the saved no-DWARF late-tail replay.

## Living pages refreshed

- `docs/wiki/binaryen/passes/string-gathering/index.md`
- `docs/wiki/binaryen/passes/string-gathering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/string-gathering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/string-gathering/reuse-naming-and-ordering.md`
- `docs/wiki/binaryen/passes/string-gathering/wat-shapes.md`
- `docs/wiki/binaryen/passes/string-gathering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-up rule

Future `string-gathering` work should start from the existing dossier plus the 2026-04-25 current-main/port-readiness bridge. Do not create a second string-gathering folder. Only rewrite the strategy if a later primary-source check changes exact-slot scanning, reusable-global eligibility, fresh-name construction, validity-first reorder, feature gating, or the shared `StringLowering.cpp` ownership model.
