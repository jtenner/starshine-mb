---
kind: investigation
status: working
last_reviewed: 2026-10-10
sources:
  - ../../npm-beta-handoff.md
  - ./node-package-surface.md
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/duplicate_function_elimination.mbt
  - ../../../src/passes/o4s_private_duplicates_test.mbt
related:
  - ../binaryen/passes/duplicate-function-elimination/starshine-strategy.md
  - ../ir2/registry-map.md
---

# npm O4s optimizer discrepancy

## Inputs and scope

Fresh fetch verified `origin/master` at
`9057a5d8a5a5b85859c702c76d0cbe3e9f18ab55`. Optimizer work is isolated on
`codex/optimizer-disparity`; packaging/CI/release workflow retains its existing
owner. No npm publication, tag, release or master push belongs to this task.
Licensing remains undecided.

Both optimizers must read the same original name-stripped artifact, never the
other optimizer's output. Original WasmGC: 7,452,107 bytes,
`059555428f569dcd57275757be8453a4f4881eb80592f9f80e402b4987072de3`.
Original WASI: 6,748,730 bytes,
`b7dd0896d7b41989e1aa29bd297d3fd63097b7e3b7f76883e9897f25010add52`.
The source report, comparison, handoff and both originals are immutable;
local evidence copies have a SHA-256 manifest outside the worktree.

A fresh native release build of the verified baseline reproduces the selected
WasmGC O4s output, 7,287,538 bytes,
`6ace60a63b33dda84c15067ca2ab60b702a6e74e3edb7bfca7d158761984bbea`.
Its pass trace confirms preset DFE is skipped for host-visible identity.
O4s numeric levels 4/1 select only DFE, constraint analysis, vacuum, reorder
locals and strip debug. These are different queues from Binaryen's O4/s1.

## Private duplicate admission regression

The broad preset DFE guard suppresses all duplicate merging on modules with
imports/exports. The actual pass already marks each exported and runtime
address-materialized function and refuses to merge either protected endpoint.
This includes active/passive elements, globals/tables and `ref.func` through
structured/EH bodies. Direct calls and start invoke functions without exposing
an address; declarative element payloads only satisfy validation declarations.

Focused regressions require O4s to merge private duplicate helpers while
preserving import slots, exported and table/global function identities, direct
call remapping, validation and input ownership. Candidate admission must also
exclude protected functions before duplicate normalization/pair enumeration,
so broad preset admission does not expose quadratic protected-only buckets.

Independent read-only source review supports the narrower admission and
identified that bucket-cost issue plus the separate CLI O4z portfolio filter.
This is preliminary review, not runtime or final release signoff.

## Pending readiness evidence

- Confirm red regressions and commit them before the implementation.
- Implement bounded private admission; validate runtime results, traps, state,
  host identities and remapping independently.
- Measure omitted cleanup owners on originals and close further supported causes.
- Repeat exact-input Starshine/Binaryen samples with compatible features and
  independent validation; record byte reductions, tool/input hashes, wall/RSS.
- Run focused/full tests and required direct-pass generated comparisons; record
  incomplete broader signoff explicitly.
- Obtain independent final patch review and coordinate npm rebuild/parity/packed
  JavaScript and strict TypeScript checks with the prep owner through parent.
