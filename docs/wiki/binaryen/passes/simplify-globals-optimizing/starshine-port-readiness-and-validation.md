---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
  - ../duplicate-import-elimination/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
  - ../directize/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine port readiness and validation for `simplify-globals-optimizing`

Use this page after the source contract pages:

- [`./binaryen-strategy.md`](./binaryen-strategy.md) explains what Binaryen does.
- [`./wat-shapes.md`](./wat-shapes.md) shows the important transformed shapes.
- [`./starshine-strategy.md`](./starshine-strategy.md) records current local status.

This page answers the next practical question: if Starshine implements this boundary pass later, what is the safest first slice and how should it be validated?

## Current port-readiness summary

`simplify-globals-optimizing` is **not implemented** in Starshine today.
The useful local status is:

| Surface | Current state | Code / doc anchor |
| --- | --- | --- |
| Public pass name | known as boundary-only | [`src/passes/optimize.mbt#L127-L141`](../../../../../src/passes/optimize.mbt#L127-L141) |
| Active request behavior | rejected honestly as boundary-only | [`src/passes/optimize.mbt#L448-L466`](../../../../../src/passes/optimize.mbt#L448-L466) |
| Active presets | local `optimize` / `shrink` stop before the late Binaryen post-pass tail | [`src/passes/optimize.mbt#L248-L270`](../../../../../src/passes/optimize.mbt#L248-L270) |
| Backlog | split into global rewrite / mutation tracking plus nested rerun | [`agent-todo.md#L546-L561`](../../../../../agent-todo.md#L546-L561) |
| Canonical placement | after `duplicate-import-elimination`, before `remove-unused-module-elements` | [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) |

That means the wiki should continue to teach the pass as a future boundary/module port, not as a HOT peephole already hiding in the local pass manager.

## Minimum viable Starshine slice

A source-faithful first slice should preserve Binaryen's two identities:

1. shared global-simplification algorithm, and
2. optimizing wrapper that reruns ordinary function cleanup on exactly the changed functions.

A practical local landing order is:

1. **Fact table first**
   - collect imported/exported/read/written/non-init-written/read-only-to-write facts per global;
   - scan function bodies and module-level initializer / segment-offset expressions;
   - keep this module-owned, not HOT-region-owned.
2. **Startup-only propagation**
   - replace known earlier constant `global.get`s in later global initializers, element offsets, and data offsets;
   - keep this separate from runtime code propagation because startup order is the proof.
3. **Dead or redundant write repair**
   - rewrite removable `global.set $g value` as `drop(value)`;
   - preserve operand evaluation and mark the containing function as changed.
4. **Small immutable-copy canonicalization**
   - chase immutable global-copy chains only when the replacement type is exactly valid at the use;
   - leave subtype/refinalization extensions for later unless deliberately documented.
5. **Runtime trace propagation**
   - replace global reads only while the current linear execution story is still simple;
   - clear current facts around calls, nonlinear control, and writes to tracked globals.
6. **Optimizing wrapper**
   - carry the exact touched-function set from replacement/removal phases;
   - rerun Starshine's default function cleanup on those functions only;
   - do **not** prepend `precompute-propagate`, unlike the nearby DAE/inlining optimizing siblings.

The first useful local implementation may intentionally skip some shapes, but it should name itself as a subset until the fact collection, rewrite, and nested-rerun pieces all exist.

## Transformed-shape coverage to preserve

The first tests should be organized around the shape catalog in [`./wat-shapes.md`](./wat-shapes.md):

| Shape family | First Starshine proof |
| --- | --- |
| Single-use global initializer folding | one global initializer copied into a later initializer; function-use and multi-use negatives remain unchanged |
| Startup propagation | later global / data / elem offsets see earlier constants; imported/exported boundaries remain conservative |
| Dead writes | never-read or same-as-init writes become `drop(value)` rather than disappearing |
| `read-only-to-write` | exact self-guard positives, nested positives, and actual-node / effect / value-flow negatives |
| Immutable-copy chain | compatible ancestor rewrites, exact-type mismatch negatives |
| Runtime propagation | same-linear-trace positives, call and nonlinear-control barriers |
| Type-changing replacements | replacements that require type repair are either refinalized correctly or kept as explicit non-goals |
| Optimizing wrapper | touched functions receive ordinary cleanup; untouched functions do not |

The shape tests should stay readable enough for beginners, then add advanced stress cases for GC refs, segment offsets, side effects inside conditions, and nested self-guards.

## Validation ladder

Use this validation order when implementation starts.

### 1. Registry and request behavior

Before the pass is implemented, existing behavior should remain:

- `simplify-globals-optimizing` is boundary-only;
- explicit active requests fail with the boundary-only error;
- presets do not silently include it.

When the implementation lands, update the registry classification and add the classification-change test in the same commit.

### 2. Shared-engine shape tests

Add source-shaped tests beside the implementing module for:

- global fact collection,
- startup propagation,
- write-to-drop repair,
- copy-chain canonicalization,
- runtime trace propagation,
- bailout preservation.

These tests prove the shared global algorithm. They do not prove the optimizing wrapper by themselves.

### 3. Optimizing-wrapper scheduler tests

Add separate tests for:

- exact touched-function set construction,
- nested default-function cleanup on changed functions,
- no nested rerun on unchanged functions,
- no extra `precompute-propagate` prefix,
- validation/writeback after type-changing replacements.

This is the main behavior that distinguishes `simplify-globals-optimizing` from plain [`../simplify-globals/index.md`](../simplify-globals/index.md).

### 4. Binaryen oracle comparison

Run isolated oracle comparison before late-tail replay:

- `bun scripts/pass-fuzz-compare.ts --pass simplify-globals-optimizing ...`
- reduced fixtures from Binaryen's `simplify-globals-*` lit family;
- targeted debug-artifact runs once the module-boundary harness accepts the pass.

If mismatches are caused by a known subset, record that subset explicitly on the Starshine strategy page.

### 5. Late-tail neighborhood replay

Only after neighboring skipped passes stop masking the output, replay the late cluster:

1. `duplicate-import-elimination`
2. `simplify-globals-optimizing`
3. `remove-unused-module-elements`
4. `string-gathering`
5. `reorder-globals`
6. `directize`

That order matters because `SGO` can expose dead globals for RUME and can alter the global/module surface seen by the later string and layout passes.

## Code surfaces a future implementation will probably need

The exact owner file is still undecided, but a faithful port needs these categories rather than only HOT helpers:

| Need | Why |
| --- | --- |
| Module-level global table | The pass reasons about imported/exported/read/written globals across the whole module. |
| Module-code walker | Global initializers and segment offsets are part of the pass contract. |
| Function-body mutation tracker | The optimizing wrapper must know exactly which functions changed. |
| Effect / side-effect classifier | `read-only-to-write` and runtime propagation both depend on conservative barriers. |
| Expression copier / replacement helper | Single-use init folding and constant propagation copy expressions into new sites. |
| Type repair / validation path | GC and `ref.func` replacements can refine expression types. |
| Nested function-pass scheduler | The optimizing sibling requires per-changed-function default cleanup without the DAE/inlining prefix. |

If a future port implements only startup propagation or only dead-write cleanup, keep `simplify-globals-optimizing` marked as partial until the nested rerun contract exists too.

## Open design questions

- Should Starshine land a shared `simplify-globals` / `simplify-globals-optimizing` owner first, or a narrower startup-only `propagate-globals-globally` substrate first?
- Should touched-function cleanup reuse the existing active preset list exactly, or define a smaller Binaryen-equivalent default-function subset for nested runs?
- How should local type repair represent Binaryen's `ReFinalize()` obligations for reference-typed replacements?
- Should global fact collection reuse broader module-analysis caches or stay pass-local until another global-family pass needs it?

Record the answer in this page and [`./starshine-strategy.md`](./starshine-strategy.md) when implementation work decides any of these.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
