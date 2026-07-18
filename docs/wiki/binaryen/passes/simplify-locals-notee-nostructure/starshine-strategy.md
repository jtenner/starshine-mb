---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../flatten/index.md
  - ../local-cse/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ../flatten/index.md
  - ../local-cse/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
---

# Starshine Strategy For `simplify-locals-notee-nostructure`

Use this page together with the retained 2026-04-25 source bridge and the companion [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) bridge.
A 2026-05-07 backlog-closure review confirmed the current Starshine status is now best described as active direct with the aggressive prelude deferred outside the active no-DWARF parity queue.
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that track the pass, the direct-pass validation evidence, and why no standalone `SLNNS` backlog slice remains open today.

## The honest current status

`simplify-locals-notee-nostructure` is now **active direct and top-level aggressive-prelude scheduled** in Starshine.
It does not get a separate owner file; instead, `src/passes/simplify_locals.mbt` exposes a stricter policy mode of the shared locals engine:

- `allowStructure = false`
- `allowTee = false`
- nesting through existing consumer positions remains allowed

The current local strategy is still conservative:

- register and dispatch the exact upstream / saved-audit spelling;
- keep the old local removed-name spelling distinct;
- reuse the no-structure locals cleanup engine without creating fresh tees;
- schedule the exact `flatten -> simplify-locals-notee-nostructure -> local-cse` order in both top-level presets;
- keep modern SLNNS closeout and optimizing nested-rerun reconciliation open rather than treating scheduling alone as direct-pass requalification.

This page is now an active direct implementation and top-level scheduler map. The 2026-07-17 scheduling decision is recorded in [`docs/wiki/binaryen/passes/flatten/index.md`](../flatten/index.md).

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active direct pass-name status
  - `src/passes/optimize.mbt`
    - registers `"simplify-locals-notee-nostructure"` as a `HotPass`
    - keeps the old local spelling `"simplify-locals-no-tee-no-structure"` out of the active direct-pass surface
    - schedules the aggressive trio in both `optimize` and `shrink` while retaining the later full `"simplify-locals"` slot
- CLI pipeline acceptance through the registry
  - `src/cmd/cmd.mbt`
    - the pipeline parser accepts `HotPass`, `ModulePass`, or `Preset` categories
    - the exact upstream spelling is now accepted because the registry classifies it as a hot pass
- active hot-pass dispatcher
  - `src/passes/pass_manager.mbt`
    - dispatches `"simplify-locals-notee-nostructure"` to `simplify_locals_notee_nostructure_run(ctx, func)`
    - keeps the existing `"simplify-locals-nostructure"` / `"simplify-locals-no-structure"` path on the tee-allowing no-structure variant
- current shared locals owner
  - `src/passes/simplify_locals.mbt`
    - declares `simplify_locals_notee_nostructure_descriptor()` for the upstream spelling
    - routes the sibling through `simplify_locals_run_with_options(..., allow_structure_rewrites=false, allow_tee=false)`
    - keeps the full pass broader: full `simplify-locals` still allows structure lifting and tee-based multi-use sinking
- current registry and behavior proof surface
  - `src/passes/registry_test.mbt`
    - checks that `simplify-locals-notee-nostructure` is active and exposes the expected descriptor name
  - `src/passes/simplify_locals_nostructure_test.mbt`
    - checks direct-pipeline acceptance for the upstream spelling
    - checks that the no-tee variant does not synthesize a `local.tee` for a multi-use local
- current backlog truth
  - `agent-todo.md`
    - tracks modern direct closeout and shared nested-rerun proof under the O4z work
    - keeps this stricter sibling distinct from `SLNS` / `simplify-locals-nostructure`

That code-and-doc map is the main practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for this sibling is deliberately limited but executable.

### 1. The upstream spelling is active

`src/passes/optimize.mbt` registers `simplify-locals-notee-nostructure` as a hot pass.
That means direct CLI / harness requests use the exact Binaryen spelling seen in the saved `-O4z` audit.

The old local spelling `simplify-locals-no-tee-no-structure` is intentionally not the newly active surface. If compatibility for that spelling is needed later, add it explicitly and document it as an alias.

### 2. The dispatcher runs a stricter locals policy mode

`src/passes/pass_manager.mbt` dispatches the pass to `simplify_locals_notee_nostructure_run(ctx, func)`.
That runner calls the shared locals engine with structure synthesis disabled and fresh tee creation disabled.

### 3. The active `simplify-locals` implementation is still broader

The full `simplify-locals` pass remains broader because it can use structure rewrites and tee-based multi-use sinking.
The no-tee/no-structure sibling must continue to preserve these distinctions:

- no fresh `local.tee` creation for multi-use locals
- no block / `if` / loop result-structure synthesis
- ordinary single-use sinks into existing nested consumers remain allowed

### 4. The aggressive pipeline role is scheduled

Binaryen uses this sibling in the `-O4` / aggressive prelude after `flatten` and before `local-cse`. Starshine now schedules that exact trio in both public presets and protects the prefix order in `src/passes/registry_test.mbt`.

The remaining scheduler work is not this top-level slot; it is proving one shared final function-prelude expansion through optimizing nested reruns. Neighbor dossiers remain:

- [`../flatten/index.md`](../flatten/index.md)
- [`../local-cse/index.md`](../local-cse/index.md)

## The current Starshine implementation shape

The local implementation is an **aggressive HOT local-traffic cleanup policy mode** rather than a separate unrelated rewrite family.

It currently preserves:

- exact upstream first-slice policy gates: no fresh tees, no structure synthesis, ordinary nesting still allowed
- direct single-use sinks into existing consumers through the shared scan/sinkable machinery
- existing dead-overwrite and final dead-set cleanup from the shared locals engine
- conservative effect ordering and local read/write conflicts inherited from the shared pass
- scheduler honesty: direct pass only until the aggressive-only `flatten -> sibling -> local-cse` neighborhood is available

## Distinctions future work must keep explicit

### Not `simplify-locals-nostructure`

[`../simplify-locals-nostructure/index.md`](../simplify-locals-nostructure/index.md) covers a different upstream policy: `SimplifyLocals<true, false, true>`.
That sibling permits fresh tees.
This one does not.

### Not `simplify-locals-nonesting`

[`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md) covers the stricter flatness-preserving sibling: `SimplifyLocals<false, false, false>`.
This pass keeps `allowNesting = true`, so it may still sink single-use values into already-existing consumers.

### Not full `simplify-locals`

[`../simplify-locals/index.md`](../simplify-locals/index.md) covers the active full Starshine pass and upstream `SimplifyLocals<true, true, true>`.
Full local cleanup may build block / `if` / loop result structure; this sibling must not.

## Validation evidence and remaining scope

The direct-pass slice is historically green at the focused and oracle-comparison levels, and the top-level aggressive neighborhood is now scheduled:

1. focused local tests cover registry and exact upstream spelling, direct-pipeline acceptance, single-use sinking, no fresh tee for multi-use locals, and the Binaryen const+nop loop parity shape;
2. `.tmp/pass-fuzz-simplify-locals-notee-nostructure` refreshed the mixed-generator direct lane on 2026-05-06 with `6759/10000` comparable cases, `6759` matches, `0` mismatches, `17` Binaryen empty-recursion-group parser command failures, and `3` other Binaryen/tool command failures;
3. `.tmp/pass-fuzz-slnns-smith-10000-after-local` reached `8983/8983` comparable `wasm-smith` matches with `0` mismatches and `0` validation failures;
4. `.tmp/pass-fuzz-slnns-genvalid-1000-fixed` reached `1000/1000` comparable `gen-valid` matches with `0` mismatches, `0` validation failures, and `0` command failures;
5. `.tmp/pass-fuzz-slnns-10000-after-genvalid-fix` reached `9496/9496` comparable mixed-generator matches with `0` mismatches and `0` validation failures;
6. `.tmp/self-opt-slnns-after-local-bin128` passed normalized-WAT and canonical-function equality against Binaryen 128 for `tests/node/dist/starshine-debug-wasi.wasm`.

Remaining scope is modern direct-pass and nested-rerun qualification:

- refresh the SLNNS-specific v130/four-lane closeout evidence;
- replay the now-scheduled `flatten -> simplify-locals-notee-nostructure -> local-cse` cluster as a dedicated composition lane;
- prove shared aggressive rerun surfaces when optimizing passes call the final function pipeline;
- replay the generated-artifact `-O4z` path after the remaining scheduler substitutions are closed.

That work is tracked by `[O4Z-SLNNS]001` and `[O4Z-NESTED]001`; it does not reopen the completed top-level scheduling step.

## Bottom line

Current Starshine `simplify-locals-notee-nostructure` strategy is active direct execution plus exact top-level aggressive-prelude placement:

- the exact upstream spelling is registered locally today;
- the CLI and dispatcher can run it as a direct hot pass;
- the shared locals engine has the needed no-tee/no-structure policy gates;
- both public presets schedule it immediately after `flatten` and before `local-cse`;
- the active full `simplify-locals` HOT pass remains a broader sibling, not this pass;
- modern direct closeout and shared nested-rerun proof remain open.

So the right mental model today is:

- **active direct and top-level scheduled sibling**
- **no fresh tees**
- **no structure synthesis**
- **clear upstream spelling**
- **nested aggressive replay still to prove**

## Sources

- [research note 0554](./index.md)
- [research note 0544](./index.md)
- [research note 0333](./index.md)
- [research note 0489](./index.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
