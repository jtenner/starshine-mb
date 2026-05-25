---
kind: concept
status: supported
last_reviewed: 2026-05-19
sources:
  - ../raw/wasm/2026-05-19-wast-variable-instruction-sources.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - identifier-name-and-annotation-authoring.md
  - control-flow-authoring.md
  - memory-argument-authoring.md
  - resource-declaration-authoring.md
  - ../binary/instruction-and-expression-encoding.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../validate/module-validation-phases.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../fuzzing/generator-coverage-ledger.md
---

# WAST Variable Instruction Authoring

## Overview

Use this page when writing, reducing, or widening WAST fixtures that read or write locals and globals:

- local instructions: `local.get`, `local.set`, and `local.tee`;
- global instructions: `global.get` and `global.set`;
- nearby constant-expression use of immutable `global.get` in Starshine.

These instructions look simple, but they connect several layers: WAST `$` identifiers, core numeric index spaces, binary opcode immediates, validator stack effects, name-section metadata, and mutating-pass repair. The primary-source and local-code manifest is [`../raw/wasm/2026-05-19-wast-variable-instruction-sources.md`](../raw/wasm/2026-05-19-wast-variable-instruction-sources.md).

## Beginner Mental Model

WebAssembly functions use a typed value stack plus typed local slots. Parameters are the first locals; explicit `(local ...)` declarations come after them.

```wat
(module
  (global $counter (mut i32) (i32.const 0))
  (func (param $x i32) (result i32)
    (local $tmp i32)
    (local.set $tmp (i32.add (local.get $x) (i32.const 1)))
    (global.set $counter (local.get $tmp))
    (local.get $tmp)))
```

In that function:

- `$x` lowers to `LocalIdx(0)` because params lead the local index space;
- `$tmp` lowers to `LocalIdx(1)` because it is the first body local;
- `$counter` lowers to the global's absolute `GlobalIdx` in the module global index space;
- the printer may round-trip these as numeric `local.get 0`, `local.set 1`, and `global.set 0` rather than preserving the original `$` spellings.

Identifier metadata is separate from variable instruction semantics. For the source-id versus name-section distinction, see [`identifier-name-and-annotation-authoring.md`](identifier-name-and-annotation-authoring.md).

## Layer Model

| Layer | Owner | Variable-instruction facts to remember |
| --- | --- | --- |
| WAST keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Recognizes `local.get`, `local.set`, `local.tee`, `global.get`, and `global.set`; accepts numeric or `$` identifiers. |
| WAST lowerer/printer | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Resolves local ids through the function-local map and globals through the module map; prints numeric indices. |
| Core instruction model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Keeps `LocalGet`, `LocalSet`, `LocalTee`, `GlobalGet`, and `GlobalSet` as explicit `Instruction` variants. |
| Binary bytes | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Uses opcodes `0x20`..`0x24`, each followed by the relevant local/global index immediate; byte well-formedness is not enough to prove semantic validity. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) | Checks index existence, value types, global mutability, and constant-expression eligibility. |
| Fuzz / generator evidence | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt) | `[FZG]003` covers `local.tee`; `[FZG]008` covers immutable `global.get` const-expression variants; `[FUZ]1039B` forces imported immutable `i32` globals into coverage-forced active element/data offsets; invalid strategies keep mutable-global const-expression failures live. |

## Text Shapes And Stack Rules

| WAST shape | Stack before | Stack after | Main validation rule |
| --- | --- | --- | --- |
| `local.get x` | unchanged | pushes local `x`'s type | `x` must be in the current function's local index space. |
| `local.set x` | `... value` | consumes value | value must match local `x`'s type. |
| `local.tee x` | `... value` | stores value, then leaves value on stack | equivalent stack effect to `local.set x` followed by `local.get x`, but the operand is evaluated once. |
| `global.get g` | unchanged | pushes global `g`'s type | `g` must exist in the module global index space. |
| `global.set g` | `... value` | consumes value | `g` must exist, be mutable, and receive its declared type. |

The tee rule is the common fixture trap. This is valid because `local.tee` leaves the `i32` for the function result:

```wat
(func (param i32) (local i32) (result i32)
  (local.tee 1 (i32.add (local.get 0) (i32.const 1))))
```

Replacing that with only `local.set 1` would leave no result value. Replacing it with `local.set 1; local.get 1` is semantically fine only if the pass preserves the original operand evaluation order and cannot duplicate trapping or effectful operand work.

## Identifier And Index Resolution

Starshine lowers local identifiers per defined function:

1. type-use parameter ids are inserted first, starting at index `0`;
2. if the function uses a type index, the lowerer asks that function type for the parameter count before numbering body locals;
3. explicit local ids are inserted after the parameter range;
4. every `local.*` instruction resolves either a numeric index directly or a `$` id through that map.

Global identifiers are module scoped. Imports and definitions share one global index space; imported globals occupy the prefix before locally-defined globals. WAST fixture-facing global declarations, explicit imports, inline exports, mutability syntax, and initializer-order rules live in [`resource-declaration-authoring.md`](resource-declaration-authoring.md). A mutating pass that reorders or deletes globals must update every `GlobalIdx` carrier, including `global.get`, `global.set`, exports/imports, name metadata, initializers, and any cached global summaries. The broader core/binary resource-section rewrite checklist lives in [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md).

## Binary And Validation Contract

The official variable-instruction binary family is intentionally compact:

| Instruction | Opcode | Immediate |
| --- | ---: | --- |
| `local.get` | `0x20` | `localidx` |
| `local.set` | `0x21` | `localidx` |
| `local.tee` | `0x22` | `localidx` |
| `global.get` | `0x23` | `globalidx` |
| `global.set` | `0x24` | `globalidx` |

Starshine's codec maps these directly in [`src/binary/decode.mbt`](../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../src/binary/encode.mbt). The typechecker then supplies the missing semantic facts:

- unknown local or global indices are invalid;
- `local.set` and `local.tee` pop the local's declared type;
- `global.set` rejects immutable globals before checking the operand type;
- `global.get` is allowed in ordinary function bodies regardless of mutability, but constant-expression contexts are narrower.

## Constant-Expression `global.get`

Starshine allows an extended immutable-`global.get` constant-expression subset in selected initializer/offset positions. The key local rules are:

- immutable imported globals may be read in constant expressions;
- coverage-forced GenValid modules deliberately use imported immutable `i32` globals in active element and data offsets so that the imported-global offset profile stays exercised;
- immutable earlier defined globals may be read by later globals or segment/table initializers;
- mutable `global.get` is rejected in constant expressions;
- ordinary function-body `global.get` remains just a normal instruction.

```wat
(module
  (global $base i32 (i32.const 8))
  (global $copy i32 (global.get $base)) ;; allowed by Starshine's immutable-global const-expr policy
  (global $mut (mut i32) (i32.const 0))
  ;; (global $bad i32 (global.get $mut)) ;; invalid: mutable global in const expression
)
```

The focused validator-side allow-list, ordering, and portability caveats live in [`../validate/constant-expressions.md`](../validate/constant-expressions.md); the broader phase map remains in [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md). The invalid-repro and strategy names for mutable-global constant-expression failures are covered by [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md) and [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md).

## Rewrite And Signoff Guidance

When a pass changes locals or globals, check these invariants before accepting output:

1. **Local index map:** parameters still precede body locals; any deleted or inserted body local updates all `LocalIdx` uses and local-name metadata if preserved.
2. **Tee semantics:** replacing `local.tee` must preserve single evaluation, stored local value, and the remaining stack value.
3. **Global index map:** global reorder/delete/insert rewrites all `GlobalIdx` carriers, not just function-body instructions.
4. **Mutability:** never introduce `global.set` to an immutable global; do not turn a mutable-global const-expression failure into an apparently valid initializer.
5. **Type refinement:** if a pass tightens a local/global reference type, retag gets/tees/sets consistently and run validation.
6. **Roundtrip expectations:** WAST source `$` ids may be lost during print; compare semantic indices and name-section metadata separately.

Useful validation lanes are ordinary `moon test` for local parser/lowerer/typechecker coverage, focused package tests such as `moon test src/wast`, `moon test src/binary`, and `moon test src/validate`, and pass-specific `bun fuzz compare-pass --pass <name>` when a transform mutates variable instructions.

## Common Mistakes

- Treating `$` names as stable runtime identities. They are source-level identifiers unless separately preserved in the binary `name` section.
- Forgetting that params are locals too. `local.get 0` usually means the first parameter, not the first `(local ...)` declaration.
- Rewriting `local.tee` as a bare `local.set` and accidentally dropping a result value.
- Moving `global.get` across a `global.set` to the same mutable global without proving the read value is unchanged.
- Assuming byte opcode validity proves semantic validity. The byte codec can decode `global.set 0`, but validation still rejects it if global `0` is immutable or missing.
- Reusing constant-expression `global.get` examples in ordinary WAST without keeping the immutable/prior-global ordering rule visible.

## Sources

- Source manifest: [`../raw/wasm/2026-05-19-wast-variable-instruction-sources.md`](../raw/wasm/2026-05-19-wast-variable-instruction-sources.md)
- Official WebAssembly text instructions: <https://webassembly.github.io/spec/core/text/instructions.html>
- Official WebAssembly syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- Official WebAssembly binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html>
- Official WebAssembly validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html>
- Local parser/lowerer/typechecker sources listed in the frontmatter above.
