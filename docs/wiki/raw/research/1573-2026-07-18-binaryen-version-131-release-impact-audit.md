---
kind: research
status: current
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_131
  - https://github.com/WebAssembly/binaryen/compare/version_130...version_131
  - https://github.com/WebAssembly/binaryen/blob/version_131/CHANGELOG.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/OptimizeInstructions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MemoryPacking.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/Directize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/Heap2Local.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/Inlining.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/toolchain-inlining.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/directize_init.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-module-elements-tables-init.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/heap2local-rmw.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/string-lowering_types.wast
related:
  - ../../binaryen/release-horizon-and-oracles.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/tracker.md
  - ../../binaryen/passes/constraint-analysis/index.md
  - ../../../../agent-todo.md
---

# Binaryen `version_131` release impact audit

## Executive decision

Binaryen `version_131` is the stable Starshine source/oracle baseline as of 2026-07-18.

- GitHub published the release on **2026-07-15 at 19:11:37 UTC**.
- The tag resolves to commit `1f903c14babf829745b421b92ff0f286e93e4209`.
- It is `92` commits ahead of `version_130` commit `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`.
- Binaryen added one public pass, `constraint-analysis`, and one hidden test pass, `remove-start`.
- The default optimization scheduler and the top-level no-DWARF `-O4z` pass order did **not** change between the two tags. The existing 56-slot / 38-owner O4z roster remains the correct scheduler baseline.
- Six Starshine implementation areas must be reopened because their upstream owner behavior changed after the v130 signoff: `optimize-instructions`, `memory-packing`, `remove-unused-module-elements`, `directize`, `heap2local`, and the shared `inlining` / `inlining-optimizing` engine.
- `pick-load-signs` has already completed an explicit v131 audit and remains closed.

The local `wasm-opt` found on `PATH` during this audit is TinyGo's Binaryen `version_116`, not v131. Every v131 parity command must therefore pass an explicit verified official v131 binary through `--wasm-opt-bin`; a bare `wasm-opt` command is not acceptable evidence.

## Registration and scheduler delta

A direct parse of `src/passes/pass.cpp` at both tags found:

| Surface | `version_130` | `version_131` | Delta |
| --- | ---: | ---: | --- |
| Public `registerPass(...)` names | 170 | 171 | `constraint-analysis` added |
| Hidden `registerTestPass(...)` names | 7 | 8 | `remove-start` added |
| Public pass removals | 0 | 0 | none |
| Hidden pass removals | 0 | 0 | none |

The only `pass.cpp` changes are those two registrations. There is no diff in `addDefaultFunctionOptimizationPasses()`, the global pre/post pass builders, or the optimize/shrink ordering logic. Therefore:

- do not reconstruct the O4z scheduler from scratch;
- relabel the current O4z ledger from v130 to v131;
- keep existing scheduler gaps open exactly where they were;
- add v131 direct-pass work before changing preset order.

## Mandatory Starshine parity reopens

### `optimize-instructions`

Upstream v131 changed behavior in the owner file, not just tests:

- equal consecutive `ref.eq` inputs can now keep one evaluation and fold to true;
- identical `select` arms can be collapsed even when a scratch local is required to preserve condition/effect order;
- equality reasoning for idempotent calls now uses deeper child/parent effect ordering;
- `skipNonNullCast` and descriptor movement checks use directional `orderedBefore(...)` reasoning;
- non-concrete select-arm types now fail closed instead of crashing.

The v130 OI closeout does not cover those semantics. Reopen OI with focused ref-equality, identical-select, idempotent-call/global-effects, effect-order, and non-concrete-arm fixtures before rerunning the four-lane matrix.

### `memory-packing`

The previously documented current-main gap is now part of the released oracle:

- overlapping active data segments can be optimized by zeroing bytes trampled by later segments;
- imported-memory overlap is admitted only when every active segment is provably in bounds of the declared minimum;
- the proof handles memory64 and custom page-size arithmetic without wrapping;
- out-of-bounds imported-memory overlap still bails because partially applied writes remain observable after failed instantiation.

Starshine currently rejects every active overlap. The pass is no longer behavior-closed against the stable release.

### `remove-unused-module-elements`

Binaryen v131 adds table-initial-value and overlap-aware liveness/trap behavior:

- a table's initial value participates in callable-function discovery;
- wrong-type and null table writes may need to survive when removing them would expose a compatible default or earlier write and eliminate an indirect-call trap;
- overlapping or dynamically placed element segments force more conservative segment retention when traps may happen;
- `trapsNeverHappen` changes that retention boundary;
- null table segments received additional focused handling.

The existing Starshine signoff predates those families. Reopen direct RUME and the two O4z RUME neighborhoods.

### `directize`

Binaryen v131's constant-target classification now considers table initial values explicitly:

- an in-bounds `ref.func` table initializer can identify a direct target;
- a null/default hole can prove a trap;
- an imported table initializer remains unknown;
- non-`ref.func` initializers such as `global.get` remain unknown;
- table growth and runtime sets are distinguished from immutable initial contents;
- out-of-initial-range indices are traps only when later growth cannot populate them.

Starshine's accepted default implementation is segment-driven and does not implement the released table-initializer matrix. Reopen directize and the accepted late-tail suffix.

### `heap2local`

Binaryen v131 contains two correctness/robustness changes:

- local graph, parent, and branch-target analyses are rebuilt after each successful allocation optimization so later candidates do not use stale analysis state;
- `adjustTypeFlowingThrough(...)` stops when the rewritten path is already unreachable instead of forcing an invalid concrete type through dead code.

The old Starshine matrix does not prove multiple sequential candidate safety against the new oracle. Reopen with multi-allocation, stale-analysis, and unreachable-flow fixtures, then rerun the pass-specific aggregate and O4z slot.

### `inlining` and `inlining-optimizing`

Binaryen v131 gives the current toolchain inline hint a released producer and consumer contract:

- `@binaryen.inline` is added as a toolchain annotation distinct from `@metadata.code.inline`;
- `@binaryen.inline "\00"` (`NeverInline`) rejects full inlining after the `try_delegate` bailout;
- `@binaryen.inline "\7f"` (`AlwaysInline`) accepts full inlining before ordinary size/use heuristics;
- `strip-toolchain-annotations` removes the new hint.

Starshine preserves `@metadata.code.inline` as metadata and has separate `no-inline*` policy markers, but it does not consume `@binaryen.inline` as Binaryen v131 full-inline policy. Reopen the shared inliner once for both public variants; keep nested-scheduler work separately owned by the existing O4z nested-rerun slice.

## Released upstream changes that need dossier refresh but not a new v0.1.0 parity blocker

These passes are not currently accepted Starshine direct implementations in the relevant released scope, or their current-main drift was already documented. Their living pages should be retagged to v131 and corrected, but no newly closed local pass needs reopening solely from this release:

| Pass/surface | v131 change | Local disposition |
| --- | --- | --- |
| `constraint-analysis` | New public CFG constraint-propagation/folding pass. | Add upstream-only landing page; no local spelling. |
| `remove-start` | New hidden test pass that clears `module->start`. | Record as hidden test infrastructure, not public pass parity. |
| `global-effects` | Excludes unaddressed functions from indirect-call targets and accounts for inexact imported functions across subtypes. | Refresh dossier; Starshine remains boundary-only. |
| `remove-unused-types` | Explicit open-world fatal removed; `GlobalTypeRewriter` applies world-mode public-type policy. | Existing current-main correction becomes released behavior. |
| `unsubtyping` | Explicit open-world fatal removed; world-mode public types remain frozen. | Existing current-main correction becomes released behavior. |
| `type-ssa` | Exact table initializer types now block unsafe allocation subtype splitting. | Refresh upstream-only dossier. |
| `remove-relaxed-simd` | Replacement block is explicitly typed `unreachable`. | Refresh upstream-only dossier. |
| `string-lowering` | String-bearing tag signatures are rewritten with function signatures. | Refresh upstream-only dossier. |
| `strip-toolchain-annotations` | Clears `@binaryen.inline` toolchain hints. | Link from inlining refresh. |
| `print-boundary` | Recursive function-reference signatures no longer recurse infinitely in JSON output. | Existing current-main page becomes released behavior. |
| `asyncify` | Function-name and wildcard matching uses the corrected internal name representation and cleaner diagnostics. | Existing upstream-only dossier needs a tag refresh. |
| `safe-heap` | Atomic helper generation is allowed on non-shared memory when atomics are enabled and the integer access is naturally aligned. | Added upstream-only landing page; no local spelling. |
| `merge-j2cl-itables` | Aborts if a class/vtable/itable type to be rewritten is public. | Added upstream-only specialized-pass landing page; no local spelling. |
| `poppify` | Preserves unreachable local-set shape needed for non-nullable locals. | Internal/shared-lowering watchpoint, not a Starshine public pass row. |

## Secondary v131 oracle spot-check set

Several pass owner files did not change, but Binaryen's expected pass tests changed because shared effect, type, printing, or finalization helpers changed. Do not reopen these automatically as implementation blockers, but rerun targeted v131 probes before relying on old v130 closeout evidence in a release decision:

- `code-pushing`
- plain DAE / `dae2` (already open through the DAE backlog)
- `heap-store-optimization`
- `precompute`
- `remove-unused-brs`
- the five `simplify-locals` variants
- `tuple-optimization`
- closed-world GUFA/type passes when that queue becomes active

A targeted probe that remains behavior-green may simply renew the old closeout. A mismatch must be classified against the v131 shared-helper contract before deciding whether to open a dedicated pass slice.

## Documentation actions

Required in this maintenance change:

1. advance the release-horizon page and catalogs to `version_131`;
2. state that the 56-slot O4z scheduler is unchanged;
3. relabel `agent-todo.md` to the v131 ledger and add the six mandatory release-refresh slices;
4. add a `constraint-analysis` landing page and tracker row;
5. mark the six accepted Starshine pass areas as reopened in their living pages;
6. preserve `pick-load-signs` as already v131-closed;
7. record the local `PATH` oracle mismatch (`version_116`) and require explicit `--wasm-opt-bin` for v131 evidence;
8. add this note to the wiki index and chronological log;
9. relabel pre-release current-main findings as released v131 behavior in `remove-unused-types`, `unsubtyping`, `print-boundary`, and related type/annotation pages;
10. add missing upstream-only landing pages for released `safe-heap` and `merge-j2cl-itables` changes;
11. mark shared-helper-sensitive closed passes as v130-closed pending `[V131-SPOT]001`, rather than silently presenting them as v131-renewed.

## Signoff rule for reopened passes

Each reopened pass must use:

- an official v131 binary that reports `wasm-opt version 131 (version_131)`;
- explicit `--wasm-opt-bin <v131-path>` on compare/self-opt commands;
- red-first focused fixtures for the new upstream families;
- the repository's full four-lane pass closeout matrix;
- the relevant direct O4z or late-tail neighborhood;
- source-backed mismatch classification and performance evidence.

Do not close a v131 slice merely because ordinary random GenValid remains green; the release changes are concentrated shapes that broad generation may not sample.
