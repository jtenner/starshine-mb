---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md
  - ../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_side_tables.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./import-and-call-shapes.md
  - ./starshine-strategy.md
  - ../string-lowering/index.md
  - ../string-gathering/index.md
---

# Starshine `string-lifting` port readiness and validation

## Purpose

This page turns the source-backed `string-lifting` dossier into an implementation-readiness checklist for future Starshine work.
It does **not** claim the pass exists locally today.

Shortest current truth:

- Binaryen has a public `string-lifting` module pass.
- Starshine currently treats `string-lifting` as an unknown pass name.
- Starshine has some string instruction plumbing, but not enough to emit every Binaryen lifted output shape.
- A faithful port should start with registry honesty and a tiny magic-import constant slice, not helper-call rewriting.

## Current upstream contract to match

Use [`./binaryen-strategy.md`](./binaryen-strategy.md) for the complete strategy.
The port-relevant contract is:

1. collect imported string globals from the configured magic constants module;
2. collect imported numbered `string.const` globals paired with the `string.consts` JSON custom section;
3. collect exact `wasm:js-string` helper imports;
4. reject recognized helper names with wrong expected signatures as fatal pass errors;
5. rewrite recognized `global.get` and helper `call` expressions;
6. refinalize changed functions;
7. run the same applier over module-code expressions;
8. remove the consumed `string.consts` custom section;
9. enable the Strings feature.

The 2026-04-26 current-main recheck in [`../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md) found no teaching-relevant drift from the `version_129` contract.

## Exact Starshine status today

`string-lifting` is absent from all pass-status buckets in `src/passes/optimize.mbt`:

- `src/passes/optimize.mbt:127-142` lists boundary-only names and omits `string-lifting`.
- `src/passes/optimize.mbt:144-153` lists removed names and omits `string-lifting`.
- `src/passes/optimize.mbt:156-278` builds active module/HOT/preset entries and has no `string-lifting` entry.
- `src/passes/optimize.mbt:463-476` therefore reports an unknown pass before it could report boundary-only or removed status.

There is also no `src/passes/string_lifting.mbt` owner file and no module-dispatcher case.

## Local prerequisites that already exist

These surfaces are useful prerequisites, not a pass implementation.

| Surface | Exact location | What it gives a future port |
| --- | --- | --- |
| pass registry / request errors | `src/passes/optimize.mbt:127-278`, `src/passes/optimize.mbt:463-476` | place to add honest boundary-only/removed/active status before implementation |
| core instruction enum | `src/lib/types.mbt:725-735` | `StringConst` plus currently modeled string new/encode array opcodes |
| `stringref` type helper | `src/lib/types.mbt:1240-1242` | value-type spelling for current string validation surfaces |
| WAT opcode enum | `src/wast/types.mbt:234-242` | parser-level string opcode vocabulary for the current subset |
| WAT keyword table | `src/wast/keywords.mbt:101-109` | text-token mapping for the current subset |
| WAT parser | `src/wast/parser.mbt:2180-2191` | `string.const` literal parsing plus new/encode string opcode parsing |
| WAT-to-lib lowering | `src/wast/lower_to_lib.mbt:1299-1309`, `src/wast/lower_to_lib.mbt:2389-2399` | conversion from parsed string opcodes to lib instructions |
| WAT printer | `src/wast/module_wast.mbt:417-425` | rendering of current string constants and new/encode opcodes |
| validation surface facts | `src/validate/validate.mbt:4090-4440` | feature/fact tracking for current string operations |
| binary string pool | `src/binary/encode.mbt`, `src/binary/decode.mbt` | `string.const` index/payload handling |
| HOT string constants | `src/ir/hot_lift.mbt:768-775`, `src/ir/hot_lift.mbt:1291-1293`, `src/ir/hot_lower.mbt:185-197`, `src/ir/hot_side_tables.mbt:37-39` | HOT roundtrip for currently modeled string constants |

## Missing local output surface

Do not start with helper rewrites until these Binaryen output families have local representation and validation coverage:

- `string.from_code_point`
- `string.concat`
- `string.eq`
- `string.compare`
- `string.test`
- `string.measure_wtf16`
- `stringview_wtf16.get_codeunit`
- `stringview_wtf16.slice`

The existing new/encode array support only covers part of the helper roster in [`./import-and-call-shapes.md`](./import-and-call-shapes.md).

## First safe implementation slice

A minimal honest sequence is:

1. Add a registry-status test proving `string-lifting` is deliberately boundary-only or removed, rather than unknown.
2. Add or confirm WAT/lib/validator/binary support for the exact output opcode to be emitted.
3. Implement only configurable magic-import global discovery.
4. Rewrite only `global.get` of a recognized imported string global to `string.const`.
5. Refinalize or otherwise prove type repair for the rewritten expression.
6. Add a Binaryen-oracle comparison fixture for the magic-import case.

This slice avoids JSON custom-section parsing, helper-call signatures, missing lifted opcodes, and the open cast-repair TODO.

## Second slice: JSON `string.consts`

The JSON path should be separate because it requires pass-facing custom-section behavior:

- recognize imported globals from module `string.const`;
- parse import bases as indices;
- parse the `string.consts` custom section as JSON payload data;
- remove the consumed custom section;
- preserve malformed/missing-section behavior with explicit tests.

Starshine currently has binary custom-section support, but this dossier did not find a ready-made `string.consts` parser/remover utility.

## Third slice: helper calls

Only after output opcodes and signature checking exist, implement helpers one family at a time:

| Helper | First required local output support |
| --- | --- |
| `fromCharCodeArray` | `string.new_wtf16_array` |
| `fromCodePoint` | `string.from_code_point` |
| `concat` | `string.concat` |
| `intoCharCodeArray` | `string.encode_wtf16_array` |
| `equals` | `string.eq` |
| `test` | `string.test` |
| `compare` | `string.compare` |
| `length` | `string.measure_wtf16` |
| `charCodeAt` | `stringview_wtf16.get_codeunit` |
| `substring` | `stringview_wtf16.slice` |

Validation must distinguish three cases:

- wrong module: unchanged;
- unknown helper base under `wasm:js-string`: warning or explicit local policy plus unchanged;
- recognized helper base with wrong signature: Binaryen-compatible fatal error unless Starshine intentionally documents a divergence.

## Cast TODO decision

Binaryen's source still carries an explicit cast-repair TODO for generated string inputs.
A Starshine port must choose and document one of two policies:

- parity-first: preserve Binaryen's limitation and test only shapes that Binaryen accepts cleanly;
- repair-first: add explicit casts locally, mark the behavior as a deliberate divergence, and compare carefully against Binaryen after a later `string-lowering` pipeline if needed.

Do not silently claim full type repair without tests.

## Validation ladder

Use this order for future signoff:

1. registry/status tests;
2. WAT parser/printer/typecheck tests for every emitted opcode;
3. reduced magic-import fixture;
4. reduced JSON `string.consts` fixture;
5. one reduced helper fixture per helper family;
6. wrong-module, unknown-helper, and wrong-signature fixtures;
7. module-code expression fixture;
8. feature-enable assertion;
9. Binaryen normalized WAT comparison for representative fixtures;
10. broad pass-fuzz comparison only after the full helper roster and cast policy are implemented.

## Health-check note

This page intentionally keeps `string-lifting` as upstream-only and unknown locally. The wiki improvement is a clearer implementation bridge, not a claim that the code status changed.
