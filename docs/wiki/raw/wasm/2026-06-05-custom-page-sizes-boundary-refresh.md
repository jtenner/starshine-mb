---
kind: raw-source
status: current
last_reviewed: 2026-06-05
sources:
  - https://github.com/WebAssembly/proposals
  - https://github.com/WebAssembly/custom-page-sizes
  - https://github.com/WebAssembly/custom-page-sizes/blob/main/proposals/custom-page-sizes/Overview.md
  - https://webassembly.github.io/spec/core/syntax/types.html#memory-types
  - https://webassembly.github.io/spec/core/valid/types.html#memory-types
  - https://webassembly.github.io/spec/core/binary/types.html#memory-types
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/validate.mbt
  - ../../../../src/validate/match.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
related:
  - ../../wasm-feature-status-and-proposal-boundaries.md
  - ../../wasm-custom-page-sizes-boundary.md
  - ../../binary/type-table-memory-global-tag-sections.md
  - ../../validate/resource-sections-and-limits.md
  - ../../wast/resource-declaration-authoring.md
  - ../../binaryen/passes/multi-memory-lowering/index.md
---

# Custom Page Sizes Boundary Refresh (2026-06-05)

## Why this note exists

Custom Page Sizes is easy to overroute in Starshine because several Binaryen pass dossiers mention a memory `pageSize`, while Starshine's current core memory representation stores only address-width limits plus a shared-memory flag. This note records the current primary-source and local-code split so living pages can distinguish the active proposal from current Starshine support.

## Primary sources checked

- The official WebAssembly proposals repository currently lists **Custom Page Sizes** under Phase 3 active proposals, not under finished proposals.
- The proposal repository and overview describe a custom-page-size extension for linear memories. The overview's motivation is to allow a memory page size other than the default 64 KiB page size for use cases such as embedded systems and short-lived memories.
- The proposal overview adds a memory-type `pagesize` field and a binary memory-type flag extension with an additional page-size exponent immediate.
- The proposal overview records an intentionally narrow validity shape at the checked revision: the page size must be either `1` byte or `65536` bytes.
- Current Core WebAssembly memory-type pages remain the stable-Core source for ordinary memory32/memory64 limits, but they are not enough evidence for custom page-size support in Starshine.

## Starshine evidence checked

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `Limits::{I32Limits,I64Limits}` and `MemType(Limits, Bool)`. There is no page-size field in `Limits`, `MemType`, `TableType`, or `ExternType`.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) accepts `Limits` tags `0x00`, `0x01`, `0x04`, and `0x05`; `MemType` additionally accepts shared-memory tags `0x02`, `0x03`, `0x06`, and `0x07`. It rejects any other limit or memory-type tag as `InvalidLimits`. There is no branch that reads a custom page-size immediate.
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) emits only the same ordinary/memory64/shared-memory flag matrix and cannot emit a custom page-size memory type.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) validates memory limits with `ValidateMax` and the local/proposal shared-memory maximum rule, but it has no page-size validation dimension.
- [`src/validate/match.mbt`](../../../../src/validate/match.mbt) matches `MemType` by limit compatibility and shared-flag equality only. It cannot model the proposal rule that page size participates in external-memory compatibility because no local field exists.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses memory limits as naturals only, and [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) lowers WAST resource limits through `@lib.Limits::i32(...)`; there is no WAST spelling for custom page sizes.

## Durable conclusions

1. Custom Page Sizes is active-proposal evidence, not stable Core 3.0 and not current Starshine support.
2. Starshine should not claim binary, WAST, validator, generator, external-type matching, pass, or Node/package support for custom page sizes until the core `MemType` shape grows a page-size field and each layer is tested.
3. Binaryen pass pages that say memories must have the same page size describe Binaryen's source-level legality condition. In current Starshine docs that condition should be routed as a future-port caveat because local memories have no page-size representation to compare or rewrite.
4. Existing Starshine memory page arithmetic, such as `min << 16` in memory-related pass helpers, assumes the ordinary 64 KiB page scale. Do not reuse those helpers for custom page sizes without a design and tests.

## Caveats and supersession

- This note narrows earlier generic active-proposal routing that only listed Custom Page Sizes in the broad active-proposal bucket. It does not supersede the memory64 or threads/shared-memory bridges; address width, sharedness, and page size are separate memory-type dimensions.
- No local code change is implied. This is documentation/source routing only.
