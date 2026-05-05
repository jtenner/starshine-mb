---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-merge-similar-functions-current-main-recheck.md
  - ../../../raw/research/0443-2026-05-05-merge-similar-functions-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md
  - ../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./profitability-indirection-and-type-barriers.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
---

# Starshine strategy for `merge-similar-functions`

## Current status

Starshine does **not** implement `merge-similar-functions` today.

The local status is:

- registry category: **removed**
- explicit CLI/pass request behavior: rejected before pass execution
- active hot owner file: **none**
- active module owner file: **none**
- active preset role: **none**
- active `agent-todo.md` slice: **none**

That makes this page a status and future-port map, not an implementation guide for existing transform code.

## Why the pass is not a HOT rewrite

Binaryen `merge-similar-functions` is a whole-module shrink pass. It must compare multiple defined functions, build a new helper function, replace original bodies with thunks, and preserve module-level names / exports / function-reference behavior.

A faithful Starshine port therefore belongs in module-pass infrastructure, not as a single-function HOT peephole. HOT IR may help analyze or rewrite individual bodies after a module-level planner has chosen a class, but HOT alone cannot choose equivalence classes across the function section or synthesize the helper/thunk module edit.

For the Binaryen side of that contract, see:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./equivalence-classes-param-derivation-and-thunk-rewrites.md`](./equivalence-classes-param-derivation-and-thunk-rewrites.md)
- [`./profitability-indirection-and-type-barriers.md`](./profitability-indirection-and-type-barriers.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Exact local code map

Starshine's current implementation evidence is negative: the pass exists only as registry/status plumbing and preset omission, not as a transform body.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt#L98-L103) defines `pass_registry_entry_removed(...)`, the shared removed-pass wrapper.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt#L128-L138) lists `merge-similar-functions` inside `pass_registry_removed_names()`.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt#L307-L312) turns removed names into registry entries.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt#L520-L524) rejects explicit requests with the removed-registry error.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt#L434-L463) omits the pass from both preset builders.

## Registry and request gating

### `src/passes/optimize.mbt`

This file is the source of truth for the current local pass status.

Relevant surfaces:

- `pass_registry_removed_names()` includes `"merge-similar-functions"`.
- `pass_registry_entries()` maps removed names through `pass_registry_entry_removed(...)`.
- Removed entries have no `HotPassDescriptor` and no module-pass owner hook.
- `run_hot_pipeline_expand_passes(...)` rejects removed requests with:
  - `pass flag {name} is removed from the active hot pipeline registry`
- `optimize_preset_passes(...)` does not include `merge-similar-functions`.
- `shrink_preset_passes(...)` also does not include `merge-similar-functions`.

The last point is important: the local `shrink` preset is not Binaryen's full `shrinkLevel >= 2` late-global schedule today. In Binaryen, `merge-similar-functions` belongs to the late global post-pass shrink path; in Starshine, the name is tracked only as an unavailable boundary.

## CLI and option surfaces

### `src/cli/cli.mbt`

The CLI parser collects long-form kebab-case pass flags into `CliParseResult.pass_flags`. There is no `merge-similar-functions` parser special case. Availability is resolved by the optimizer registry later.

### `src/cmd/cmd.mbt`

Relevant surfaces:

- `resolve_effective_pass_flags(...)` synthesizes only `"shrink"` or `"optimize"` from optimization levels when there is no explicit pass list.
- `make_optimize_options(...)` carries `shrink_level`, `monomorphize_min_benefit`, `closed_world`, low-memory options, traps policy, validation policy, and stack-function-pass controls.
- There is no `merge-similar-functions` option, planner, dispatcher hook, or helper-generation path.

So `--merge-similar-functions` can be parsed as a pass-like flag, but the registry rejects it as removed. It is not silently ignored and it is not run as part of local `--shrink`.

## Pipeline and pass-manager surfaces

### `src/passes/pass_manager.mbt`

This file owns active hot-pipeline execution and module-state support. It has reusable verification, tracing, validation, and module-context plumbing, but it does not contain a `merge-similar-functions` dispatcher case or owner implementation.

A future implementation would need either:

- a new module-pass owner file plus a module-pass dispatcher entry, or
- a shared module-rewrite framework that can add helper functions and replace existing function bodies safely.

## Representation surfaces a future port would reuse

### `src/lib/types.mbt`

This file already has many prerequisite IR-level building blocks a future port would need:

- `FuncIdx`, `TypeIdx`, and `LocalIdx`
- `CompType::FuncCompType(...)` for function signatures
- `Func`, `Code`, `Locals`, `Expr`, and `Instruction`
- imports, exports, element segments, and name-related module metadata surfaces
- direct function calls, tail-call shapes, `ref.func`, `call_ref`, and related typed-call operands

Those are representation prerequisites only. They do not implement:

- Binaryen-style function hashing,
- cross-function equivalence-class splitting,
- diff-vector derivation,
- helper synthesis,
- thunk replacement,
- local-index shifting after synthetic-param insertion, or
- size-profitability scoring.

## Planning and backlog surfaces

### `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

This older registry map lists `merge-similar-functions` in Batch 4 compatibility / boundary work. Treat that as a compatibility-tracking signal, not an active implementation plan.

### `agent-todo.md`

At the 2026-05-05 review point, there is no active `merge-similar-functions` slice. Future work should add one before implementing the pass so the required module rewrite, validation, and parity gates are explicit.

## Current request behavior

Expected behavior for a direct request:

```text
--merge-similar-functions
```

is rejection before any pass mutates the module:

```text
pass flag merge-similar-functions is removed from the active hot pipeline registry and is not implemented in the hot pipeline
```

This is the correct current behavior. It keeps the known Binaryen pass name visible without pretending Starshine implements the transformation.

## Future Starshine strategy

A faithful future port should preserve Binaryen's shape and safety contract before optimizing for local style.

### Required module-level phases

1. **Candidate scan**
   - scan defined functions only
   - reject imported functions
   - reject top-level function-type mismatches
   - reject total-local-count mismatches
2. **Hash prefilter**
   - group functions with a hash that ignores only source-backed difference sites
   - do not treat same hash as proof
3. **Equivalence-class split**
   - run exact structural comparison inside hash buckets
   - allow only literal payload and eligible direct-callee differences
4. **Diff-vector derivation**
   - walk primary and sibling bodies in lockstep expression-slot order
   - reuse one synthetic param for repeated identical per-function difference vectors
5. **Profit and limit checks**
   - reject classes that exceed the `255` synthetic-param boundary
   - keep a conservative helper-plus-thunk size-benefit check so tiny wrappers can stay unchanged
6. **Helper construction**
   - clone the primary body into a generated helper
   - keep original params first and append synthetic params
   - rewrite differing literals to `local.get`
   - rewrite eligible direct calls to `call_ref` / `return_call_ref`
   - repair non-param local indices after the signature grows
7. **Thunk replacement**
   - preserve original function names
   - forward original params plus per-function payloads
   - materialize literal payloads directly
   - materialize callee payloads with `ref.func`
   - preserve `call` versus `return_call` style where Binaryen does
8. **Validation and cleanup**
   - validate the full module after helper insertion and thunk replacement
   - keep follow-up cleanup explicit; do not hide validity fixes inside unrelated passes

### Required test families

A future Starshine implementation should add tests for at least the families in [`./wat-shapes.md`](./wat-shapes.md):

- large constant-wrapper positives
- repeated diff-vector param reuse
- original params plus shifted non-param locals
- direct-callee `ref.func` / `call_ref` positives
- tail-call-preserving positives
- tiny-function profitability bailouts
- incompatible wrapper-signature bailouts
- incompatible callee-signature bailouts
- total-local-count mismatch bailouts
- synthetic-param limit bailouts

### Validation expectations

Use the existing pass signoff rules once implementation begins:

- tests beside the owner file
- active dispatcher / CLI coverage
- final-module validation
- Binaryen parity via `bun fuzz compare-pass ...` or `bun scripts/pass-fuzz-compare.ts ...`
- explicit documentation of any intentional divergence from Binaryen

## Non-goals for the current tree

Until a real port lands, do not claim Starshine supports:

- near-duplicate function class formation,
- generated helper functions,
- original-name-preserving thunk rewrites,
- call-target parameterization into `call_ref`,
- Binaryen's shrink-level scheduler slot, or
- helper-plus-thunk profitability decisions.

## Related pages

- Overview: [`./index.md`](./index.md)
- Binaryen strategy: [`./binaryen-strategy.md`](./binaryen-strategy.md)
- Upstream file/test map: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- Core mechanics: [`./equivalence-classes-param-derivation-and-thunk-rewrites.md`](./equivalence-classes-param-derivation-and-thunk-rewrites.md)
- Profitability and type barriers: [`./profitability-indirection-and-type-barriers.md`](./profitability-indirection-and-type-barriers.md)
- Shape catalog: [`./wat-shapes.md`](./wat-shapes.md)
- Port readiness: [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
- Raw source manifest: [`../../../raw/binaryen/2026-05-05-merge-similar-functions-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-merge-similar-functions-current-main-recheck.md)
- Research follow-up: [`../../../raw/research/0443-2026-05-05-merge-similar-functions-current-main-recheck.md`](../../../raw/research/0443-2026-05-05-merge-similar-functions-current-main-recheck.md)
- Legacy raw source manifest: [`../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md`](../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md)
- Legacy research follow-up: [`../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md`](../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md)
