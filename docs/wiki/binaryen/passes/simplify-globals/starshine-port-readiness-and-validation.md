---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-simplify-globals-current-main-recheck.md
  - ../../../raw/research/0461-2026-05-05-simplify-globals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md
  - ../../../raw/research/0275-2026-04-23-simplify-globals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_region_edit.mbt
  - ../../../../../src/ir/hot_query.mbt
  - ../../../../../src/ir/hot_side_tables.mbt
  - ../../../../../src/ir/hot_labels.mbt
  - ../../../../../src/ir/hot_verify.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./plain-vs-optimizing-and-safety.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals-optimizing/index.md
  - ../propagate-globals-globally/index.md
  - ../duplicate-import-elimination/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
  - ../directize/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine port readiness and validation for `simplify-globals`

Use this page after the source-contract pages:

- [`./binaryen-strategy.md`](./binaryen-strategy.md) explains what Binaryen does.
- [`./wat-shapes.md`](./wat-shapes.md) shows the important transformed shapes.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) maps the upstream owner and shipped tests.
- [`./plain-vs-optimizing-and-safety.md`](./plain-vs-optimizing-and-safety.md) isolates the plain-versus-optimizing split and the safety rules.
- [`./starshine-strategy.md`](./starshine-strategy.md) records current local status.

This page answers the next practical question: if Starshine implements the plain pass later, what is the safest first slice and how should it be validated?

## Current port-readiness summary

`simplify-globals` is **not implemented** in Starshine today.
The useful local status is:

| Surface | Current state | Code / doc anchor |
| --- | --- | --- |
| Public pass name | active module pass | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), [`0699`](../../../raw/research/0699-2026-05-26-sgo-shared-family-exposure.md) |
| Active request behavior | runs the shared SGO core without optimizing nested cleanup | [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) |
| Active presets | local `optimize` / `shrink` use the optimizing sibling in the late Binaryen post-pass tail | [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md#L35-L41`](../../no-dwarf-default-optimize-path.md#L35-L41) |
| Backlog | only the optimizing sibling has a dedicated slice today | [`agent-todo.md#L176-L182`](../../../../../agent-todo.md#L176-L182) |
| Canonical placement | late global cleanup, before the module cleanup tail | [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) |

That means the wiki should continue to teach the pass as a future boundary/module port, not as a HOT peephole already hiding in the local pass manager.

## Minimum viable Starshine slice

A source-faithful first slice should preserve Binaryen's plain-pass contract:

1. **Fact table first**
   - collect imported/exported/read/written/non-init-written/read-only-to-write facts per global;
   - scan function bodies plus module-level initializer and offset expressions;
   - keep this module-owned, not HOT-region-owned.
2. **Startup-only propagation**
   - replace known constant `global.get`s in later global initializers, element offsets, and data offsets;
   - keep this separate from runtime code propagation because startup order is the proof.
3. **Dead or redundant write repair**
   - rewrite removable `global.set $g value` as `drop(value)`;
   - preserve operand evaluation and mark the containing function as changed.
4. **Runtime trace propagation**
   - replace global reads only while the current linear-execution story is still simple;
   - clear current facts around calls, nonlinear control, and writes to tracked globals.
5. **Type repair**
   - if a substitution becomes more refined than the original expression type, refinalize before continuing.

The plain pass should stop there. Do **not** add the optimizing sibling's nested default-function rerun to the plain port.

## Transformed-shape coverage to preserve

The first tests should be organized around the shape catalog in [`./wat-shapes.md`](./wat-shapes.md):

| Shape family | First Starshine proof |
| --- | --- |
| Single-use global initializer folding | one global initializer copied into a later initializer; function-use and multi-use negatives remain unchanged |
| Startup propagation | later global / data / elem offsets see earlier constants; imported/exported boundaries remain conservative |
| Dead writes | never-read or same-as-init writes become `drop(value)` rather than disappearing |
| `read-only-to-write` | exact self-guard positives, nested positives, and actual-node / effect / value-flow negatives |
| Runtime propagation | same-linear-trace positives, call and nonlinear-control barriers |
| Type-changing replacements | substitutions that need type repair are either refinalized correctly or kept as explicit non-goals |

The shape tests should stay readable enough for beginners, then add advanced stress cases for GC refs, segment offsets, side effects inside conditions, and nested self-guards.

## Validation ladder

Use this validation order when implementation starts.

### 1. Registry and request behavior

Before the pass is implemented, existing behavior should remain:

- `simplify-globals` is an active module pass;
- explicit active requests run the shared core and skip optimizing nested cleanup;
- presets use `simplify-globals-optimizing`, not the plain sibling.

When the implementation lands, update the registry classification and add the classification-change test in the same commit.

### 2. Shared-engine shape tests

Add source-shaped tests beside the implementing module for:

- global fact collection,
- startup propagation,
- write-to-drop repair,
- runtime trace propagation,
- bailout preservation.

These tests prove the shared global algorithm. They do not prove any future optimizing wrapper by themselves.

### 3. Boundary-module scheduler tests

Add separate tests for:

- exact touched-function set construction if the implementation records it,
- no nested default-function rerun on the plain pass,
- no accidental `precompute-propagate` prefix,
- validation/writeback after type-changing replacements.

### 4. Binaryen oracle comparison

Run isolated oracle comparison before late-tail replay:

- `bun scripts/pass-fuzz-compare.ts --pass simplify-globals ...`
- reduced fixtures from Binaryen's `simplify-globals-*` lit family;
- targeted debug-artifact runs once the boundary harness accepts the pass.

If mismatches are caused by a known subset, record that subset explicitly on the Starshine strategy page.

### 5. Late-tail neighborhood replay

Only after neighboring skipped passes stop masking the output, replay the late cluster:

1. `duplicate-import-elimination`
2. `simplify-globals`
3. `simplify-globals-optimizing`
4. `remove-unused-module-elements`
5. `string-gathering`
6. `reorder-globals`
7. `directize`

That order matters because `simplify-globals` can expose dead globals for later cleanup and can alter the global/module surface seen by the later string and layout passes.

## Code surfaces a future implementation will probably need

The exact owner file is still undecided, but a faithful port needs these categories rather than only HOT helpers:

| Need | Why |
| --- | --- |
| Module-level global table | The pass reasons about imported/exported/read/written globals across the whole module. |
| Module-code walker | Global initializers and segment offsets are part of the pass contract. |
| Function-body mutation tracker | The plain pass still needs to know which function bodies changed. |
| Effect / side-effect classifier | `read-only-to-write` and runtime propagation both depend on conservative barriers. |
| Expression copier / replacement helper | Single-use init folding and constant propagation copy expressions into new sites. |
| Type repair / validation path | GC and `ref.func` replacements can refine expression types. |
| Boundary-module scheduler | The plain pass should stay in the late module/global phase, not the HOT pipeline. |

If a future port implements only startup propagation or only dead-write cleanup, keep `simplify-globals` marked as partial until the runtime and type-repair pieces exist too.

## Open design questions

- Should Starshine land a shared `simplify-globals` / `simplify-globals-optimizing` owner first, or a narrower startup-only `propagate-globals-globally` substrate first?
- Should touched-function tracking be stored now, even though plain `simplify-globals` does not need nested reruns?
- How should local type repair represent Binaryen's `ReFinalize()` obligations for reference-typed replacements?
- Should global fact collection reuse broader module-analysis caches or stay pass-local until another global-family pass needs it?

Record the answer in this page and [`./starshine-strategy.md`](./starshine-strategy.md) when implementation work decides any of these.

## Sources

- [`../../../raw/binaryen/2026-05-05-simplify-globals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-simplify-globals-current-main-recheck.md)
- [`../../../raw/research/0461-2026-05-05-simplify-globals-current-main-recheck.md`](../../../raw/research/0461-2026-05-05-simplify-globals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md`](../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md)
- [`../../../raw/research/0275-2026-04-23-simplify-globals-primary-sources-and-starshine-followup.md`](../../../raw/research/0275-2026-04-23-simplify-globals-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt)
- [`../../../../../src/ir/hot_region_edit.mbt`](../../../../../src/ir/hot_region_edit.mbt)
- [`../../../../../src/ir/hot_query.mbt`](../../../../../src/ir/hot_query.mbt)
- [`../../../../../src/ir/hot_side_tables.mbt`](../../../../../src/ir/hot_side_tables.mbt)
- [`../../../../../src/ir/hot_labels.mbt`](../../../../../src/ir/hot_labels.mbt)
- [`../../../../../src/ir/hot_verify.mbt`](../../../../../src/ir/hot_verify.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
