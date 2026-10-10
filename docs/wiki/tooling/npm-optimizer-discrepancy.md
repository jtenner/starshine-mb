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

## First bounded implementation checkpoint

The preset now runs identity-protecting DFE rather than skipping the complete
module. Protected functions still contribute rewrite/cleanup facts but never
enter normalization or duplicate pair enumeration. The CLI automatic O4z
candidate filter retains DFE and keeps its separate DIE restriction.

Fresh native binary SHA-256:
`ea899c2d07a03af4c634e8634d886dbf0bfe92524be9820b4ac01d7159844a8e`.
The following single serial samples start from the identical original inputs;
wall/RSS exclude independent validation and consumer tests, and are local samples.

| Artifact | Previous O4s bytes | DFE-fixed O4s bytes | Further reduction | Time (s) | Peak RSS (KiB) |
| --- | ---: | ---: | ---: | ---: | ---: |
| WasmGC | 7,287,538 | 7,232,524 | 55,014 | 8.260 | 267,636 |
| WASI | 6,347,850 | 6,240,505 | 107,345 | 9.058 | 278,852 |

Both outputs independently validate under
`wasm2,gc,function-references,tail-call,extended-const`.
GC output SHA-256:
`cda21fda5f83717853d719433996cb215a41aa3529e41515e557d66ab80608cb`.
WASI output SHA-256:
`53987fb549842534484f05fc995d52cd7cc1d9d37ae9b53b6947a3accc484df8`.
The reduced Node fixture preserves results 84, repeated state increments,
state 91 before an unreachable trap, export names, distinct exported/table/global
identities and their callback aliases. These bounded controls do not establish
universal equivalence.

## Pending readiness evidence

- Completed red checkpoint `d041fd822`: public O4s tests failed 2/2 on helper
  counts; protected-candidate test failed on 6 versus 2 normalizations.
- Initial implementation tests passed 2/2 public, 1/1 protected-candidate and
  1/1 numeric CLI; refresh final assertions, Node identity suite and independent review.
- Measure omitted cleanup owners on originals and close further supported causes.
  Direct OptimizeInstructions currently aborts on the original GC input; a
  reduced write-set fact test exposes an absent optional-control child access.
- Repeat exact-input Binaryen samples with compatible features; preserve exact
  tool/input hashes and remaining gap.
- Run focused/full tests and required direct-pass generated comparisons; record
  incomplete broader signoff explicitly.
- Run isolated packed JavaScript/strict TypeScript controls on copies of the
  original package with exact revised artifacts. Coordinate a fresh-source npm
  build/parity gate with the prep owner through parent; that integration remains
  separate from candidate-copy testing.
