---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md
  - ../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./type-requirements-cfg-and-unsupported-families.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Starshine port readiness and validation for `type-generalizing`

## Current decision

Keep `type-generalizing` boundary-only until there is an explicit decision to support a developer/experimental pass.

Reasons:

- upstream Binaryen registers `experimental-type-generalizing` as a hidden test pass;
- upstream labels it not yet sound;
- the implementation depends on CFG/backward dataflow plus oracle-like type facts;
- several instruction families remain unsupported/TODO in upstream;
- Starshine currently has no owner file, dispatcher case, or backlog slice.

## Implementation-readiness checklist

A future port should not mutate modules until these prerequisites are available or intentionally scoped down:

1. **CFG and joins:** function CFG with enough structure to propagate requirements backward across joins.
2. **Value-stack requirements:** representation for stack-position type requirements, not only locals.
3. **Local requirement lattice:** conservative joins for reference/heap types and exact top/bottom behavior.
4. **Oracle or subset:** either a `ContentOracle` analogue or a deliberately narrower first slice that excludes oracle-dependent shapes.
5. **Instruction transfer table:** explicit handlers for locals, calls, `call_ref`, globals, tables, ref ops, struct ops, array ops, and conversions.
6. **Unsupported-family policy:** EH, tuple, string, continuation, atomic GC, and source-TODO families must skip or reject with tests.
7. **Local declaration rewrite:** safe mutation of non-param local declarations while preserving params and scalar locals.
8. **Use repair:** update every affected `local.get` / `local.tee` result type.
9. **Validation/refinalization:** run local validation after mutation and preserve a way to repair expression metadata.
10. **Binaryen oracle lane:** know how to invoke or fixture the hidden `experimental-type-generalizing` pass.

## Recommended slice order

### Slice 0: registry honesty

Current state. Keep direct requests rejected as boundary-only and keep presets free of this pass.

Acceptance:

- `pass_registry_category("type-generalizing") == BoundaryOnly`;
- `run_hot_pipeline(..., ["type-generalizing"])` errors before dispatch;
- `optimize` / `shrink` expansions do not include the name.

### Slice 1: analyzer-only prototype

Compute proposed generalized local declarations for a tiny reference-local subset, but do not write changes.

Start with shapes where:

- no EH, tuple, string, continuation, table, atomics, or GC aggregates appear;
- only `drop`, `local.get`, `local.set`, `local.tee`, direct calls, and function result constraints are present;
- all unsupported families are explicit skips.

Acceptance:

- tests compare computed proposed local types against hand-fixtured Binaryen `type-generalizing.wast` examples;
- no module bytes are changed.

### Slice 2: narrow mutating local rewrite

Rewrite non-param reference-local declarations only for the Slice 1 subset. Retag affected `local.get` and `local.tee` expression result types, then validate.

Acceptance:

- positive WAT fixtures show generalized local declarations;
- param and function-result constraints remain unchanged;
- direct request is active only after registry tests change deliberately;
- unsupported families remain no-op or rejected.

### Slice 3: call_ref and table/global constraints

Add transfer rules for direct call, `call_ref`, globals, and tables. Keep GC aggregates and oracle-dependent precision guarded if no local oracle exists yet.

Acceptance:

- call signatures prevent unsafe generalization;
- `call_ref` tests cover bottom target and declared-supertype cases where Starshine can parse/validate them;
- global/table declaration constraints feed requirements correctly.

### Slice 4: GC aggregate and oracle-dependent families

Only after the previous slices are stable, add struct/array/ref operation transfer rules and any needed oracle facts.

Acceptance:

- struct field and array element requirements constrain locals;
- unsupported atomic/string/continuation/EH families stay guarded;
- compare against Binaryen on targeted fixtures.

## Validation ladder

For any mutating slice, run:

1. focused pass tests for positive and negative WAT shapes;
2. registry tests for category and preset honesty;
3. `moon info`;
4. `moon fmt`;
5. `moon test`;
6. targeted Binaryen comparison if hidden-pass invocation is available in the harness;
7. broader pass-fuzz only after the pass supports enough syntax to avoid meaningless unsupported-surface failures.

## Required negative tests

- Params are not generalized.
- Scalar locals are not generalized through reference logic.
- Function-result uses preserve result requirements.
- Direct-call and `call_ref` argument requirements block unsafe local broadening.
- Global/table/struct/array requirements block unsafe local broadening.
- Unsupported EH, tuple, string, continuation, and atomic GC shapes do not rewrite silently.
- Local get/tee expression types agree with rewritten local declarations after validation.

## Documentation requirements for implementation

If a local port lands, update:

- this page with exact owner-file and test paths;
- [`./starshine-strategy.md`](./starshine-strategy.md) from boundary-only status to implementation map;
- [`./wat-shapes.md`](./wat-shapes.md) with Starshine-supported versus upstream-only families;
- [`../tracker.md`](../tracker.md) and [`../index.md`](../index.md);
- [`../../index.md`](../../index.md) and [`../../log.md`](../../log.md);
- `agent-todo.md` if the pass becomes an active backlog slice.

## Current safest answer

Do not implement this opportunistically as part of a generic pass campaign. It is an experimental upstream pass with enough unsupported surface that the safest Starshine work is either continued documentation/health maintenance or an explicitly scoped analyzer-only prototype.
