---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
  - ../duplicate-import-elimination/index.md
  - ../remove-unused-module-elements/index.md
  - ../string-gathering/index.md
  - ../reorder-globals/index.md
  - ../directize/index.md
---

# Starshine strategy for `simplify-globals-optimizing`

Use this page with the raw primary-source manifests in [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md) and [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md).
The purpose here is to map the reviewed Binaryen contract to the exact current Starshine status and the concrete local surfaces a future port should start from. The implementation-readiness and validation ladder now live in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Honest current status

`simplify-globals-optimizing` is still **unimplemented** in Starshine.
There is no `src/passes/simplify_globals_optimizing.mbt`, no shared local `simplify_globals.mbt` owner file, and no boundary scheduler that performs this pass's nested default-function rerun today.

The current local strategy is therefore a status-and-port map:

- keep the public pass spelling tracked in the registry,
- classify it as boundary-only rather than HOT-local,
- reject explicit user requests honestly,
- keep the canonical late-post-pass slot visible,
- keep the `SGO` backlog split visible,
- keep the sibling relation to plain `simplify-globals` and `propagate-globals-globally` explicit,
- do not imply that the current `optimize` / `shrink` preset already models this late Binaryen boundary pass.

## Exact local code map today

The fast read-along path is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L141`](../../../../../src/passes/optimize.mbt#L127-L141)
    - `pass_registry_boundary_only_names()` includes `"simplify-globals-optimizing"`
- active request guard
  - [`src/passes/optimize.mbt#L448-L466`](../../../../../src/passes/optimize.mbt#L448-L466)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- current preset gap
  - [`src/passes/optimize.mbt#L248-L270`](../../../../../src/passes/optimize.mbt#L248-L270)
    - local `optimize` / `shrink` presets currently expand only to implemented active hot/module passes and stop before the late Binaryen post-pass tail that contains `simplify-globals-optimizing`
- registry coverage tests
  - [`src/passes/registry_test.mbt#L1-L66`](../../../../../src/passes/registry_test.mbt#L1-L66)
    - the registry tests prove active and removed classifications, but do not yet isolate an assertion for `simplify-globals-optimizing`
- boundary-only request behavior through a caller surface
  - [`src/cmd/fuzz_harness_wbtest.mbt#L206-L216`](../../../../../src/cmd/fuzz_harness_wbtest.mbt#L206-L216)
    - existing coverage proves the boundary-only rejection path using `global-struct-inference-desc-cast`; a future `SGO` port should add or update targeted pass-request tests when the classification changes
- canonical Binaryen placement
  - [`../../no-dwarf-default-optimize-path.md#L35-L48`](../../no-dwarf-default-optimize-path.md#L35-L48)
    - the no-DWARF late post-pass phase places `simplify-globals-optimizing` after `duplicate-import-elimination` and before `remove-unused-module-elements`; the nested rerun rule records that this sibling reruns default function passes without the `precompute-propagate` prefix
- backlog slice
  - [`../../../../../agent-todo.md#L546-L561`](../../../../../agent-todo.md#L546-L561)
    - `SGO` is split into constant-global / mutation tracking and nested default-function rerun work

## What Starshine currently does for this pass name

### 1. The name is known but boundary-only

`src/passes/optimize.mbt` keeps `simplify-globals-optimizing` in the boundary-only registry list.
That is the correct current classification because Binaryen's pass needs module-wide global facts, startup-order rewrites, function-body substitutions, and an optimizer rerun over changed functions.
Those are not expressible as a small HOT peephole pass in the current local pipeline.

### 2. Explicit requests fail instead of silently no-oping

The same file's expansion path rejects boundary-only passes with a specific error.
For this pass, that protects users from thinking a late global cleanup happened when it did not.
It also keeps the local preset honest: until the boundary implementation exists, `optimize` and `shrink` cannot pretend to replay the full Binaryen no-DWARF tail.

### 3. The backlog already names the two necessary halves

`agent-todo.md` keeps `SGO` split into:

- constant-global rewrite and mutation tracking, and
- nested default-function rerun / artifact comparison.

That split matches the reviewed upstream contract.
A future implementation that lands only global substitutions but not touched-function tracking and nested reruns should be documented as a partial subset, not as full `simplify-globals-optimizing` parity.

## Starshine implementation shape to preserve

A future local port should be planned as a boundary/module family, probably sharing machinery with plain `simplify-globals` and possibly a startup-only subset.
The minimum shape is:

1. collect module-wide global traffic facts across function bodies and module-level code,
2. fold single-use global initializers only into later global initializers,
3. preserve operand evaluation when erasing useless writes by rewriting `global.set value` to `drop(value)`,
4. implement the actual-node and effect/value-flow legality checks for `read-only-to-write`,
5. canonicalize immutable copy chains only where the use type remains legal,
6. distinguish startup propagation from runtime trace propagation,
7. record exactly which functions changed,
8. rerun the default function optimization pipeline on changed functions,
9. avoid prepending `precompute-propagate` in this nested rerun,
10. re-run validation and Binaryen comparison on both isolated pass tests and the late post-pass neighborhood.

The most likely local landing point is **not** the existing HOT pass manager alone.
The pass must eventually compose with boundary/module scheduling next to `duplicate-import-elimination`, `remove-unused-module-elements`, `string-gathering`, `reorder-globals`, and `directize`. For a concrete first-slice and validation plan, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Mapping to neighboring dossiers

| Neighbor | Relationship to `simplify-globals-optimizing` |
| --- | --- |
| [`../simplify-globals/index.md`](../simplify-globals/index.md) | Shared Binaryen engine without the optimizing nested rerun. Any local implementation should keep this public-contract split explicit. |
| [`../propagate-globals-globally/index.md`](../propagate-globals-globally/index.md) | Startup-only shared-engine subset. Useful as a staging candidate, but smaller than full `simplify-globals-optimizing`. |
| [`../dae-optimizing/index.md`](../dae-optimizing/index.md) | Another optimizing late pass, but its nested cleanup helper prepends `precompute-propagate`; do not copy that exact rerun shape for `SGO`. |
| [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md) | Same warning as DAE: optimizing sibling, different nested-rerun helper story. |
| [`../duplicate-import-elimination/index.md`](../duplicate-import-elimination/index.md) | Immediate late-post-pass predecessor in the no-DWARF path. |
| [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md) | Immediate late-post-pass successor; should consume globals and elements made dead by `SGO`. |
| [`../string-gathering/index.md`](../string-gathering/index.md) | Later global/string boundary pass; depends on the late-tail ordering staying honest. |
| [`../reorder-globals/index.md`](../reorder-globals/index.md) | Later layout pass; should see the post-`SGO` global set. |
| [`../directize/index.md`](../directize/index.md) | Final late-tail indirect-call cleanup neighbor. |

## What Starshine does not have yet

Do not infer hidden local support from the registry entry.
Starshine still lacks:

- an owner file for the shared global simplification family,
- global-use fact tables for this pass family,
- startup initializer and offset propagation for this pass family,
- runtime global-value trace propagation for this pass family,
- `read-only-to-write` structural matching,
- changed-function tracking for global substitutions and erased writes,
- nested default-function rerun scheduling for `SGO`,
- isolated local regression tests for `--simplify-globals-optimizing`,
- debug-artifact Binaryen parity evidence for the isolated pass.

## Validation plan for the eventual port

When implementation begins, validate in this order:

1. source-shape tests for shared global rewrites:
   - single-use global initializer folding,
   - same-as-init and dead writes becoming `drop(value)`,
   - `read-only-to-write` positives and negatives,
   - immutable-copy-chain replacement,
   - startup propagation into later globals and offsets,
   - runtime trace propagation with call/control barriers;
2. scheduler tests:
   - changed functions are tracked exactly,
   - nested default function cleanup runs only where needed,
   - no `precompute-propagate` prefix is inserted for `SGO`;
3. boundary behavior tests:
   - boundary-only rejection disappears only when a real implementation exists,
   - `optimize` / `shrink` preset expansion changes only when the late-tail gap is intentionally closed;
4. oracle comparison:
   - compare `--simplify-globals-optimizing` against Binaryen on reduced fixtures,
   - replay the MoonBit debug artifact late-tail neighborhood once neighboring skipped passes are available.

## Bottom line

Current Starshine `simplify-globals-optimizing` strategy is honest boundary-only tracking plus an explicit future-port map.
The pass should stay documented as unimplemented until Starshine has both the shared global rewrite engine and the optimizing-specific changed-function default-rerun behavior.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/fuzz_harness_wbtest.mbt`](../../../../../src/cmd/fuzz_harness_wbtest.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
