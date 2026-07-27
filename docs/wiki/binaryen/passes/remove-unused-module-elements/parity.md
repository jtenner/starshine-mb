---
kind: comparison
status: supported
last_reviewed: 2026-07-27
sources:
  - ../../release-horizon-and-oracles.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/passes/optimize.mbt
  - ./fuzzing.md
related:
  - ./index.md
  - ./roots-reference-only-and-nullification.md
  - ./indirect-call-trap-preservation.md
  - ./retention-and-index-rewrites.md
---

# `remove-unused-module-elements` Binaryen v131 Parity

## Current status

The 2026-07-27 source-to-test audit closes RUME's released Binaryen v131 behavior surface and the missing second early preset slot.

- Direct RUME behavior has no known semantic, validation, or index-rewrite failure in the renewed matrix.
- The sibling `remove-unused-nonfunction-module-elements` continues to share the graph engine while preserving function declarations.
- The optimize and shrink rosters now contain all three Binaryen RUME positions: initial prepass, GC/global-type cleanup follow-up, and late postpass.
- Broad random-all still exposes one pass-independent, size-losing local-run encoding family; it is recorded explicitly rather than mislabeled as semantic parity.

## Transform-family audit

| Family | Starshine v131 behavior | Evidence |
| --- | --- | --- |
| Startup roots | exports, start, module code, globals, elem/data offsets, and reachable function bodies seed the graph | focused fixtures plus regular/dedicated GenValid |
| Strong versus reference-only functions | direct calls are strong; `ref.func` can remain declaration-only; closed-world mode can nullify an uncalled referenced body | `closed world empties uncalled ref.func targets` |
| `call_ref` | compatible referenced function types become callable in closed-world mode | `closed world call_ref keeps compatible targets callable` |
| Imported call conventions | `binaryen.js.called`, `binaryen-intrinsics/call.without.effects`, and `wasm:js-prototypes/configureAll` receive Binaryen-compatible treatment | focused source-mapped tests and implementation audit |
| Functions | unused imports/definitions are removed, reference-only bodies can become `unreachable`, and surviving indices/types are repaired | focused function/import/remap tests |
| Globals | strong instruction/export/init uses retain globals; dead globals are removed; potentially descriptor-trapping initializers are retained unless TNH | descriptor initializer fixture |
| Tables | imports/definitions, defaults, active parents, indirect calls, mutation, growth, and table index rewrites are tracked | table-default/overlap suite |
| Memories | loads/stores/atomics/SIMD/memory ops and active data startup traps retain memories; full-u64 memory64 bounds avoid Binaryen's truncation bug | focused data tests and wasm-smith `004700` |
| Tags and EH | legacy `try` body/catches/catch tags, typed EH, throws, and exports participate in reachability and remapping | legacy-EH focused and dedicated profile |
| Continuations | `cont.new`, `cont.bind`, `suspend`, `resume`, `resume_throw`, `resume_throw_ref`, `stack.switch`, and resume-handler tags carry type/tag liveness and remaps | synthetic continuation binary fixture |
| Elem segments | active/passive/declarative modes, parent retention, declaration-only `ref.func`, overlap/null/wrong-type writes, and active-to-declarative weakening are covered | v131 table fixtures and focused suite |
| Data segments | active/passive users, trap-sensitive startup writes, data-count rebuild, and data-index rewrites are covered | focused data/remap tests |
| GC/type carriers | struct/array/ref casts, descriptor casts, atomic GC operations, array data/elem operations, recursive groups, and subtype-compatible call types are marked | recursive-type and all-features audit |
| Type cleanup | dead types are compacted only when the local safety checks can preserve recursive-group validity; surviving type-index carriers are rewritten through the shared DFE traversal | recursive-group validity tests |
| Non-function sibling | functions are preserved while non-function roots, retention, nullification, and remaps reuse the same engine | existing sibling-mode focused tests |

## Focused coverage

`src/passes/remove_unused_module_elements_test.mbt` now has `43/43` passing tests. The new audit cases lock in:

- closed-world reference-only body nullification
- closed-world `call_ref` compatible target retention
- `binaryen.js.called` reference strength
- exact and type-only `binaryen-intrinsics/call.without.effects` target selection
- `wasm:js-prototypes/configureAll` function selection from its element operand
- continuation handler-tag retention and remapping
- descriptor-trapping initializer retention and `traps_never_happen` relaxation

These augment the existing import/drop/remap, segment-parent, table-default, overlap, trap, recursive-group, and decoded legacy-EH coverage.

## Renewed explicit-v131 evidence

Oracle: `.tmp/binaryen-version-131-bin/bin/wasm-opt`, verified as `wasm-opt version 131 (version_131)`.

Native Starshine: `_build/native/release/build/cmd/cmd.exe`.

| Lane | Result |
| --- | --- |
| Dedicated `rume-all`, 10,000 | `10000/10000` normalized; zero failures |
| Regular GenValid, 100,000 | `100000/100000` normalized; zero failures |
| Random all-profiles, 10,000 | `9375` normalized plus `625` classified one-byte local-run representation gaps; zero validation/property/command failures |
| wasm-smith, 10,000 | `9956` comparable; `9955` normalized; one known memory64 Starshine win; `44` Binaryen/tool failures |
| Focused RUME tests | `43/43` |
| Dedicated profile tests | `2/2` |
| Full repository after merging remote master | `10002/10002` |

See [`./fuzzing.md`](./fuzzing.md) for commands, artifact paths, and residual classifications.

## Residual classifications

### Random-all local-run encoding family

All `625` differences select `remove-unused-brs-control`, and every canonical Starshine output is one byte larger. Inspection shows RUME's internal module state unchanged; the byte comes from Starshine's multi-value decode/re-encode path leaving a synthetic same-typed scalar scratch local in a separate local declaration run. This is a real size gap, but it is not a RUME liveness/nullification/remap gap. The owner is decoder/encoder local-run canonicalization.

### wasm-smith `case-004700`

Starshine emits an empty module while Binaryen retains a huge unused memory64 and two active data segments. Starshine's full-u64 bounds prove the startup writes in range; Binaryen v131's `Index` truncation false-positives a trap. The Starshine result is both correct and 41 canonical bytes smaller (`8` versus `49`).

## Performance

On `tests/node/dist/starshine-debug-wasi.wasm`, direct RUME produced canonical wasm equality at `5,286,137` bytes.

- Starshine pass-local: `113.379 ms`
- Binaryen v131 pass-local: `66.655 ms`
- ratio: about `1.70x`
- whole command: Starshine `747.526 ms`, Binaryen `802.785 ms`

The pass-local target is not met on this artifact, so performance remains a documented optimization opportunity rather than a correctness blocker.

## Scheduler reconciliation

Binaryen v131 schedules the second early RUME after GC/global type optimization because those passes can make `ref.func`-reachable code dead. Starshine's corresponding public order is now:

`global-refining -> global-struct-inference -> remove-unused-module-elements -> ssa-nomerge`

Registry tests assert:

- three RUME occurrences in both optimize and shrink presets
- exact second-slot position
- the downstream DAEO index shift caused by inserting the slot

Historical first- and second-neighborhood artifacts remain exact for the earlier tree. Renewed broad self-hosted neighborhood probes on the current tree are not canonical-equal because neighboring DFE/memory-packing/global/GSI/SSA implementations have independent output-shape differences; direct RUME on the same self-hosted artifact is canonical-equal. Do not attribute those whole-neighborhood differences to RUME without a pass-local replay.

## Reopening criteria

Reopen RUME if any of the following appears:

- a module element is kept, removed, or nullified differently without a proven Starshine semantic/size/performance win
- a surviving module or type index is stale or invalid
- a legacy/typed EH, continuation, GC, descriptor, segment, or table-default carrier is missed
- closed-world callable/reference-only behavior disagrees with Binaryen v131
- the non-function sibling removes or rewrites a function unexpectedly
- a residual currently classified outside RUME is reduced to a pass-local RUME mutation
