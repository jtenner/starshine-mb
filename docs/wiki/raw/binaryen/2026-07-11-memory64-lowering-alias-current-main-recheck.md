---
kind: raw-source
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/Memory64Lowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/Memory64Lowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/memory64-lowering.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory64-lowering.wast
related:
  - ../../binaryen/passes/memory64-lowering/index.md
  - ../../binaryen/passes/memory64-lowering/binaryen-strategy.md
  - ../../binaryen/passes/memory64-lowering/implementation-structure-and-tests.md
  - ../../binaryen/passes/memory64-lowering/wat-shapes.md
  - ../../binaryen/passes/memory64-lowering/starshine-strategy.md
  - ../../binaryen/passes/memory64-lowering/starshine-port-readiness-and-validation.md
supersedes:
  - 2026-04-24-memory64-lowering-primary-sources.md
  - 2026-04-25-memory64-lowering-current-main-recheck.md
  - 2026-04-26-memory64-lowering-port-readiness-primary-sources.md
---

# Binaryen `memory64-lowering` / `table64-lowering` alias and current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable focused primary-source correction for the living `memory64-lowering` dossier

## Scope

This recheck resolves a source-topology error preserved in older captures: Binaryen publishes two CLI spellings, `memory64-lowering` and `table64-lowering`, but they are **aliases for the same `Memory64Lowering` pass constructor**, not independently selectable memory-only and table-only transforms.

Use the living pages for explanation and future Starshine planning. This capture records source evidence only.

## Primary sources rechecked

- Binaryen `version_130` and current `main` [`src/passes/Memory64Lowering.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/Memory64Lowering.cpp)
  - The one visitor owns memory and table declaration lowering, active data and element offsets, scalar/SIMD/atomic memory operations, bulk memory/table operations, and table operations.
  - It has no public mode parameter that selects memory-only versus table-only behavior.
- Binaryen `version_130` and current `main` [`src/passes/pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp)
  - The two public registrations describe memory and table 64-bit-index lowering separately for CLI discoverability.
  - Both registrations construct the same `Memory64Lowering` pass with the same no-option constructor.
- Binaryen `version_130` and current `main` [`test/lit/passes/memory64-lowering.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory64-lowering.wast)
  - The one fixture contains two RUN lines, one invoking `--memory64-lowering` and one invoking `--table64-lowering`.
  - Both commands normalize to the same expected output, which includes both memory and table lowering shapes.

## Durable observations

- **Public-name distinction, not transform distinction:** `memory64-lowering` and `table64-lowering` are two public names for one combined module transform. Invoking either name does not select only one resource family.
- **One test file proves both names:** the canonical fixture is `test/lit/passes/memory64-lowering.wast`; it exercises both command spellings and contains both memory and table examples. Older wiki references to a separate `table64-lowering.wast` fixture are stale and should not be copied into future validation commands.
- **The rewrite contract remains current:** the combined visitor lowers all applicable memory64 and table64 declarations and typed use sites, while preserving the previously documented dynamic-wrap, static-high-`MemArg.offset` trap, unsigned-size, grow-failure-sentinel, active-segment, and positional bulk-operation rules.
- **No behavior-bearing drift found:** comparing the reviewed `version_130` and current-main owner, registration, and fixture surfaces found no change to this combined-transform contract.

## Documentation consequences

- Say “two public aliases” or “two public spellings,” not “separate siblings,” when describing upstream behavior.
- A future Starshine implementation may expose both spellings for compatibility, but both must dispatch to the same combined module rewrite unless later upstream evidence proves a mode split.
- Separate memory-first and table-later *implementation slices* remain sensible because Starshine table typing is incomplete; that local sequencing is not evidence that Binaryen has two independently scoped passes.

## Historical caveat

The older raw captures are retained as immutable provenance. Their owner-level observations remain useful, but their separate-fixture / independently scoped-sibling wording is superseded by this recheck.
