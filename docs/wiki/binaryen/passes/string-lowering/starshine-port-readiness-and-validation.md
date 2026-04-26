---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-string-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0415-2026-04-26-string-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-string-lowering-primary-sources.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./json-and-magic-imports.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./json-and-magic-imports.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../string-gathering/index.md
  - ../string-lifting/index.md
---

# Starshine port readiness and validation for `string-lowering`

## Scope

This page is the implementation-readiness bridge for a future Starshine port of Binaryen's `string-lowering` family.
It does not claim the pass is implemented today.
It turns the existing dossier into a step-by-step validation map that connects:

- Binaryen's source-backed phase order,
- the transformed module / instruction shapes in [`./wat-shapes.md`](./wat-shapes.md),
- the JSON and magic-import ABI details in [`./json-and-magic-imports.md`](./json-and-magic-imports.md), and
- the exact Starshine code surfaces a future port would have to reuse or extend.

## Current local status

Starshine currently treats all public `string-lowering` names as **unknown pass names**.
They are not boundary-only names and not removed names.

Exact registry anchors:

- [`src/passes/optimize.mbt#L118-L130`](../../../../../src/passes/optimize.mbt#L118-L130)
  - boundary-only names omit `string-lowering`, `string-lowering-magic-imports`, and `string-lowering-magic-imports-assert`
- [`src/passes/optimize.mbt#L133-L139`](../../../../../src/passes/optimize.mbt#L133-L139)
  - removed names also omit the three public Binaryen names

That makes registry honesty the first decision point. A future slice should not silently implement one spelling while leaving the siblings undocumented.

## Binaryen contract to preserve

A faithful port must preserve the source-backed order described in [`./binaryen-strategy.md`](./binaryen-strategy.md):

1. run the `string-gathering` prefix,
2. rewrite string heap types to extern heap types while preserving nullability,
3. convert gathered defining string globals into imports,
4. choose default JSON metadata, magic imports, or assert-mode fatal behavior,
5. create `wasm:js-string` helper imports,
6. lower the supported string instruction subset into helper calls,
7. refinalize,
8. remove the Strings feature only after all lowered surfaces are repaired.

Skipping or reordering those phases can change validation behavior.
For example, removing the Strings feature before proving all string-typed code is gone would create a malformed module rather than a completed lowering.

## Local substrate already present

Starshine already has usable string literal plumbing:

- WAT keyword and parser support
  - [`src/wast/keywords.mbt#L101-L109`](../../../../../src/wast/keywords.mbt#L101-L109)
  - [`src/wast/parser.mbt#L2180-L2191`](../../../../../src/wast/parser.mbt#L2180-L2191)
- WAT-to-lib lowering
  - [`src/wast/lower_to_lib.mbt#L2389-L2399`](../../../../../src/wast/lower_to_lib.mbt#L2389-L2399)
- binary encoding
  - [`src/binary/encode.mbt#L2818-L2879`](../../../../../src/binary/encode.mbt#L2818-L2879)
- validation
  - [`src/validate/typecheck.mbt#L3230-L3259`](../../../../../src/validate/typecheck.mbt#L3230-L3259)
- HOT roundtrip for string constants
  - [`src/ir/hot_lift.mbt#L1292-L1295`](../../../../../src/ir/hot_lift.mbt#L1292-L1295)
  - [`src/ir/hot_lower.mbt#L196-L198`](../../../../../src/ir/hot_lower.mbt#L196-L198)

This is enough to build tests around literal gathering and `string.const` roundtrips.
It is not enough to claim pass readiness for the whole Binaryen instruction surface.

## Missing local substrate

A future port still needs explicit support or explicit rejection for these surfaces:

- the three public pass names:
  - `string-lowering`
  - `string-lowering-magic-imports`
  - `string-lowering-magic-imports-assert`
- `string.consts` JSON custom-section emission and roundtrip expectations,
- module import synthesis for `string.const` and `wasm:js-string`,
- ABI-visible function/global/type rewriting from string refs to extern refs,
- helper-call rewrites for Binaryen's supported operation families:
  - `fromCharCodeArray`
  - `fromCodePoint`
  - `concat`
  - `intoCharCodeArray`
  - `equals`
  - `test`
  - `compare`
  - `length`
  - `charCodeAt`
  - `substring`
- validation repair / refinalization after module-wide type and call changes,
- feature-section cleanup after successful lowering.

The local string opcode vocabulary also does not line up perfectly with Binaryen's pass surface today: Starshine already parses some `string.new*` / `string.encode*` array forms that Binaryen's lowering pass treats as unsupported TODO families, while Starshine lacks some source instructions Binaryen lowers through helpers.
Treat that as a test-design warning, not as a contradiction.

## First safe implementation slices

### Slice 0: registry honesty

Add tests that prove the current behavior for the three public names, then decide the intended local category.
Options:

- keep them unknown until implementation starts,
- add them as boundary-only names with clear request rejection,
- or add an implemented module pass only when mutation is real.

Do not register only `string-lowering` while ignoring the magic-import siblings unless the docs say that is intentional.

### Slice 1: no-mutation analyzer

Before changing output, build a module analyzer that reports:

- string literal globals that the gathering prefix would define or reuse,
- string-typed function/global/type surfaces that would need externref repair,
- unsupported string opcodes that would make Binaryen fatal or unreachable,
- whether default JSON, magic-import, or assert-mode behavior was requested.

This slice should validate against local fixtures without comparing output to Binaryen yet.

### Slice 2: default JSON literal lowering

Implement the smallest mutating default-mode subset:

Before:

```wat
(global $s (ref string) (string.const "hello"))
```

After:

```wat
(import "string.const" "0" (global $s (ref extern)))
;; plus Binaryen-style `string.consts` metadata for "hello"
```

This slice must also update any `global.get $s` users to the externref-shaped type and validate the output module.

### Slice 3: helper imports and supported op rewrites

Only after type/import repair exists, add helper-call rewrites for the source-backed Binaryen subset.

Example shape:

```wat
(string.concat (local.get $a) (local.get $b))
```

becomes a call to the imported helper:

```wat
(call $wasm:js-string.concat (local.get $a) (local.get $b))
```

The exact local WAT spelling for imported helper function names may differ, but the module/base ABI and signature behavior should be oracle-checked against Binaryen.

### Slice 4: magic imports and assert mode

Split these tests deliberately:

- valid UTF-16 literals become magic imports under the selected constants module,
- invalid / non-UTF-8-convertible literals fall back to JSON in normal magic mode,
- the same invalid literals fail in assert mode.

Do not collapse those into one "magic imports work" fixture.

### Slice 5: feature cleanup and wider parity

Only after validation repair is reliable should the pass disable the Strings feature.
Then compare focused Binaryen fixtures before broader fuzzing.

## Validation ladder

Use this order:

1. `moon test` fixtures for registry categorization and unknown/boundary behavior.
2. Parser/lower/typecheck fixtures for each supported source shape.
3. Binary encode/decode roundtrip fixtures for string literal and custom-section behavior.
4. Focused pass fixtures matching Binaryen `test/lit/passes/string-lowering.wast` and `string-lowering.js`.
5. Separate oracle runs for:
   - `--string-lowering`,
   - `--string-lowering-magic-imports`,
   - `--string-lowering-magic-imports-assert`.
6. Negative fixtures for unsupported string op families, preserving Binaryen's explicit TODO/fatal boundary instead of silently no-oping.
7. Feature cleanup checks proving no string feature remains after successful lowering.

## Main caveats

- The JS string builtins proposal is the ABI context for `wasm:js-string` helper imports. Recheck it before freezing helper ABI tests.
- Public-type handling is intentionally narrow in Binaryen `version_129`: singleton-rec-group function types get special treatment, but broader public-type cases are not solved.
- If local `string-gathering` lands first, reroute the first mutating slice through that owner instead of duplicating the Binaryen inherited-prefix behavior.
- This pass should be module/boundary-owned, not HOT-owned: it rewrites imports, globals, custom sections, types, helper functions, and feature metadata.
