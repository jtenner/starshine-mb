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

RUME is **closed again after correctness repair and renewed verification on 2026-07-27**. Review found two source-confirmed Binaryen-v131 gaps in the prior closeout:

- `return_call` bypassed the direct-call special-import rules used by ordinary `call`.
- `configureAll` used an expression-wide `array.new_elem` accumulator instead of resolving and validating exact call operand one.

The implementation now routes ordinary and tail direct calls through one helper, validates the exact `configureAll` producer contract, treats closed-world `array.new_elem` / `array.init_elem` payload functions as references until a real callable use upgrades them, and removes the per-expression temporary accumulator. A detached pre-fix worktree running the new focused file produced the intended red state (`44/52` passing, eight failures across the tail/special-import/configureAll families); the repaired tree passes `52/52`.

The renewed explicit-v131 matrix is green for all RUME-owned behavior. The same historical random-all local-run family and wasm-smith memory64 case remain classified outside parity failure: the former is a one-byte decoder/encoder size gap with no RUME mutation, and the latter is the existing full-u64 Starshine correctness/size win. The sibling `remove-unused-nonfunction-module-elements` still shares the graph engine while preserving function declarations, and the optimize/shrink rosters still contain all three intended RUME positions.

## Transform-family audit

| Family | Starshine v131 behavior | Evidence |
| --- | --- | --- |
| Startup roots | exports, start, module code, globals, elem/data offsets, and reachable function bodies seed the graph | focused fixtures plus regular/dedicated GenValid |
| Strong versus reference-only functions | direct calls are strong; `ref.func` can remain declaration-only; closed-world mode can nullify an uncalled referenced body | `closed world empties uncalled ref.func targets` |
| `call_ref` | compatible referenced function types become callable in closed-world mode | `closed world call_ref keeps compatible targets callable` |
| Imported call conventions | ordinary and tail direct calls share `binaryen.js.called`, `binaryen-intrinsics/call.without.effects`, and stack-exact `wasm:js-prototypes/configureAll` handling | red-first focused regressions plus exact singleton/dedicated GenValid lanes |
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

The focused file retains the earlier 43 tests and adds nine strict regressions for:

- exact-ref, typed-local, and typed-global tail `call.without.effects`
- tail-called `configureAll`
- unrelated earlier `array.new_elem`
- a later nested call after operand one
- multiple array operands
- incorrect offsets and sizes
- an underspecified intrinsic shape that Binaryen rejects
- generated high-risk families whose callable bodies must not become `unreachable`

Focused verification passes `52/52`. The dedicated generator file passes `3/3`; its special-import test directly validates ordinary and tail forms of both `call.without.effects` and `configureAll`.

## Renewed explicit-v131 evidence

Oracle: `.tmp/binaryen-version-131-bin/bin/wasm-opt`, verified as `wasm-opt version 131 (version_131)`.

Current-master native Starshine SHA-256: `f4ea93419d8bb8c98d3e09c28a823b30a119ee436ee775c65d95b0386018545b` at `_build/native/release/build/cmd/cmd.exe`.

| Lane | Result |
| --- | --- |
| Dedicated `rume-all`, 10,000 | `10000/10000` normalized; zero validation, generator, property, mismatch, or command failures |
| Regular GenValid, 100,000 | `100000/100000` normalized; zero failures |
| Random all-profiles, 10,000 | `9375` normalized plus `625` classified one-byte local-run representation gaps; zero validation/property/command failures |
| wasm-smith, 10,000 | `9956` comparable; `9955` normalized; one known memory64 Starshine win; `44` Binaryen/tool failures; zero Starshine failures |
| Four new singleton profiles, 10,000 each | all four `10000/10000` normalized with zero failures |
| Focused RUME tests | `52/52` |
| Dedicated profile tests | `3/3` |
| Current-master native full `moon test` | `10012/10012` |
| Retained-versus-fresh DAE checks | focused `3/3`, topology `1/1`, bounded differential `10000/10000` normalized |
| Release artifact checks | native/wasm-gc builds, external validation, stable two-step roundtrip, and `2944`-attempt wasm-gc roundtrip smoke green |

The expanded aggregate selected every leaf: special imports `1784`, index-remap stress `1744`, dead graph `1764`, legacy EH `1203`, table traps `1190`, callable references `1183`, and continuations/descriptors `1132`. See [`./fuzzing.md`](./fuzzing.md) for commands, out dirs, cache counts, CI-stage evidence, and residual classifications.

## Residual classifications

### Random-all local-run encoding family

All `625` differences select `remove-unused-brs-control`, and every canonical Starshine output is one byte larger. Inspection shows RUME's internal module state unchanged; the byte comes from Starshine's multi-value decode/re-encode path leaving a synthetic same-typed scalar scratch local in a separate local declaration run. This is a real size gap, but it is not a RUME liveness/nullification/remap gap. The owner is decoder/encoder local-run canonicalization.

### wasm-smith `case-004700`

Starshine emits an empty module while Binaryen retains a huge unused memory64 and two active data segments. Starshine's full-u64 bounds prove the startup writes in range; Binaryen v131's `Index` truncation false-positives a trap. The Starshine result is both correct and 41 canonical bytes smaller (`8` versus `49`).

## Performance

Seven current-master direct debug-WASI runs after the repair report:

- Starshine pass-local samples: `101.973`, `103.502`, `100.742`, `101.240`, `101.387`, `102.603`, `100.126 ms`
- Starshine median: `101.387 ms`
- Binaryen v131 pass-local samples: `67.5935`, `66.8218`, `67.3755`, `66.7585`, `69.6762`, `68.5737`, `69.1596 ms`
- Binaryen v131 median: `67.5935 ms`
- median ratio: `1.500x`

This improves the historical Starshine result from `113.379 ms` by about `10.6%` and remains comfortably inside the `2x` pass-local acceptance bound. After applying Binaryen-v131 strip-debug to Starshine's raw output, Starshine and Binaryen's direct output are byte-identical at `5,286,137` bytes with SHA-256 `267d26b0d4f499d4695f3ea4306bb9cc902e1b19e2257e532a34ee9d106a9d58`. Name-map sorting remains a secondary unmeasured target.

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
