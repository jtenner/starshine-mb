---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` unsupported-family policy refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Full source matrix

The v130 owner tests `curr->is<BrOn>() || curr->is<TryTable>()` and reports `Unsupported instruction for Flatten`. The `BrOn` class covers the four local HOT families:

- `br_on_null`
- `br_on_non_null`
- `br_on_cast`
- `br_on_cast_fail`

`try_table` is the fifth hard-unsupported family.

## Direct v130 probes

- `.tmp/flatten-probes/unsupported-br-on-null.wat` exits `1` with `Fatal: Unsupported instruction for Flatten: BrOn` under `wasm-opt version 130 --all-features --flatten -S`.
- `.tmp/flatten-probes/unsupported-try-table.wat` reaches the control-structure dispatch first and aborts with `unexpected expr type` / `UNREACHABLE` at `Flatten.cpp`; it is still a hard unsupported pass boundary, not a successful no-op.

The distinction matters: the source's final explicit `TryTable` fatal check is not reached for this direct shape because the earlier control-structure switch has no `TryTable` arm.

## Local policy

Starshine keeps public `flatten` removed. Internally, `FlattenRunAdmission` classifies these five families as `UpstreamHardUnsupported` before any mutation and `flatten_run(...)` returns unchanged. This preserves input semantics and prevents partial flattening while the pass has no public execution contract, but it does **not** yet match Binaryen's observable hard failure. Public registry/CLI/harness admission therefore remains blocked until Starshine chooses and tests a user-visible rejection path that is compatible with the Binaryen v130 contract.

The same admission boundary separately records representable-but-deferred inputful-loop, legacy-try, and branch-payload families so hard upstream unsupported instructions cannot be conflated with ordinary implementation gaps.
