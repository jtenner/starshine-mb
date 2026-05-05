---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-directize-current-main-recheck.md
  - ../../../raw/research/0476-2026-05-05-directize-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md
  - ../../../raw/research/0380-2026-04-26-directize-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md
  - ../../../raw/research/0350-2026-04-25-directize-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-directize-primary-sources.md
  - ../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/directize.mbt
  - ../../../../../src/passes/directize_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../duplicate-import-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./table-info-and-immutability.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../duplicate-import-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
---

# Starshine Strategy For `directize`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-directize-primary-sources.md`](../../../raw/binaryen/2026-04-22-directize-primary-sources.md), the 2026-05-05 current-main source bridge in [`../../../raw/binaryen/2026-05-05-directize-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-directize-current-main-recheck.md), and the 2026-04-26 port-readiness bridge in [`../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.
For the first-slice order and validation ladder, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## The honest current status

`directize` is now implemented in Starshine as an active explicit module pass in `src/passes/directize.mbt`, with direct Binaryen oracle evidence for the default pass behavior.

The current local strategy is still deliberately conservative where the upstream pass is policy-sensitive:

- keep the pass spelling tracked in the registry surface as an active module pass
- preserve the boundary-shaped architecture by computing whole-module table facts before any function-body rewrite
- rewrite compatible constant-index indirect calls through non-imported, non-exported, non-mutated known table entries
- classify known holes, out-of-range entries, and wrong-type targets as traps and rewrite them to `unreachable`
- lower the narrow known-target `select` shape to direct-call `if` arms with fresh locals
- keep the canonical no-DWARF tail slot documented but out of presets until the neighboring `string-gathering -> reorder-globals -> directize` tail can be replayed together
- leave optional `directize-initial-contents-immutable` pass-arg behavior for a future pass-arg surface

So this page is now an **implemented explicit-pass status-and-port-map** page. The current 2026-05-05 current-main source bridge remains the upstream contract for future preset and pass-arg work.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active module-pass registry status
  - `src/passes/optimize.mbt:281`
    - `pass_registry_entries()` includes `pass_registry_entry_module("directize", directize_summary())`
- module-pass dispatch
  - `src/passes/pass_manager.mbt:8940`
    - `run_hot_pipeline_apply_module_pass(...)` routes `"directize"` to `directize_run_module_pass(...)`
- implementation and focused tests
  - `src/passes/directize.mbt:933`
  - `src/passes/directize_test.mbt:2`
- backlog and delivery plan
  - `agent-todo.md:689-701`
    - `DIR` slice under the Binaryen no-DWARF default optimize pathway parity section, now recording direct explicit-pass oracle evidence
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:34-35`
    - the final late-tail slot where `directize` follows `reorder-globals`
- neighboring living dossiers a future port must line up with
  - `docs/wiki/binaryen/passes/duplicate-import-elimination/index.md`
  - `docs/wiki/binaryen/passes/simplify-globals-optimizing/index.md`
  - `docs/wiki/binaryen/passes/remove-unused-module-elements/index.md`
  - `docs/wiki/binaryen/passes/string-gathering/index.md`
  - `docs/wiki/binaryen/passes/reorder-globals/index.md`

Additional implementation substrate now mapped in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md):

- `src/wast/parser.mbt:1874-1885` and `src/wast/lower_to_lib.mbt:1919-1958` for WAT indirect-call parsing/lowering.
- `src/wast/lower_to_lib.mbt:2171-2252` plus `src/lib/types.mbt:198-212`, `221`, and `780-785` for table/element/mutation shapes.
- `src/lib/types.mbt:526-531`, `src/binary/decode.mbt:2544-2564`, `src/binary/encode.mbt:2008-2028`, and `src/lib/show.mbt:866-882` for direct/indirect call representation and roundtrip.
- `src/ir/hot_side_tables.mbt:249-254` and `src/ir/hot_lower.mbt:993-1018` for HOT signature/table side data and lowering.
- `src/validate/typecheck.mbt:907-944` and `3216-3219` plus negative tests in `src/validate/typecheck_negative_tests.mbt:332-391` for validation of call-indirect table/type boundaries.

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status, reusable substrates, and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `directize` is an active Binaryen-shaped explicit module pass for the default pass behavior.

### 1. The name is active, not forgotten

`src/passes/optimize.mbt` registers `directize` as a module pass.
That means:

- the project treats `directize` as a real executable pass
- the spelling is preserved in the registry-level compatibility surface and CLI pass parser
- the pass remains visible in tracker and backlog work instead of silently falling out of planning
- the implementation keeps module/table analysis ahead of function-local rewrites

### 2. The pass rewrites the default Binaryen directize families

`src/passes/directize.mbt` currently rewrites compatible `call_indirect` / `return_call_indirect` sites when the target expression is an immediate `i32.const` and the selected table entry is known from active element segments. It bails out for imported tables, exported tables, and runtime-mutated tables, and it leaves unknown entries indirect.

It also handles the two important non-direct-call target classes from the default pass contract:

- known holes / out-of-range / wrong-type targets become `unreachable`
- the narrow known-target `select` index shape becomes an `if` with direct-call arms and fresh locals for operands

### 3. The remaining work is preset and option integration, not core default-pass parity

`agent-todo.md` keeps `directize` under `DIR`, but the active remaining local work is now narrower:

- keep direct Binaryen oracle evidence current
- add the final late-tail preset only after the neighboring `string-gathering -> reorder-globals -> directize` sequence is locally replayable
- decide how Starshine should expose Binaryen-style pass args before adding `directize-initial-contents-immutable`

That backlog framing keeps the implemented explicit pass separate from still-unscheduled tail integration.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `directize` port should be taught as a **late boundary/module pass**, not as an isolated HOT peephole.

Why:

- Binaryen runs it after `reorder-globals`
- it is the last top-level pass in the canonical no-DWARF tail
- its correctness depends on module-wide table facts before function-local rewriting starts
- its rewrites can refine call result types and convert known traps into `unreachable`, so the eventual local implementation will need explicit rewrite plus repair logic instead of a cheap local pattern match

So the local strategy is:

1. collect whole-module table and element knowledge first
2. classify target expressions with the same `Known` / `Trap` / `Unknown` boundary the Binaryen dossier teaches
3. apply function-local call rewrites only after that proof exists
4. preserve late-tail scheduler placement after the neighboring global/string/module cleanup passes
5. keep validation and artifact proof focused on mixed known/unknown/trap table surfaces

In other words, the implemented explicit pass is ready, while the future preset slot still has to fit into the documented late optimization ecosystem.

## The most important local dependency map

### `directize` is downstream of the whole late cleanup tail

See:

- [`../duplicate-import-elimination/index.md`](../duplicate-import-elimination/index.md)
- [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)
- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)
- [`../string-gathering/index.md`](../string-gathering/index.md)
- [`../reorder-globals/index.md`](../reorder-globals/index.md)

Why it matters locally:

- the no-DWARF scheduler docs already place `directize` after all of those passes
- the Binaryen strategy page says the pass wants table/global shape mostly settled before it reasons about table entries
- a future Starshine port should therefore validate not only `--directize` in isolation, but also the real tail neighborhood that feeds it

### `directize` is late boundary work, not a neighbor of the current HOT peephole cluster

This is one of the most important local teaching points.
The current active Starshine HOT cluster covers passes like:

- `dead-code-elimination`
- `remove-unused-names`
- `remove-unused-brs`
- `optimize-instructions`
- `heap-store-optimization`
- `precompute`
- `merge-blocks`

Those are valuable neighboring dossiers for style and validation habits, but `directize` does not naturally belong in that early/mid function-local cluster.
Its module-pass classification is intentional: the Binaryen dossier teaches that module-wide table facts come first.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine still does **not** currently have:

- the optional `directize-initial-contents-immutable` pass-arg mode
- preset scheduling for the full no-DWARF late tail
- a combined oracle replay for `string-gathering -> reorder-globals -> directize`, because `string-gathering` is still not active locally

So the current repo status is best summarized as:

- active module pass tracked
- default explicit-pass directize behavior implemented
- direct Binaryen oracle evidence recorded
- scheduler slot documented but not preset-scheduled
- parser / IR / binary / validation / HOT substrates mapped
- remaining work is pass-arg and late-tail integration, not the core default explicit pass

## Validation evidence and future validation plan

Current direct evidence:

1. local build/test gate
   - `moon info`
   - `moon fmt`
   - `moon test src/passes`
   - `moon test src/cmd`
   - `moon test`
2. focused Binaryen oracle lanes
   - `.tmp/pass-fuzz-directize-genvalid-10000-final2`: `10000/10000` compared, `10000` normalized matches, `0` mismatches/failures
   - `.tmp/pass-fuzz-directize-mixed-10000-final2`: `9975` comparable normalized matches, `0` mismatches, `25` Binaryen-side command failures
3. debug artifact oracle lane
   - `.tmp/self-opt-directize-debug-final2`: canonical wasm equality and normalized WAT equality on `tests/node/dist/starshine-debug-wasi.wasm`

Future changes should rerun those direct lanes when touching table facts, trap rewriting, select lowering, type matching, or local insertion. Preset scheduling should additionally replay the full late tail once `string-gathering` is active.

## Bottom line

Current Starshine `directize` strategy is an active explicit module pass plus late-tail landing-zone planning:

- the pass name is intentionally preserved in `src/passes/optimize.mbt` as an active module pass
- `src/passes/directize.mbt` implements default directize behavior for direct calls, known traps, and narrow select lowering
- `agent-todo.md` records direct oracle evidence under `DIR`
- the canonical slot is already documented in the no-DWARF optimizer notes but remains out of presets
- the surrounding `duplicate-import-elimination`, `simplify-globals-optimizing`, `remove-unused-module-elements`, `string-gathering`, and `reorder-globals` dossiers already define the practical landing zone for scheduled tail integration

So the right mental model today is:

- **explicit pass implemented**
- **direct Binaryen oracle parity green**
- **clear late-tail dependency story**
- **preset/pass-arg integration remains future work**

## Sources

- [`../../../raw/binaryen/2026-05-05-directize-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-directize-current-main-recheck.md)
- [`../../../raw/research/0476-2026-05-05-directize-current-main-recheck.md`](../../../raw/research/0476-2026-05-05-directize-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md)
- [`../../../raw/research/0380-2026-04-26-directize-port-readiness.md`](../../../raw/research/0380-2026-04-26-directize-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md)
- [`../../../raw/research/0350-2026-04-25-directize-current-main-recheck.md`](../../../raw/research/0350-2026-04-25-directize-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-directize-primary-sources.md`](../../../raw/binaryen/2026-04-22-directize-primary-sources.md)
- [`../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md`](../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
