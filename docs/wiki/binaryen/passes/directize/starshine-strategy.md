---
kind: concept
status: supported
last_reviewed: 2026-07-30
sources:
  - ../../release-horizon-and-oracles.md
  - ./index.md
  - ../late-pipeline-dispatch.md
  - ../reorder-globals/index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/directize.mbt
  - ../../../../../src/passes/directize_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../duplicate-import-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
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

Use this page together with the retained 2026-05-05 current-main recheck in [research note 0476](./index.md) and the 2026-04-26 port-readiness digest in [research note 0380](./index.md), which preserve direct tagged and current source/test URLs for the documented contract.
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.
For the first-slice order and validation ladder, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## The honest current status

`directize` is implemented in Starshine as an active explicit module pass in `src/passes/directize.mbt`. The 2026-07-30 source/profile renewal closes the released default behavior across table32/table64 addresses, sparse segment/default facts, direct/trap/unknown classification, known/trap and multivalue select lowering, tail calls, GC subtyping, mutation/growth boundaries, and legacy-EH traversal. Optional `directize-initial-contents-immutable` pass-arg support remains separate.

The current local strategy is still deliberately conservative where the upstream pass is policy-sensitive:

- keep the pass spelling tracked in the registry surface as an active module pass
- preserve the boundary-shaped architecture by computing whole-module table facts before any function-body rewrite
- rewrite compatible constant-index indirect calls through non-imported, non-exported, non-mutated known table entries
- classify known holes, out-of-range entries, and wrong-type targets as traps and rewrite them to `unreachable`
- lower known/known, known/trap, and trap/trap constant-index `select` shapes to direct-call or trapping `if` arms with fresh operand locals
- keep the accepted public late-tail suffix documented alongside the no-DWARF order, with any broader widening beyond that suffix still gated on fresh evidence
- leave optional `directize-initial-contents-immutable` pass-arg behavior for a future pass-arg surface

So this page is now an **implemented explicit-pass status-and-port-map** page. The current 2026-05-05 current-main source bridge remains the upstream contract for future pass-arg and broader-widening work.

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
  - `agent-todo.md`
    - the remaining follow-up is pass-arg support and any broader widening beyond the accepted public suffix; the direct `DIR` triple-replay slice is closed
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

`src/passes/directize.mbt` rewrites compatible `call_indirect` / `return_call_indirect` sites when the target is an immediate table-width constant (`i32.const` for table32 or `i64.const` for table64) and sparse segment/default facts classify it as known or trapping. It bails out for imported tables, exported tables, and runtime-mutated tables, and it leaves unknown entries indirect.

It also handles the two important non-direct-call target classes from the default pass contract:

- known holes / out-of-range / wrong-type targets become `unreachable`
- known/known, known/trap, and trap/trap constant-index `select` shapes become typed `if` expressions with direct-call or `unreachable` arms and fresh locals preserving operand evaluation

### 3. V131 table-initial-value parity is now core default-pass work

`agent-todo.md` no longer needs a dedicated `DIR` replay blocker because the neighboring `string-gathering -> reorder-globals -> directize` sequence is now locally replayable.

The active local work is:

- implement and test v131 table initializer target/trap/unknown classification;
- renew direct Binaryen oracle evidence and the accepted late-tail suffix;
- keep broader late-tail widening gated on fresh neighboring evidence;
- decide optional Binaryen-style pass args separately from the released default behavior.

That framing keeps the implemented segment-driven core while making the new released gap explicit.

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

In other words, the implemented explicit pass is ready, while any broader widening beyond the accepted public suffix still has to fit into the documented late optimization ecosystem.

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
- any broader late-tail widening beyond the accepted public suffix
- any replay that extends earlier than the accepted public suffix at `simplify-globals-optimizing -> remove-unused-module-elements`

So the current repo status is best summarized as:

- active module pass tracked
- default explicit-pass directize behavior implemented
- direct Binaryen oracle evidence recorded
- accepted public late-tail suffix scheduled in `optimize` / `shrink`
- parser / IR / binary / validation / HOT substrates mapped
- remaining work is pass-arg support and any broader widening beyond the accepted public suffix, not the core default explicit pass

## Validation evidence and future validation plan

Current direct evidence is recorded in [`./fuzzing.md`](./fuzzing.md):

1. regular GenValid: `100000/100000` exact;
2. pass-owned `directize-all`: `10000/10000` exact, with all eight leaves and 27 source-derived labels selected;
3. wasm-smith: all `9956` comparable cases green after classifying one no-call `drop(unreachable)` wrapper residual, plus `44` Binaryen/tool admissions;
4. random all-profiles: zero directize-owned residuals; all `180` raw differences are no-call `remove-unused-brs-*` local reconstruction/encoding cases;
5. pass-local artifact time: `46.973ms` versus Binaryen `42.052ms` (`1.12x`, inside the repository target).

The audit repaired full-width table64 handling, address-width validation, trap-arm and multivalue select lowering, explicit-null default classification, and large-table allocation behavior. Future changes should rerun the same matrix when touching table facts, trap rewriting, select lowering, type matching, local insertion, or legacy-EH traversal.

## Bottom line

Current Starshine `directize` strategy is an active explicit module pass plus late-tail landing-zone planning:

- the pass name is intentionally preserved in `src/passes/optimize.mbt` as an active module pass
- `src/passes/directize.mbt` implements default directize behavior for direct calls, known traps, and narrow select lowering
- `agent-todo.md` now leaves only the optional pass-arg / broader-widening follow-up; the accepted public late-tail suffix is already scheduled in `optimize` / `shrink`
- the canonical slot is already documented in the no-DWARF optimizer notes and the accepted public suffix now matches that order
- the surrounding `duplicate-import-elimination`, `simplify-globals-optimizing`, `remove-unused-module-elements`, `string-gathering`, and `reorder-globals` dossiers already define the practical landing zone for scheduled tail integration

So the right mental model today is:

- **explicit pass implemented**
- **direct Binaryen oracle parity green**
- **clear late-tail dependency story**
- **pass-arg support and any broader widening beyond the accepted public suffix remain future work**

## Sources

- [research note 0476](./index.md)
- [research note 0380](./index.md)
- [research note 0350](./index.md)
- [research note 0265](./index.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
