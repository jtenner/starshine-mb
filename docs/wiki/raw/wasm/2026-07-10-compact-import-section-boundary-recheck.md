# Compact Import Section Proposal Boundary Recheck

- Capture date: 2026-07-10
- Source family: official WebAssembly proposal tracker and the Compact Import Section proposal repository
- Reason for capture: route an active proposal that changes the import-section binary/text encoding without changing module import semantics, validation, or execution.
- Status: immutable primary-source bridge. It complements the general 2026-07-10 Core/proposal/dashboard status bridge; it is the focused source for Compact Import Section mechanics and current Starshine boundary claims.

## Primary sources checked

1. WebAssembly proposals tracker README, checked 2026-07-10: <https://github.com/WebAssembly/proposals/blob/main/README.md>
   - Lists **Compact Import Section** in **Phase 3 — Implementation Phase (CG + WG)**.
2. WebAssembly Compact Import Section proposal overview, checked 2026-07-10: <https://github.com/WebAssembly/compact-import-section/blob/main/proposals/compact-import-section/Overview.md>
3. Proposal modified specification entry point, checked 2026-07-10: <https://webassembly.github.io/compact-import-section/>

## Durable takeaways

- The proposal targets repeated **module names** and, in one form, repeated **external types** in the import section. It does not introduce a new import semantic or a new section id.
- Existing import entries remain valid and represent one flat `(module name, item name, externtype)` triple.
- The proposal adds two import-section encodings:
  1. one module name followed by a list of `(item name, externtype)` pairs;
  2. one module name and one `externtype` followed by a list of item names.
- The compact forms use an empty second name plus `0x7F` or `0x7E` where an ordinary import currently carries its external-type tag. The proposal deliberately makes old decoders fail at that unknown import-type position rather than silently misdecode the input.
- The proposed WAT surface adds grouped `(import "mod" (item ... ) ...)` forms alongside the existing single-item `(import "mod" "item" ...)` form.
- The proposal explicitly says syntax, validation, and execution semantics do not otherwise change. A conforming implementation can therefore lower/decode compact groups into the existing ordered flat import representation, provided it preserves every individual import and its order.

## Starshine source reconciliation

- Current Starshine stores a flat `ImportSec(Array[Import])`, and each `Import` is exactly `(Name, Name, ExternType)` in [`src/lib/types.mbt`](../../../../src/lib/types.mbt). This matches the proposal's semantic fallback representation but preserves neither the original grouping nor which compact encoding was used.
- [`Decode for Import`](../../../../src/binary/decode.mbt) reads exactly two names and then one `ExternType`; [`Decode for ExternType`](../../../../src/binary/decode.mbt) accepts current tags `0x00` through `0x04` only. The proposed `0x7F` / `0x7E` sentinels therefore remain unsupported and reject at decode time today.
- [`Encode for Import`](../../../../src/binary/encode.mbt) and [`Encode for ImportSec`](../../../../src/binary/encode.mbt) emit only the existing flat encoding. The current core representation cannot round-trip compact grouping byte-for-byte.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) requires the existing module-name, item-name, descriptor form; [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prints the same flat form. There is no compact-group AST or printer policy.
- [`validate_importsec(...)`](../../../../src/validate/validate.mbt) already validates an ordered flat list, so this proposal is primarily a binary/text front-end and emission-policy task—not a new index-space or execution-model task.

## Uncertainty and implementation boundary

- The tracker phase is a standards-process claim, not a promise that a particular engine, external validator, Binaryen build, or Starshine command accepts the proposal.
- This capture does not assert a preferred Starshine encoder policy. A future implementation must decide whether to always emit flat imports, opportunistically compact compatible runs, or preserve an explicit source-emission choice in a new representation. The current flat `ImportSec` cannot preserve the input's grouping by itself.
- Before implementation, recheck the proposal repository's modified specification and tests. This note records the 2026-07-10 upstream shape and the current local boundary; it is not a replacement for byte-level conformance fixtures.
