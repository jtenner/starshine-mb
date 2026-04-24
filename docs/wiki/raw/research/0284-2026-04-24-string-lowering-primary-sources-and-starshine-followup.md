---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-string-lowering-primary-sources.md
  - ../../binaryen/passes/string-lowering/index.md
  - ../../binaryen/passes/string-lowering/binaryen-strategy.md
  - ../../binaryen/passes/string-lowering/implementation-structure-and-tests.md
  - ../../binaryen/passes/string-lowering/json-and-magic-imports.md
  - ../../binaryen/passes/string-lowering/wat-shapes.md
  - ../../binaryen/passes/string-lowering/starshine-strategy.md
  - ../../binaryen/passes/string-gathering/index.md
  - ../../strings/string-const-surface.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/tests.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
  - ../../../../agent-todo.md
---

# `string-lowering` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `string-lowering` dossier already had a living overview, Binaryen strategy page, transformed-shape catalog, implementation/test map, and focused JSON/magic-import page.
It still had two durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine status / strategy page that maps the upstream contract to the exact current local code surfaces

This follow-up closes those gaps without pretending Starshine already implements the pass.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-24-string-lowering-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- `StringLowering.cpp` on `version_129` and `main`
- `pass.cpp`
- `passes.h`
- `string-utils.h`
- `string-gathering.wast`
- `string-lowering.wast`
- `string-lowering.js`

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `src/binary/tests.mbt`
- `src/wast/keywords.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/validate/typecheck.mbt`
- `src/ir/hot_lift.mbt`
- `src/ir/hot_lower.mbt`
- `docs/wiki/strings/string-const-surface.md`
- `agent-todo.md`
- neighboring living dossiers for `string-gathering` and `reorder-globals`

## Durable findings

### 1. The Binaryen side needed provenance, not a new algorithm story

The existing upstream pages were still broadly correct after the 2026-04-21 research wave.
The new manifest adds the missing provenance anchor:

- on 2026-04-24 the official Binaryen `version_129` release page showed publish date **2026-04-01 14:31**
- the tagged source still shows `StringLowering::run(...)` as gather, type update, import lowering, instruction replacement, refinalize, feature-disable
- a narrow current-`main` spot check on `StringLowering.cpp` did not expose teaching-relevant drift from the tagged contract

### 2. The key local correction is stronger than “unimplemented”: Starshine does not track the pass name today

Re-reading `src/passes/optimize.mbt` found no `string-lowering`, `string-lowering-magic-imports`, or `string-lowering-magic-imports-assert` entry in either `pass_registry_boundary_only_names()` or `pass_registry_removed_names()`.

So the current local status is:

- no owner file
- no registry spelling
- no removed-pass request guard for this exact pass name
- no dedicated active backlog slice
- no scheduler role in the default optimize or shrink presets

That is different from many other unimplemented pass folders where the registry already preserves an unavailable upstream spelling.

### 3. Starshine already has useful string plumbing, but it is not a lowering pass

The strongest current local implementation bridge is ordinary wasm-string and `string.const` infrastructure:

- `src/wast/keywords.mbt:101` recognizes the textual `string.const` keyword.
- `src/wast/parser.mbt:2181` parses `string.const` literals.
- `src/wast/lower_to_lib.mbt:2389` lowers parsed `StringConst` to `@lib.Instruction::string_const(...)`.
- `src/wast/lower_to_lib.mbt:7238` tests WAST-to-binary-module lowering for global and function `string.const` sites.
- `src/binary/encode.mbt:72` binds a module stringref pool while encoding.
- `src/binary/encode.mbt:87` maps `string.const` payloads to active `stringrefs` indices.
- `src/binary/encode.mbt:1580` collects unique `string.const` payloads across module globals and code.
- `src/binary/decode.mbt:148` binds a decode-time `stringrefs` context.
- `src/binary/decode.mbt:160` maps binary string literal indices back to bytes.
- `src/binary/tests.mbt:1817` roundtrips a module with `string.const` literals and a `stringrefs` section.
- `src/validate/typecheck.mbt:3063` owns `string.const` typechecking.
- `src/ir/hot_lift.mbt:1292` lifts `StringConst` into HOT constant payloads.
- `src/ir/hot_lower.mbt:197` lowers HOT string constants back to library IR instructions.

Those locations prove Starshine can parse, encode, decode, validate, lift, and lower string constants.
They do **not** prove that Starshine can perform Binaryen-style `string-lowering` yet.

### 4. A faithful future port is module/boundary work, not a HOT peephole

Binaryen `string-lowering` changes ABI-visible types, imports, globals, custom sections, helper imports, feature flags, and module-level code.
That makes the future Starshine landing zone much closer to a boundary/module pass than a local HOT expression rewrite.

A faithful local port would need at least:

1. registry spelling decisions for the three public Binaryen lowering modes
2. a module pass owner that can change type, import, global, custom-section, and feature metadata
3. a literal/import metadata model for `string.consts` JSON and magic imports
4. a supported-op lowering table matching the reviewed helper surface
5. explicit unsupported-op behavior for the still-TODO upstream families
6. validation and roundtrip tests covering ABI rewrites, helper imports, and JSON custom-section output

### 5. The local relation to `string-gathering` should stay explicit

Current `agent-todo.md` has `SG` slices for `string-gathering`, not for `string-lowering`.
That matters because `string-lowering` inherits gathering upstream but is larger and ABI-changing.

The safest future sequence is:

1. keep `string-gathering` as the local late-tail literal-canonicalization workstream
2. treat `string-lowering` as a separate upstream-only dossier until Starshine intentionally takes on boundary string ABI lowering
3. avoid filing `string-lowering` regressions as failures of the current `SG` backlog unless the failure is specifically about the inherited gathering prefix

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-24-string-lowering-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0284-2026-04-24-string-lowering-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/string-lowering/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/string-lowering/index.md`
- `docs/wiki/binaryen/passes/string-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/string-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/string-lowering/json-and-magic-imports.md`
- `docs/wiki/binaryen/passes/string-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `string-lowering` work needs a clean provenance-plus-local-status path, start with:

1. `docs/wiki/raw/binaryen/2026-04-24-string-lowering-primary-sources.md`
2. `docs/wiki/binaryen/passes/string-lowering/index.md`
3. `docs/wiki/binaryen/passes/string-lowering/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/string-lowering/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/string-lowering/json-and-magic-imports.md`
6. `docs/wiki/binaryen/passes/string-lowering/wat-shapes.md`
7. `docs/wiki/binaryen/passes/string-lowering/starshine-strategy.md`
8. `docs/wiki/binaryen/passes/string-gathering/index.md`
9. `docs/wiki/strings/string-const-surface.md`
10. `src/passes/optimize.mbt`
11. `src/binary/encode.mbt`
12. `src/binary/decode.mbt`
13. `src/wast/lower_to_lib.mbt`
14. `src/validate/typecheck.mbt`
15. `agent-todo.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status: no transform, no registry entry, no active backlog slice, but real string-literal infrastructure that future boundary/module work would reuse.
