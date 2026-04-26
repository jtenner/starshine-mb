---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md
  - ../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md
  - ../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./import-and-call-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../string-lowering/starshine-strategy.md
  - ../string-gathering/starshine-strategy.md
---

# Starshine `string-lifting` status and strategy

## Current status

Starshine currently has **no `string-lifting` pass**.

More specifically:

- `src/passes/optimize.mbt` does not list `string-lifting` as an active pass.
- It is not listed in `pass_registry_boundary_only_names()`.
- It is not listed in `pass_registry_removed_names()`.
- There is no `src/passes/string_lifting.mbt` owner file.
- There is no active `agent-todo.md` backlog slice for `string-lifting`.

So an explicit local request for `--string-lifting` is currently an unknown-pass situation, not an honest boundary-only rejection.

## Why this is not just `string-lowering`

Binaryen uses two separate files and directions:

- `StringLifting.cpp` lifts imports and helper calls into wasm strings.
- `StringLowering.cpp` lowers wasm strings back to imports and `externref`-shaped operations.

A faithful Starshine port should preserve that directionality even if both passes eventually share helper-import and string-constant utilities.

## Exact local code surfaces that exist today

These are prerequisites, not a pass implementation.

| Local file | Current relevance |
| --- | --- |
| `src/passes/optimize.mbt:127-154` | Registry source of truth; the boundary-only and removed name arrays currently omit `string-lifting` |
| `src/passes/optimize.mbt:156-278` | Active pass and preset registration; no active/module/preset `string-lifting` entry exists |
| `src/lib/types.mbt:725-735` | Defines `Instruction::StringConst` and the currently modeled string new/encode instruction constructors |
| `src/lib/types.mbt:1240-1242` | Defines the local `stringref` value type helper used by validation/type surfaces |
| `src/wast/types.mbt:234-242` | Textual opcode enum includes current string-constant and string new/encode names |
| `src/wast/keywords.mbt:101-109` | Maps WAT tokens such as `string.const`, `string.new_wtf16_array`, and `string.encode_wtf16_array` |
| `src/wast/parser.mbt:2180-2191` | Parses `string.const` literals plus the current string new/encode opcode family |
| `src/wast/lower_to_lib.mbt:1299-1309` and `src/wast/lower_to_lib.mbt:2389-2399` | Lowers parsed WAT string opcodes into `@lib.Instruction` values |
| `src/validate/typecheck.mbt` | Typechecks current local string operations |
| `src/validate/validate.mbt` | Tracks string surfaces in validation feature facts |
| `src/binary/encode.mbt` | Encodes `string.const` through the module stringrefs pool |
| `src/binary/decode.mbt` | Decodes `string.const` indices back to literal payloads |
| `src/ir/hot_lift.mbt:768-775` and `src/ir/hot_lift.mbt:1291-1293` | Lifts current local string ops and `StringConst` payloads into HOT form |
| `src/ir/hot_lower.mbt:185-197` | Lowers HOT string constants back to `@lib.Instruction::string_const(...)` |
| `src/ir/hot_side_tables.mbt:37-39` | Stores `StringConst` payloads for HOT constants |

## Major missing local pieces

A real Starshine `string-lifting` port would need new module-pass infrastructure for:

- imported global discovery by module/base;
- `string.consts` custom-section parsing and removal;
- `wasm:js-string` helper import discovery with exact signature checks;
- rewriting function bodies and module-code expressions;
- adding or preserving feature flags for the Strings feature;
- refinalizing changed functions or otherwise repairing expression types;
- modeling the full Binaryen lifted instruction surface, not only the string ops Starshine already parses;
- deciding whether to replicate Binaryen's current open cast TODO or fix it locally with explicit tests.

## Important local instruction gap

The current local string surface is useful but narrower than Binaryen `string-lifting` output.
The grep-backed local scan found direct support for `StringConst`, `StringNewUtf8Array`, `StringNewWtf16Array`, and encode variants, but the Binaryen lifting output also includes families such as:

- `string.from_code_point`
- `string.concat`
- `string.eq`
- `string.compare`
- `string.test`
- `string.measure_wtf16`
- string-view get/slice operations

A pass port must not assume those are already complete just because `string.const` roundtrips today. It also must not silently preserve a recognized `wasm:js-string` helper with the wrong signature unless Starshine intentionally diverges from Binaryen: the 2026-04-25 source correction confirms that Binaryen treats that case as fatal.

## Suggested future implementation order

If Starshine ever tracks this pass, use the more detailed ladder in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). The short version is:

1. Add the pass name as boundary-only or removed, with tests proving explicit requests fail honestly.
2. Add missing WAT/lib/validator/binary support for every lifted output opcode the pass will emit.
3. Implement magic-import `global.get -> string.const` first.
4. Add JSON `string.consts` custom-section decode/remove support only after a focused fixture proves roundtrip behavior.
5. Build exact `wasm:js-string` helper signature checking before helper-call rewrites.
6. Add helper-call rewrites one family at a time.
7. Decide and document the cast-repair boundary before turning on broader call rewrites.
8. Keep the pass out of presets unless a larger string-lifting/lowering pipeline exists and validates against Binaryen.

## Validation plan for a future port

Minimum local tests should cover:

- unknown-pass or boundary-only behavior before implementation;
- magic string constant lifting;
- JSON `string.consts` lifting;
- every supported helper-call family;
- wrong-module and unknown-helper bailouts plus a recognized-helper wrong-signature error/fatal fixture;
- module-code expression rewriting;
- Strings feature enablement;
- type repair / cast behavior;
- normalized Binaryen compare for representative fixtures.

## Current conclusion

The best current Starshine strategy is documentation and explicit tracking, not implementation.
`string-lifting` is source-confirmed upstream, but local prerequisites are incomplete enough that treating the pass as implemented or immediately portable would mislead future work.

## Sources

- [`../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md)
- [`../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md`](../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md`](../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md)
- [`../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md`](../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/wast/types.mbt`](../../../../../src/wast/types.mbt)
- [`../../../../../src/wast/keywords.mbt`](../../../../../src/wast/keywords.mbt)
- [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- [`../../../../../src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt)
- [`../../../../../src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt)
