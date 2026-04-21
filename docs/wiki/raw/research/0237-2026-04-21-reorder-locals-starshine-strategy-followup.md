# Binaryen / Starshine `reorder-locals` follow-up: local strategy map, code locations, and dossier health

_Date:_ 2026-04-21  
_Status:_ absorbed into the living `docs/wiki/binaryen/passes/reorder-locals/` dossier in this same change  
_Related living pages:_
- `docs/wiki/binaryen/passes/reorder-locals/index.md`
- `docs/wiki/binaryen/passes/reorder-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/names-roundtrip-and-porting.md`
- `docs/wiki/binaryen/passes/reorder-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/parity.md`
- `docs/wiki/binaryen/passes/reorder-locals/multivalue-call-scope.md`

## Why this follow-up existed

The `reorder-locals` folder already covered the upstream Binaryen side well:

- the landing page explained the pass purpose and scheduler role,
- the Binaryen strategy page covered `ReorderLocals.cpp`,
- the WAT-shape page covered the concrete transformed shapes,
- and the names / roundtrip page already explained why the local port had to stay module-scoped.

But one practical gap remained for Starshine contributors:

- the folder still lacked the dedicated Starshine strategy/code-map page that the surrounding implemented-pass dossiers now treat as standard.

That mattered because `reorder-locals` is an active implemented pass, not just upstream research.
Without a dedicated local strategy page, readers had to reconstruct the current MoonBit implementation from scattered references in:

- `index.md`
- `names-roundtrip-and-porting.md`
- `parity.md`
- and the source tree itself.

## Process followed

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- the existing `docs/wiki/binaryen/passes/reorder-locals/` folder
- `src/passes/reorder_locals.mbt`
- `src/passes/reorder_locals_test.mbt`
- the local registry / preset / dispatch surfaces in `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, `src/passes/optimize_test.mbt`, `src/passes/registry_test.mbt`, and `src/cmd/cmd_wbtest.mbt`

I also checked `git status` first.
The worktree was clean aside from branch metadata, so there was no unrelated-local-change blockage.

## Primary online sources reviewed

Primary official Binaryen sources reviewed for this follow-up:

- Binaryen `version_129` `src/passes/ReorderLocals.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `test/passes/reorder-locals.wast`
- Binaryen `version_129` `test/passes/reorder-locals_print_roundtrip.wast`

These were used to keep the new Starshine page honest about what is:

- the upstream ordering contract,
- the upstream metadata / print-roundtrip contract,
- and the repo-local adaptation work needed to implement the same behavior through Starshine's module boundary.

Useful source locations from the official repo:

- `ReorderLocals::doWalkFunction(...)` for the full all-locals count / first-use / `newToOld` sort / zero-suffix truncation flow
- `visitLocalGet(...)` and `visitLocalSet(...)` in `ReorderLocals.cpp` for the official access counter surface
- the post-sort `curr->localNames` / `curr->localIndices` rebuild in `ReorderLocals.cpp`
- `pass.cpp` registration and the three no-DWARF scheduler slots for `reorder-locals`
- `reorder-locals_print_roundtrip.wast` for the visible declaration-order contract, not just in-memory mutation

I also did a narrow official-source freshness check against current GitHub `main` copies of:

- `ReorderLocals.cpp`
- `reorder-locals.wast`
- `reorder-locals_print_roundtrip.wast`

The result still matched the already-documented no-drift claim: no visible current-main change on those surfaces.

## Main local code locations captured in the new living page

The new Starshine strategy page now points readers directly to the in-tree owner sites:

- `src/passes/reorder_locals.mbt:2`
  - summary string and current local scope statement
- `src/passes/reorder_locals.mbt:118`
  - `rl_scan_instruction(...)`: explicit `local.get` / `local.set` / `local.tee` counting across nested boundary instructions
- `src/passes/reorder_locals.mbt:138`
  - `rl_sort_used_body_locals(...)`: descending-count plus first-use sorter over surviving body locals
- `src/passes/reorder_locals.mbt:280`
  - `rl_defined_func_param_cache(...)`: parameter lookup from the module type section
- `src/passes/reorder_locals.mbt:312`
  - `rl_rewrite_func(...)`: no-op fast path, local-run rebuild, and optional recursive index rewrite
- `src/passes/reorder_locals.mbt:410`
  - `rl_rewrite_local_names(...)`: local-name-map repair while preserving imported-function entries
- `src/passes/reorder_locals.mbt:467`
  - `rl_rewrite_name_sec(...)`: end-to-end `NameSec` repair and stale raw-payload invalidation
- `src/passes/reorder_locals.mbt:544`
  - `reorder_locals_run_module_pass(...)`: full module rewrite over code and names
- `src/passes/reorder_locals_test.mbt:210`
  - multiple-defined-function / param-arity coverage
- `src/passes/reorder_locals_test.mbt:280`
  - params-only no-op coverage
- `src/passes/reorder_locals_test.mbt:328`
  - write-only-local survival coverage
- `src/passes/reorder_locals_test.mbt:391`
  - nested `block` / `loop` / `if` / `try_table` rewrite coverage
- `src/passes/reorder_locals_test.mbt:454`
  - local-name rewrite plus raw-payload clearing coverage
- `src/passes/reorder_locals_test.mbt:500`
  - Binaryen-materialized carrier-shape ordering coverage
- `src/passes/pass_manager.mbt:8646`
  - active module-pass dispatch site
- `src/passes/optimize.mbt:237`
  - registry entry
- `src/passes/optimize_test.mbt:390`
  - preset exclusion policy test
- `src/passes/registry_test.mbt:48`
  - module-pass-category assertion
- `src/cmd/cmd_wbtest.mbt:4082`
  - explicit CLI pass execution coverage

## Main findings

### 1. The local pass is best taught as a boundary-owned port of a tiny upstream sorter

The strongest local headline is:

- **Starshine matches the core Binaryen ordering rule, but implements it as a module pass because parameter lookup and local-name repair cross module boundaries in this repo.**

That is a real implementation-boundary difference from upstream Binaryen, not a semantic disagreement about the sorter itself.

### 2. The local scan mirrors Binaryen's logic, but must say `local.tee` explicitly

Upstream Binaryen counts tees through `LocalSet` because tee is represented there.
Starshine has a distinct boundary `LocalTee`, so the MoonBit port spells it out.

That is a small but important code-reading trap for future contributors:

- the local pass is not broader than upstream here,
- it is just using a representation with a separate tee instruction kind.

### 3. The main local algorithmic difference is data-structure shape, not pass meaning

Binaryen sorts an all-locals `newToOld` array, then truncates the zero-count suffix.
Starshine instead collects only used body locals, sorts that list, and rebuilds runs from the survivors.

That looks different in code, but it preserves the same user-visible contract for:

- parameter immobility
- descending-count body-local ordering
- first-use tie breaking
- unused-body-local dropping

So the correct teaching is “different local data structure, same visible sort rule.”

### 4. The local name-section repair deserves first-class documentation

The new page makes explicit that the current MoonBit implementation owns all of these together:

- code-section function rewrites
- `NameSec.local_names` rewrites
- imported-function local-name preservation
- stale `raw_name_sec_payload` clearing

Before this follow-up, those facts were present across the dossier but not gathered into one local strategy page.

### 5. The dossier had a small schema-health inconsistency before this change

`docs/wiki/binaryen/passes/index.md` explicitly teaches that active implemented pass folders are stable homes for:

- `binaryen-strategy.md`
- `wat-shapes.md`
- `starshine-hot-ir-strategy.md`

But `reorder-locals` still lacked the Starshine page while neighboring implemented folders already had one.
So this was both:

- pass-coverage work,
- and touched-area wiki-health work.

## Durable conclusions filed back into the living wiki

- `reorder-locals` now has the full implemented-pass dossier shape used by the surrounding pass wiki.
- The correct local teaching headline is: **Starshine implements the same core frequency-and-first-use sorter as Binaryen, but keeps it module-scoped because parameter and name metadata are boundary-owned here.**
- The touched area is healthier because the pass landing page, folder map, tracker entry, and top-level wiki index now advertise the same dossier shape.
- The primary upstream oracle remains Binaryen `version_129`; the new Starshine page exists so contributors can trace the current MoonBit implementation directly instead of inferring it from scattered notes.

## Files updated in this change

- `docs/wiki/raw/research/0237-2026-04-21-reorder-locals-starshine-strategy-followup.md`
- `docs/wiki/binaryen/passes/reorder-locals/index.md`
- `docs/wiki/binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/parity.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source links

- Binaryen `version_129` `ReorderLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderLocals.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `reorder-locals.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.wast>
- Binaryen `version_129` `reorder-locals_print_roundtrip.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.wast>
- Binaryen current `main` `ReorderLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderLocals.cpp>
- Binaryen current `main` `reorder-locals.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.wast>
- Binaryen current `main` `reorder-locals_print_roundtrip.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.wast>
