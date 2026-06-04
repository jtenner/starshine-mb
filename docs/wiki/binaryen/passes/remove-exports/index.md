---
kind: entity
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md
  - ../../../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/parser.mbt
related:
  - ../remove-unused-module-elements/index.md
  - ../minify-imports-and-exports/index.md
  - ../strip-toolchain-annotations/index.md
  - ../tracker.md
  - ../late-pipeline-dispatch.md
  - ../../release-horizon-and-oracles.md
---

# Binaryen `remove-exports`

## Overview

`remove-exports` is a Binaryen `version_130` upstream pass surface for deleting module exports. The 2026-06-04 source read confirms that `RemoveExports.cpp` plus `test/lit/passes/remove-exports.wast` exist in the `version_130` tag, so this is a real upstream pass name and should no longer live only as a release-note aside.

For a beginner: an export is how a WebAssembly module exposes a function, table, memory, global, or tag to the host. Removing an export can make the binary smaller or more private, but it changes the module's public ABI. That makes this pass more like an ABI-shaping or packaging pass than an ordinary internal optimizer.

For an implementer: do not confuse `remove-exports` with [`remove-unused-module-elements`](../remove-unused-module-elements/index.md). RUME deletes unreachable module definitions and repairs indices; `remove-exports` is about the `ExportSec` public surface. A definition can remain live internally after its export name is removed, and an export can be a host contract even when no in-module instruction refers to it.

## Current Upstream And Starshine Status

| Surface | Status |
| --- | --- |
| Upstream release horizon | Present in Binaryen `version_130`; see the source read in [`../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md`](../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md). |
| Upstream owner/test files | `src/passes/RemoveExports.cpp` and `test/lit/passes/remove-exports.wast` in Binaryen `version_130`. |
| Starshine registry | Not registered on 2026-06-04; focused `src/` searches found no `remove-exports` or `RemoveExports` pass spelling. |
| Starshine prerequisite representation | Present: `Export`, `ExportSec`, and `Module.export_sec` in [`src/lib/types.mbt`](../../../../../src/lib/types.mbt). |
| Starshine codec/text prerequisites | The normal binary encode/decode and WAST parse/lower paths already know exports; a future pass should reuse those surfaces instead of inventing a pass-local export model. |

The correct current wiki status is **upstream-only / local-unknown**. It is not a boundary-only registry entry, and it is not safe to infer preset membership from the v130 changelog alone.

## Invariants And Edge Cases For A Future Port

- **Host ABI is observable.** Removing an export can break callers even if validation still passes. Preset inclusion needs an explicit policy, not just Binaryen parity.
- **Definition liveness is separate.** Deleting an export does not automatically delete the exported function/table/memory/global/tag. If the now-unexported definition should be removed too, that is a later RUME-style liveness pass decision.
- **Name and metadata maps may need repair.** Export-name maps, diagnostics, and any custom/name-section references must remain consistent after `ExportSec` changes.
- **Index spaces are unchanged unless a later pass deletes definitions.** A pure export-removal pass should not remap function/table/memory/global/tag indices by itself.
- **Start functions and active segments are not exports.** Startup behavior, active data/element effects, and internal references remain even after public exports are removed.
- **Import/export name minification is a different family.** [`minify-imports-and-exports`](../minify-imports-and-exports/index.md) rewrites visible names; `remove-exports` removes public entries.

## Practical First Slice

1. Re-read Binaryen `version_130` `RemoveExports.cpp` and `remove-exports.wast` line-by-line.
2. Decide whether Starshine should leave the pass unknown, register a boundary-only spelling for honest rejection, or implement a controlled direct pass.
3. If implementing, start with explicit-pass-only export-section deletion and no definition deletion.
4. Add tests for function/table/memory/global/tag export removal as applicable, duplicate/export-name behavior, preservation of start and active segment effects, name-section cleanup, and validation after roundtrip.
5. Only after explicit-pass parity is understood, decide whether any preset should ever include the pass; default optimization should not silently drop a module's host API without a documented policy.

## Sources

- Focused source manifest: [`../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md`](../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md)
- Tracker-expansion note: [`../../../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md`](../../../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md)
- Local export representation: [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- Local binary codec: [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt), [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- Local WAST path: [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt), [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
