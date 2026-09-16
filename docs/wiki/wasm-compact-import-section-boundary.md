---
kind: concept
status: supported
last_reviewed: 2026-09-16
sources:
  - https://github.com/WebAssembly/proposals/blob/main/README.md
  - https://github.com/WebAssembly/compact-import-section/blob/main/proposals/compact-import-section/Overview.md
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/basic/compact-imports.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/unit/test_compact_imports.py
  - https://webassembly.github.io/compact-import-section/
  - https://github.com/WebAssembly/proposals
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/wast/parser.mbt
  - ../../src/wast/module_wast.mbt
  - ../../src/validate/validate.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - binary/module-section-map.md
  - binary/function-import-export-and-code-sections.md
  - wast/function-call-and-module-authoring.md
  - wast/resource-declaration-authoring.md
  - validate/import-export-and-external-type-matching.md
---

# WebAssembly Compact Import Section Boundary

## Overview

**Compact Import Section** is an active **Phase-3** WebAssembly proposal that makes repeated imports smaller. It changes how imports are encoded in binary and written in WAT; it does **not** add a new kind of imported object, change index spaces, or change ordinary import validation/execution semantics. The official proposal tracker, proposal overview, and modified specification define this active-proposal boundary.

Starshine now decodes both released compact binary forms into its existing
ordered `ImportSec(Array[Import])`. Ordinary encoding remains the default;
`@binary.encode_module(mod, compact_imports=true)` opts into consecutive-run
compaction. Imports never reorder, so function/table/memory/global/tag indices
keep their logical meaning. The group count counts declarations, while the
expanded list counts imports.

For the Binaryen 132 shape inventory, the two forms are the per-item group and
the shared-description group. Both are expanded to ordinary logical imports
before later validation or optimization; they are serialization forms rather
than new import kinds. The release-level summary is in the
[v132 catalog](binaryen/version-132-upgrade.md#compact-imports-grouped-syntax-expands-to-ordinary-imports).

The v132 WAT grammar uses `item` declarations:

```wat
(module
  (import "env"
    (item $log "log" (func (param i32)))
    (item $memory "memory" (memory 1))))

(module
  (import "math"
    (item $sin "sin")
    (item $cos "cos")
    (func (param f64) (result f64))))
```

Both forms parse to ordinary `ImportField` entries in source order. Item IDs are
bound individually after expansion. The printer emits ordinary imports; the AST
does not retain original group style or per-declaration source spans. The older
examples on this page without `item`, or with the shared descriptor before names,
were stale proposal syntax and are superseded by the pinned v132 grammar.

## Codec and writer policy

The wire header is module name, empty field name, and `0x7f` (shared module) or
`0x7e` (shared module and external type). A shared-module group stores a count and
name/type pairs; a shared-type group stores the external type, count and names.
Nested readers are bounded by the import section payload. Truncated groups,
invalid types and nested compact markers reject.

With `compact_imports=true`, the writer first chooses consecutive same-module,
same-type runs, then consecutive same-module runs; singletons use ordinary
encoding. Distinct module names end a run. It never combines separated imports
or changes imported index spaces. The ordinary `Encode for Module` and default
`encode_module` remain suitable for tools without compact-import support.

Source and regression evidence:

- [Binary decoder](../../src/binary/decode.mbt), [writer](../../src/binary/encode.mbt)
  and [public API](../../src/binary/api.mbt).
- [Exact binary groups, writer policy and malformed boundaries](../../src/binary/binaryen132_imports_wbtest.mbt).
- [Text parser](../../src/wast/parser.mbt) and [named/numeric function-index fixtures](../../src/wast/binaryen132_imports_test.mbt).
- [Pinned upstream text cases](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/basic/compact-imports.wast)
  and [binary writer tests](https://github.com/WebAssembly/binaryen/blob/version_132/test/unit/test_compact_imports.py).

## Remaining signoff boundaries

The tests establish represented grouping and logical order, not full proposal
conformance or preservation of source formatting/locations. Exact-function imports, source-span tooling and independent runtime execution
remain separate coverage work. Mixed function/global/table/memory/tag imports
have direct logical-index fixtures; this is not full per-kind proposal signoff. Use ordinary import validation after
expansion, and record external runtime support separately.

## Related Boundaries

- [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md) owns the shared Core/finished/active-proposal vocabulary.
- [`binary/module-section-map.md`](binary/module-section-map.md) owns standard section order and pass-level cross-section repair.
- [`binary/function-import-export-and-code-sections.md`](binary/function-import-export-and-code-sections.md) owns imported-prefix function indexing, import validation order, and rewrite obligations.
- [`wast/function-call-and-module-authoring.md`](wast/function-call-and-module-authoring.md) and [`wast/resource-declaration-authoring.md`](wast/resource-declaration-authoring.md) own today's ordinary import fixture syntax.
- [`validate/import-export-and-external-type-matching.md`](validate/import-export-and-external-type-matching.md) owns current import/export type-validation and host-linking boundaries.

## Sources

- Official proposal sources: [tracker](https://github.com/WebAssembly/proposals/blob/main/README.md), [overview](https://github.com/WebAssembly/compact-import-section/blob/main/proposals/compact-import-section/Overview.md), and [modified specification](https://webassembly.github.io/compact-import-section/)
- Shared Core/proposal status source: [WebAssembly proposals tracker](https://github.com/WebAssembly/proposals)
- Core import model and codec: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt)
- WAT and validation: [`../../src/wast/parser.mbt`](../../src/wast/parser.mbt), [`../../src/wast/module_wast.mbt`](../../src/wast/module_wast.mbt), [`../../src/validate/validate.mbt`](../../src/validate/validate.mbt)

The `binaryen132-compact-imports` GenValid profile emits both compact forms in
actual batch artifacts. It varies compatible runs, interleaved globals/functions,
and a module-name change followed by another run of the original module.
[The bounded artifact test](../../src/fuzz/binaryen132_imports_wbtest.mbt)
checks decoded imports, export indices and call bodies against the original
logical module, and verifies that grouping reduces encoded size. External
campaign results remain in [the upgrade evidence](binaryen/version-132-upgrade.md).
