---
kind: entity
status: supported
starshine_status: upstream-only
last_reviewed: 2026-07-18
sources:
  - ../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/parser.mbt
related:
  - ../../../binary/function-import-export-and-code-sections.md
  - ../../../binary/custom-and-name-sections.md
  - ../remove-unused-module-elements/index.md
  - ../minify-imports-and-exports/index.md
  - ../strip-toolchain-annotations/index.md
  - ../tracker.md
  - ../late-pipeline-dispatch.md
  - ../../release-horizon-and-oracles.md
---

# Binaryen `remove-exports`

## Overview

`remove-exports` is Binaryen's parameterized export-section filter. The 2026-07-11 source recheck in [`../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md) confirms that reviewed `version_130` and current `main` retain the same small contract: match export names by user-supplied patterns and remove the matching export entries. The 2026-06-04 read remains historical provenance.

For a beginner: an export is how a WebAssembly module exposes a function, table, memory, global, or tag to the host. Removing an export can make the binary smaller or more private, but it changes the module's public ABI. That makes this pass more like an ABI-shaping or packaging pass than an ordinary internal optimizer.

For an implementer: do not confuse `remove-exports` with [`remove-unused-module-elements`](../remove-unused-module-elements/index.md). RUME deletes unreachable module definitions and repairs indices; `remove-exports` is about the `ExportSec` public surface. A definition can remain live internally after its export name is removed, and an export can be a host contract even when no in-module instruction refers to it.

## Current Upstream And Starshine Status

| Surface | Status |
| --- | --- |
| Upstream release horizon | Present in Binaryen `version_130`; the retained 2026-07-11 owner/fixture recheck preserves the reviewed release and current-main evidence. |
| Upstream owner/test files | `src/passes/RemoveExports.cpp` and `test/lit/passes/remove-exports.wast` in reviewed `version_130`; the 2026-07-11 current-`main` owner/fixture/registration recheck found no behavior-bearing drift. See [`../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md). |
| Starshine registry | Not registered on 2026-06-04; focused `src/` searches found no `remove-exports` or `RemoveExports` pass spelling. |
| Starshine prerequisite representation | Present: `Export`, `ExportSec`, and `Module.export_sec` in [`src/lib/types.mbt`](../../../../../src/lib/types.mbt). |
| Starshine codec/text prerequisites | The normal binary encode/decode and WAST parse/lower paths already know exports; a future pass should reuse those surfaces instead of inventing a pass-local export model. |

The correct current local classification is **upstream-only / local-unknown**. It is not a boundary-only registry entry, and it is not safe to infer preset membership from the v130 changelog alone. The frontmatter separates that implementation fact from evidence health: `status: supported` means this dossier has current primary and repository support, while `starshine_status: upstream-only` means no local pass exists or is reserved.

## Upstream Behavior Shape

Binaryen's pass takes an argument: `wasm-opt --remove-exports=<patterns>`. The source reads the argument string, trims it, expands response-file contents when requested, splits by newline or comma, expands Binaryen's bracketing-operator pattern syntax, then wildcard-matches each module export name. Matching export entries are collected and removed.

A concrete shape:

```wat
(module
  (func $__helper (export "__helper"))
  (func $api (export "api"))
  (memory (export "__memory") 1)
)
```

With `--remove-exports=__*`, the `__helper` function and memory definitions remain in the module, but the `"__helper"` and `"__memory"` export entries are removed. The `"api"` export remains. That distinction is the central contract: the pass filters the public export list; it does not perform liveness deletion or index remapping by itself.

## Invariants And Edge Cases For A Future Port

- **Host ABI is observable.** Removing an export can break callers even if validation still passes. Preset inclusion needs an explicit policy, not just Binaryen parity.
- **The pass is parameterized.** A faithful local spelling must accept and test name patterns; a no-argument unconditional export wipe would not match the upstream command contract.
- **Definition liveness is separate.** Deleting an export does not automatically delete the exported function/table/memory/global/tag. If the now-unexported definition should be removed too, that is a later RUME-style liveness pass decision.
- **Name and metadata maps may need repair.** Export-name maps, diagnostics, and any custom/name-section references must remain consistent after `ExportSec` changes.
- **Index spaces are unchanged unless a later pass deletes definitions.** A pure export-removal pass should not remap function/table/memory/global/tag indices by itself.
- **Start functions and active segments are not exports.** Startup behavior, active data/element effects, and internal references remain even after public exports are removed.
- **Import/export name minification is a different family.** [`minify-imports-and-exports`](../minify-imports-and-exports/index.md) rewrites visible names; `remove-exports` removes public entries.

## Practical First Slice

1. Re-read Binaryen `version_130` and current `main` `RemoveExports.cpp`, `remove-exports.wast`, and the pass-argument registration path line-by-line.
2. Decide whether Starshine should leave the pass unknown, register a boundary-only spelling for honest rejection, or implement a controlled direct pass.
3. If implementing, start with explicit-pass-only export-section filtering by exact and wildcard names. Do not delete definitions.
4. Add tests for function/table/memory/global/tag export removal as applicable, nonmatching exports, comma/newline pattern lists, preservation of start and active segment effects, name-section and command-diagnostic consistency, and validation after roundtrip.
5. Only after explicit-pass parity is understood, decide whether any preset should ever include the pass; default optimization should not silently drop a module's host API without a documented policy.

Current [`fuzzing.md`](fuzzing.md) is deliberately **planned-only**: `remove-exports` is absent from both the current compare-pass admission list and Starshine's active registry, so a rejected command cannot be parity evidence.

## Sources

- Current-main recheck: [`../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md)
- Tracker-expansion note: research note 0706
- Local export representation: [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- Local binary codec: [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt), [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- Local WAST path: [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt), [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
