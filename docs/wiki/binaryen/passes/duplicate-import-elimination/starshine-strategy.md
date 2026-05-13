---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0519-2026-05-06-duplicate-import-elimination-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-duplicate-import-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md
  - ../../../raw/research/0269-2026-04-23-duplicate-import-elimination-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../duplicate-function-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ../duplicate-function-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
---

# Starshine Strategy For `duplicate-import-elimination`

Use this page together with the raw primary-source manifests in [`../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md) and [`../../../raw/binaryen/2026-05-04-duplicate-import-elimination-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-duplicate-import-elimination-current-main-recheck.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas future maintenance or late-preset work must hook into.

## The honest current status

As of 2026-05-06, `duplicate-import-elimination` is implemented in Starshine as a small active module pass with the source-confirmed Binaryen `version_129` function-import-only contract and refreshed direct parity evidence.

The current local strategy is no longer boundary-only tracking. The pass now:

- owns its transform in `src/passes/duplicate_import_elimination.mbt`
- is registered as a `ModulePass` in `src/passes/optimize.mbt`
- is dispatched through the module-pass path in `src/passes/pass_manager.mbt`
- is accepted by the CLI and the pass-fuzz comparison harness
- keeps the canonical no-DWARF late slot documented without yet widening the public `optimize` preset to replay the full late tail
- keeps any future non-function import deduplication as explicit upstream-drift / deliberate-divergence work

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- implementation owner
  - [`src/passes/duplicate_import_elimination.mbt#L340-L410`](../../../../../src/passes/duplicate_import_elimination.mbt#L340-L410)
    - plans imported-function duplicate buckets, first-import-wins canonicalization, and defined-function index shifts
  - [`src/passes/duplicate_import_elimination.mbt#L414-L584`](../../../../../src/passes/duplicate_import_elimination.mbt#L414-L584)
    - rewrites function-name users, metadata, module-code expressions, and removes duplicate imported-function declarations
  - [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md)
    - shared imported-prefix function-index section contract that explains why removing function imports shifts every later defined `FuncIdx`
- active module-pass registry status
  - [`src/passes/optimize.mbt#L246`](../../../../../src/passes/optimize.mbt#L246)
    - `pass_registry_entries()` includes `"duplicate-import-elimination"` as a module pass
- module-pass dispatch
  - [`src/passes/pass_manager.mbt#L8647`](../../../../../src/passes/pass_manager.mbt#L8647)
    - `run_hot_pipeline_apply_module_pass(...)` calls `die_run_module_pass(...)`
- focused local proof surface
  - [`src/passes/duplicate_import_elimination_test.mbt#L60-L163`](../../../../../src/passes/duplicate_import_elimination_test.mbt#L60-L163)
    - duplicate collapse, non-function/different-signature preservation, and first-import bucket rule regressions
  - [`src/passes/registry_test.mbt#L58-L62`](../../../../../src/passes/registry_test.mbt#L58-L62)
    - registry category coverage
  - [`src/cmd/cmd_wbtest.mbt#L4084-L4125`](../../../../../src/cmd/cmd_wbtest.mbt#L4084-L4125)
    - native `run_cmd_with_adapter` execution on wasm bytes
- backlog and delivery plan
  - [`agent-todo.md#L525-L533`](../../../../../agent-todo.md#L525-L533)
    - `DIE - Duplicate Import Elimination`
- canonical scheduler context
  - [`../../no-dwarf-default-optimize-path.md#L35`](../../no-dwarf-default-optimize-path.md#L35)
    - the canonical late-tail slot where `duplicate-import-elimination` follows `duplicate-function-elimination` and precedes `simplify-globals-optimizing`
- neighboring living dossiers future maintenance and preset replay must line up with
  - [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md)
  - [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)
  - [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine accepts `duplicate-import-elimination` as an executable direct module pass.

### 1. The name is active, not boundary-only

`src/passes/optimize.mbt` registers `duplicate-import-elimination` as a `ModulePass`.
That means:

- explicit pass selection no longer rejects as boundary-only
- the CLI/API surface can run the pass directly
- the pass remains structurally separate from the HOT-only function pipeline, matching its module import / function-reference rewrite scope

### 2. The current transform is intentionally function-import-only

The implementation follows the corrected Binaryen `version_129` contract:

- scan imported functions only
- bucket by `(module, base)`
- compare later aliases only against the first import in that bucket
- require exact resolved function-type equality
- rewrite direct `call`, `return_call`, `ref.func`, start, function exports, element contents, and module-code expressions that can carry function references
- preserve non-function imports and mismatched signatures

### 3. Remaining follow-up is late-tail and future-drift work

`agent-todo.md` now gives the pass a real `DIE` follow-up slice that matches the reviewed Binaryen `version_129` contract:

- the direct module pass is active
- full late-tail preset replay is still future work
- non-function import deduplication is explicitly gated on future Binaryen evidence or deliberate Starshine divergence

That matters because older local planning text used to be broader than upstream and described table/global/memory import-user patching as if it belonged to the reviewed contract. The 2026-05-04 current-main recheck keeps that older broad interpretation stale: the upstream pass is still function-import-only, keyed by `(module, base)`, gated by exact function-type equality, and limited to the function-name rewrite surface described in [`./identity-and-rewrite-surface.md`](./identity-and-rewrite-surface.md).

## The right Starshine implementation shape

The current implementation and neighboring passes show that local `duplicate-import-elimination` should remain a **small late boundary/module pass**, not a generic import deduplicator and not a HOT peephole.

Why:

- Binaryen runs it late, after `duplicate-function-elimination`
- its correctness depends on module import declarations plus module-level function-reference rewriting
- the real upstream pass is tiny and structural rather than analysis-heavy
- the immediate downstream neighbor `simplify-globals-optimizing` expects the late-boundary module to be a little cleaner before it starts its own rewrite work

So the local strategy is:

1. scan imported functions only
2. bucket candidates by `(module, base)`
3. require exact function-type equality before merging
4. preserve first-import-wins canonicalization
5. rewrite only the actual Binaryen function-name surfaces
6. remove duplicate imported functions immediately
7. leave broader all-import deduplication as future divergence work unless upstream itself widens the contract

That is much tighter and safer than the older broad “deduplicate every import kind” mental model.

## The most important local dependency map

### `duplicate-import-elimination` is downstream of `duplicate-function-elimination`

See:

- [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md)

Why it matters locally:

- the no-DWARF scheduler docs already place `duplicate-import-elimination` after a second `duplicate-function-elimination`
- Starshine should validate not just `--duplicate-import-elimination` in isolation, but also the late-boundary neighborhood that feeds it
- the upstream pass itself is small, so getting the scheduler slot and neighboring state right matters more than building a large local framework around it

### `duplicate-import-elimination` feeds the later late-boundary cleanup tail

See:

- [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)
- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)

Why it matters locally:

- the canonical no-DWARF scheduler places `duplicate-import-elimination` before both of those passes
- even though the pass is function-import-only, it still changes the module's import/function-name surface before later cleanup and reachability passes run
- Starshine should therefore validate the pass in the real late-tail neighborhood, not only as a standalone import rewrite

### `duplicate-import-elimination` is boundary work, not a neighbor of the current HOT peephole cluster

This is one of the most important local teaching points.
The current active Starshine HOT cluster covers passes like:

- `dead-code-elimination`
- `remove-unused-names`
- `remove-unused-brs`
- `optimize-instructions`
- `precompute`
- `merge-blocks`

Those are useful neighboring dossiers for style and validation habits, but `duplicate-import-elimination` does not naturally belong in that cluster.
Its current module-pass classification is not arbitrary bookkeeping.
It reflects the same architectural fact the Binaryen dossier teaches: this pass rewrites module import and function-reference surfaces, not HOT-region local patterns.

## Direct revalidation evidence

The 2026-05-06 post-fuzzer-change revalidation lane ran `moon info`, `moon fmt`, `moon test`, and `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-import-elimination --out-dir .tmp/pass-fuzz-duplicate-import-elimination`.

The compare run reported 6759 / 10000 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures. That closes the AUD002 stale-evidence item for the direct module pass while leaving late-tail preset replay as future neighborhood work. See [`../../../raw/research/0519-2026-05-06-duplicate-import-elimination-direct-revalidation.md`](../../../raw/research/0519-2026-05-06-duplicate-import-elimination-direct-revalidation.md).

## What Starshine has now

A future contributor should be careful not to overread the current local surface beyond the function-import-only contract.
Starshine now has:

- `src/passes/duplicate_import_elimination.mbt`
- imported-function bucketing and first-import canonicalization logic
- a local function-reference rewrite surface for direct calls, return calls, refs, start, exports, element payloads, global/table/data offset expressions, names, and function annotations
- focused pass regressions in `src/passes/duplicate_import_elimination_test.mbt`
- CLI dispatch coverage in `src/cmd/cmd_wbtest.mbt`
- direct compare evidence against Binaryen on fuzz and the checked-in debug artifact

So the current repo status is best summarized as:

- transform landed
- active module-pass registry status
- CLI and compare-harness surfaces wired
- scheduler slot documented but not yet placed into the public full late-tail preset
- corrected function-import-only scope preserved

## Validation plan for the eventual port

The existing backlog plus the upstream dossier imply the right validation ladder.
The landed implementation should continue to validate in this order:

1. reduced shape tests for the real upstream families
   - duplicate imported-function positives
   - preserved different-signature negatives
   - `ref.func` and element-payload rewrites
   - `start` and export retargeting
2. scope-boundary negatives
   - imported globals, tables, memories, and tags remain untouched for strict `version_129` parity
3. scheduler-neighborhood interaction tests
   - the late boundary segment around `duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements`
4. artifact and oracle comparison
   - the `DIE` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact neighboring passes that should feed the port.

## Bottom line

Current Starshine `duplicate-import-elimination` strategy is an active module-pass implementation plus a corrected port map:

- the pass owner is [`src/passes/duplicate_import_elimination.mbt`](../../../../../src/passes/duplicate_import_elimination.mbt)
- the registry and dispatcher surfaces are [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`agent-todo.md`](../../../../../agent-todo.md) now keeps only late-tail / future-drift follow-up under `DIE`
- the canonical slot is still documented in [`../../no-dwarf-default-optimize-path.md#L35`](../../no-dwarf-default-optimize-path.md#L35)
- the surrounding [`duplicate-function-elimination`](../duplicate-function-elimination/index.md), [`simplify-globals-optimizing`](../simplify-globals-optimizing/index.md), and [`remove-unused-module-elements`](../remove-unused-module-elements/index.md) dossiers define the remaining late-tail landing zone

The right mental model today is:

- **direct transform landed**
- **function-import-only parity scope**
- **green direct fuzz / artifact evidence**
- **late preset replay still future work**
