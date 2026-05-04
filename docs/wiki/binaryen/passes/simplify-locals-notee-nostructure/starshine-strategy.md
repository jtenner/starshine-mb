---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md
  - ../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md
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

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md) and the companion [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) bridge.
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas and validation lanes a future port would have to hook into.

## The honest current status

`simplify-locals-notee-nostructure` is still **unimplemented** in Starshine.
There is no `src/passes/simplify_locals_notee_nostructure.mbt` owner file today.

The current local strategy is registry and port planning:

- keep the local removed-name spelling tracked
- keep the upstream-vs-local spelling split explicit
- keep the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` role documented
- teach the active full `simplify-locals` files as the likely future policy-mode landing zone, without pretending they already implement this sibling

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - `src/passes/optimize.mbt`
    - `pass_registry_removed_names()` includes the local alias `"simplify-locals-no-tee-no-structure"`
    - the exact upstream spelling `"simplify-locals-notee-nostructure"` is not itself registered locally
    - the active `optimize` and `shrink` presets include full `"simplify-locals"`, but not the no-tee/no-structure sibling
- CLI pipeline rejection for removed / inactive names
  - `src/cmd/cmd.mbt`
    - the pipeline parser accepts only `HotPass`, `ModulePass`, or `Preset` categories
    - removed names therefore surface as `unknown pass flag` to CLI users instead of executing silently
- active hot-pass dispatcher
  - `src/passes/pass_manager.mbt`
    - dispatches only `"simplify-locals" => simplify_locals_run(ctx, func)` for the locals family
    - has no case for `"simplify-locals-no-tee-no-structure"` or upstream `"simplify-locals-notee-nostructure"`
- current active full locals owner
  - `src/passes/simplify_locals.mbt`
    - `simplify_locals_descriptor()` declares only the full `"simplify-locals"` hot pass
    - `simplify_locals_summary()` explicitly includes structure lifting and dead local writes, which is broader than the no-tee/no-structure sibling
    - helper surfaces such as `simplify_locals_new_sinkables(...)`, `simplify_locals_effects_ordered_before(...)`, and the block / branch return candidate helpers are useful future building blocks, but there is no `allowTee` / `allowStructure` / `allowNesting` policy parameter today
- current registry proof surface
  - `src/passes/registry_test.mbt`
    - the registry test already exercises active vs boundary-only vs removed categories, though it does not yet isolate this sibling alias
- current backlog truth
  - `agent-todo.md`
    - has `SLNS` for `simplify-locals-nostructure`, not for this stricter `simplify-locals-notee-nostructure` sibling
    - has no dedicated no-tee/no-structure slice today

That code-and-doc map is the main practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for this sibling is deliberately limited.

### 1. The local alias is tracked, not forgotten

`src/passes/optimize.mbt` keeps `simplify-locals-no-tee-no-structure` in `pass_registry_removed_names()`.
That means:

- the project still treats the upstream pass as a real known missing pass
- the local compatibility spelling is preserved in the registry surface
- the pass remains visible in tracker work instead of silently falling out of planning

The local alias should not be confused with the exact upstream spelling.
A future implementation should either register both names explicitly or document why only one spelling is accepted.

### 2. The CLI does not execute it accidentally

`src/cmd/cmd.mbt` accepts only active hot-pass, module-pass, and preset categories as pipeline steps.
Removed names do not pass that filter.
So a user request for the local removed alias is rejected rather than treated as a no-op optimization.

That is the right current behavior for an unimplemented pass: known to the registry, not runnable as a transform.

### 3. The active `simplify-locals` implementation is related but broader

`src/passes/simplify_locals.mbt` already implements a full local cleanup pass in HOT form.
It can sink locals, reason about effects, lift structure when safe, canonicalize copies, and remove dead writes.

That is useful future infrastructure, but it is not the no-tee/no-structure sibling because the active pass is intentionally broader:

- it does not expose upstream's `allowTee` policy bit
- it does not expose upstream's `allowStructure` policy bit
- it does not expose upstream's `allowNesting` policy bit
- its public summary includes structure lifting, which this sibling must disable

So the active implementation should be read as a future landing zone, not as current parity.

### 4. The aggressive pipeline role is only documented, not implemented

Binaryen uses this sibling in the `-O4` / aggressive prelude after `flatten` and before `local-cse`.
Starshine currently has dossiers for both neighbors:

- [`../flatten/index.md`](../flatten/index.md)
- [`../local-cse/index.md`](../local-cse/index.md)

But the local pass itself has no dispatcher case, no owner file, and no active backlog slice.
That means Starshine cannot yet claim the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood even if neighboring documentation exists.

## The right future Starshine implementation shape

A faithful port should be taught as an **aggressive HOT local-traffic cleanup policy mode** rather than as a separate unrelated rewrite family.

The likely implementation options are:

1. extend `src/passes/simplify_locals.mbt` with explicit policy flags mirroring Binaryen's `allowTee`, `allowStructure`, and `allowNesting`, or
2. create a small sibling owner file that reuses the active full-pass helpers but hard-codes the stricter policy.

Either way, the faithful behavior must preserve:

- exact upstream policy: no fresh tees, no structure synthesis, ordinary nesting still allowed
- direct single-use sinks into existing consumers
- dead-overwrite and final dead-set cleanup
- late equivalent-get canonicalization
- conservative effect ordering and local read/write conflicts
- explicit `try` / `try_table` throwing-value barriers
- refinalization or equivalent HOT-lower/type-repair when a replacement exposes a refined type
- scheduler honesty around the aggressive-only `flatten -> sibling -> local-cse` slot

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

## Validation plan for an eventual port

A future real implementation should validate in this order:

1. registry and spelling tests
   - local alias classification
   - exact upstream spelling decision
   - CLI rejection before implementation and CLI acceptance after implementation
2. reduced positive shape tests
   - direct single-use sink into an existing consumer
   - dead-overwrite cleanup with effect preservation
   - late equivalent-get canonicalization
   - final dead-set cleanup
3. reduced negative shape tests
   - no fresh tee for multi-use locals
   - no block / `if` / loop result-structure synthesis
   - no claim of full flatness preservation
   - no motion across effect, trap, memory/table/global, local-conflict, or EH catch-boundary hazards
4. cluster tests
   - `flatten -> simplify-locals-notee-nostructure -> local-cse`
   - nested aggressive rerun surfaces when optimizing passes call the default function pipeline
5. oracle comparison
   - pass-targeted Binaryen parity with the exact upstream spelling
   - generated-artifact `-O4z` replay only after `flatten` and `local-cse` neighboring constraints are representable locally

## Bottom line

Current Starshine `simplify-locals-notee-nostructure` strategy is honest removed-name tracking plus future policy-mode planning:

- the local alias exists as `simplify-locals-no-tee-no-structure`
- the exact upstream spelling is not registered locally today
- the CLI and dispatcher do not run it
- the active full `simplify-locals` HOT pass is a related but broader landing zone
- no dedicated backlog slice exists yet
- the pass's aggressive post-`flatten` role must remain distinct from the ordinary no-DWARF `simplify-locals-nostructure` slot and from the flatness-preserving `simplify-locals-nonesting` sibling

So the right mental model today is:

- **known missing sibling**
- **no transform yet**
- **clear upstream contract**
- **clear local alias caveat**
- **clear future landing zone inside or beside the active full locals pass**

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md)
- [`../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
