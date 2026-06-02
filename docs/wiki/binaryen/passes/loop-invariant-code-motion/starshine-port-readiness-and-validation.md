---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md
  - ../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md
  - ../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md
  - ../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../raw/research/0065-2026-03-24-ir2-execution-plan.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./effects-loops-and-hoisting-rules.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../local-subtyping/index.md
  - ../flatten/index.md
  - ../code-pushing/index.md
  - ../local-cse/index.md
  - ../simplify-locals/index.md
---

# Starshine port-readiness and validation for `loop-invariant-code-motion`

This page turns the corrected Binaryen `licm` dossier into a local implementation-readiness map.
The 2026-06-02 current-main recheck kept the same local status and slice order described below.
It should be read after:

- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream algorithm;
- [`./effects-loops-and-hoisting-rules.md`](./effects-loops-and-hoisting-rules.md) for the hard safety proof;
- [`./wat-shapes.md`](./wat-shapes.md) for before/after examples;
- [`./starshine-strategy.md`](./starshine-strategy.md) for current in-tree status.

## Current local truth

Starshine still does **not** implement LICM.
There is no `src/passes/loop_invariant_code_motion.mbt`, no HOT descriptor, no module-pass descriptor, and no dedicated local reduced-test suite.

The exact current local behavior is removed-name bookkeeping:

| Local surface | Current fact |
| --- | --- |
| `src/passes/optimize.mbt:98-106` | `pass_registry_entry_removed(...)` constructs removed entries with category `Removed`, no descriptor, and no expansion. |
| `src/passes/optimize.mbt:144-151` | `pass_registry_removed_names()` lists `"loop-invariant-code-motion"`. |
| `src/passes/optimize.mbt:469-472` | `run_hot_pipeline_expand_passes(...)` rejects removed pass flags before dispatch. |
| `src/passes/registry_test.mbt:171-179` | The generic removed-name rejection path is tested with `de-nan`; there is no LICM-specific transform test yet. |
| `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md` | The refreshed registry map keeps `loop-invariant-code-motion` in the current removed-name gap and records `local-subtyping` as an active module pass. |
| `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md` | The refreshed execution plan treats the old batch labels as historical and says removed-pass revival should start with an explicit-pass slice before preset scheduling. |

## First design decision: pass spelling

Binaryen's public pass name is `licm`.
Starshine's preserved removed-registry name is `loop-invariant-code-motion`.

Before exposing an implementation, choose one explicit policy:

| Option | Benefit | Cost |
| --- | --- | --- |
| expose only `licm` | Matches upstream CLI spelling. | Breaks the local long-name breadcrumb unless kept as alias or migration warning. |
| expose only `loop-invariant-code-motion` | Preserves the existing local name. | Keeps a visible divergence from Binaryen users and docs. |
| expose both with one descriptor | Best compatibility and clearest transition. | Requires alias tests and catalog wording that identifies one canonical implementation. |

Until that decision lands, wiki pages must continue to say the transform is unimplemented and the local long name is removed.

## Minimum viable Starshine slice

A faithful first local slice should match the corrected Binaryen contract, not the older generic-hoisting overread.

### Phase 1: loop-entry candidate discovery

Start with one function body at a time.
For each loop:

1. identify the loop body's unconditional entrance sequence;
2. stop scanning as soon as control transfer is encountered;
3. only consider already none-typed whole statements in that prefix;
4. do not synthesize temps for value-producing expressions in this slice.

This keeps the first pass close to Binaryen's `visitLoop(...)` shape and avoids accidentally implementing a different optimizer.

### Phase 2: safety summaries

For each loop, Starshine needs conservative equivalents for Binaryen's checked hazards:

- global-state effects;
- exception effects;
- control-flow effects;
- trap sensitivity;
- mutable-state effects;
- local reads whose reaching sets are inside the loop;
- local sets whose target has another in-loop set.

Candidate local foundations are HOT loop/effects/use-def/local-SSA overlays, but this page deliberately does not choose an implementation API.
The acceptance rule is behavior-level: if the analysis cannot prove a Binaryen-equivalent safety property, the first slice should leave the statement inside the loop.

### Phase 3: rewrite and repair

For each accepted statement:

- emit the moved statement before the loop in the same observable order;
- leave a cleanup-safe placeholder such as `nop`, or use an equivalent deletion shape that preserves region ownership and validation;
- preserve later cleanup opportunities for `vacuum`, `merge-blocks`, or local simplification;
- validate after lowering, because moving traps or effectful work by mistake is a semantic bug rather than a cosmetic diff.

### Phase 4: alias and registry tests

Only after a transform exists:

- add registry tests for the chosen public spelling(s);
- add active-pipeline acceptance tests for the implemented name(s);
- retire the removed-name classification only for names that really dispatch to the new descriptor;
- keep any noncanonical alias explicit in docs and tests.

## Reduced test ladder

Write reduced tests before artifact comparison.
A practical order is:

1. **pure none-typed prefix move**
   - dropped pure computation or a safe local statement at loop entry moves before the loop;
   - the original loop slot becomes `nop` or disappears only through an equivalent validated cleanup.
2. **mixed prefix**
   - the first safe statement moves;
   - scanning stops at a control-transfer or unsafe statement;
   - later syntactically movable statements stay in place if not unconditionally reached.
3. **local dependency negatives**
   - a `local.get` depending on an in-loop `local.set` does not move;
   - a `local.set` to a local with another in-loop set does not move.
4. **effect and trap negatives**
   - stores, calls with relevant effects, may-throw operations, traps, and mutable-state changes stay in the loop.
5. **nested loops and flattened shapes**
   - start with simple nesting;
   - only expand to flatten-exposed statement families after the first direct-loop cases are green.
6. **alias / registry behavior**
   - active names run;
   - nonimplemented names keep honest diagnostics.

## Binaryen oracle comparison

After reduced tests pass, compare the first local slice with Binaryen's `--licm` on focused WAT fixtures.
Because Starshine's preserved local name differs from upstream, any harness wrapper should record both spellings explicitly:

- upstream oracle: `licm`;
- current local breadcrumb: `loop-invariant-code-motion`;
- eventual local public name: decided by the alias policy above.

This pass is outside the current open-world no-DWARF default optimize tail, so artifact replay is less urgent than for late-tail blockers like `directize` or `string-gathering`.
The right priority is correctness and alias honesty first.

## Non-goals for the first Starshine slice

Do not claim first-slice parity if the implementation does any of these without separate proof:

- arbitrary value-expression hoisting through fresh locals;
- CSE-like repeated-expression caching;
- moving statements past control transfer in the loop-entry prefix;
- moving trap-sensitive or effectful work because tests happen not to trap;
- ignoring local dependency analysis;
- relying on `flatten` being present, since `flatten` is itself still unimplemented locally.

## Health rule for future updates

When local implementation work starts, update these pages together:

- [`./starshine-strategy.md`](./starshine-strategy.md) for status and exact code locations;
- this page for slice order and validation;
- [`./wat-shapes.md`](./wat-shapes.md) for any newly supported or intentionally skipped shape;
- [`../tracker.md`](../tracker.md) and [`../index.md`](../index.md) for catalog status.

If later primary sources change Binaryen's candidate scan, effect checks, local-dependency checks, or moved-statement emission, update [`./binaryen-strategy.md`](./binaryen-strategy.md) and [`./effects-loops-and-hoisting-rules.md`](./effects-loops-and-hoisting-rules.md) in the same change.
