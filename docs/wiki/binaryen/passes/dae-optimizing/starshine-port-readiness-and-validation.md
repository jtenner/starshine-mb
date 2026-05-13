---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dead-argument-elimination/starshine-port-readiness-and-validation.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dead-argument-elimination/index.md
  - ../dae2/index.md
  - ../precompute-propagate/index.md
---

# Starshine `dae-optimizing` port readiness and validation

This page turns the `dae-optimizing` dossier into an implementation-readiness and validation checklist.
It is not a full-parity claim: Starshine now exposes the exact upstream spelling `dae-optimizing` plus the descriptive alias `dead-argument-elimination-optimizing`, but the implementation is still a guarded partial port rather than Binaryen's complete optimizing sibling.

Use it when extending the current port or when reviewing whether a plain DAE change accidentally imported the optimizing sibling's nested rerun behavior.

## Current hold point

Starshine currently has:

- public pass names `dae-optimizing` and `dead-argument-elimination-optimizing` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt);
- a live module-pass dispatcher path in [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) that runs the shared DAE boundary rewrite plus a guarded touched-function nested cleanup slice;
- focused regressions for touched-only nested cleanup order, size-skip tracing, and touched-only `optimize-casts` / `reorder-locals` behavior in [`src/passes/dae_optimizing_test.mbt`](../../../../../src/passes/dae_optimizing_test.mbt);
- an exact upstream-style nested cleanup prefix trace of `precompute-propagate`, but not the real `precompute-propagate` pass family itself;
- no full default-function-pipeline replay on all touched functions, no broad-module nested replay, and no green debug-artifact compare yet.

That is closer to upstream Binaryen than the earlier boundary-only hold point, but it is still intentionally narrower than the full optimizing sibling.

## Why this must be a module pass

`dae-optimizing` changes a function boundary and every owned caller together.
A HOT peephole cannot see enough of the module to do that correctly.

The minimum faithful local implementation needs all of these module facts before it mutates anything:

- function signatures and type-section users;
- imports and exports;
- direct `call` and `return_call` sites;
- function references and call-reference / indirect-call escape surfaces;
- tail-call relationships;
- all direct operands at each parameter position;
- whether each result is dropped by all owned callers;
- whether removed operands have effects that must remain evaluated;
- which touched functions need nested cleanup replay after the boundary rewrite.

## First safe slice: no-rewrite analyzer

Before deleting any parameter, add an analyzer-only pass or test helper that reports candidates without changing the module.

It should classify each defined function as one of:

- **closed direct-call boundary**: all relevant calls are owned direct calls and the signature may be considered;
- **visible boundary**: import/export/public/reference exposure means the signature must not change;
- **tail-call constrained**: dropped-result changes are blocked or limited by tail-call compatibility;
- **operand-localization needed**: a candidate exists, but call operands must first be localized or preserved explicitly.

Validation for this slice:

- assert no binary/text output changes;
- compare candidate classification against small Binaryen `--dae-optimizing` fixtures from [`./wat-shapes.md`](./wat-shapes.md);
- add tests for exports, imports, `ref.func`, `call_ref`, `call_indirect`, `return_call`, and dropped-result families even if the first mutating slice ignores most of them.

## First mutating slice: scalar dead-param deletion

The smallest useful mutating slice is narrower than Binaryen's full pass:

1. Only private defined functions.
2. Only direct `call` sites, not `call_ref` or `call_indirect` rewrites.
3. Only scalar parameters that are not read in the callee body.
4. Preserve removed actual operands as side-effecting statements in the caller when they are not trivially removable.
5. Repair the callee signature and every direct call in the same module rewrite.
6. Refuse recursive and multi-function cycles until the candidate graph is explicit enough to prove them.

This slice should already be a module pass because it changes declarations and callsites together.
It should not be implemented by locally deleting `local.get` or by editing only function bodies.

## Follow-up slices

After the scalar slice is green, port the remaining Binaryen families one at a time:

- **constant actual materialization**: if all owned callers pass the same constant, insert the callee-local value before removing the incoming parameter;
- **recursive and forwarding cycles**: remove parameters forwarded through direct-call cycles only when the entry value is never otherwise observed;
- **GC parameter refinement**: keep live parameters but narrow their reference type from call-operand least-upper-bound evidence;
- **result refinement**: narrow result types from returned-value evidence and repair call expression types;
- **dropped-result removal**: remove results only when all owned callers drop them and tail-call constraints allow it;
- **uninhabited-result preservation**: emit the needed `call; unreachable`-style repair when deleting an uninhabited result would otherwise lose control-flow knowledge;
- **operand localization and retry**: localize hard operands first, then rerun the boundary core when the localized form exposes a legal deletion;
- **unprofitable-chain throttle**: preserve Binaryen's one-caller chain throttle rather than making Starshine an unbounded signature-churn pass;
- **nested cleanup replay**: on productive changes, rerun the targeted function-cleanup suffix rather than treating the boundary rewrite as the end of the pass.

## Plain-vs-optimizing guardrail

Plain [`../dead-argument-elimination/index.md`](../dead-argument-elimination/index.md) must stop after the shared boundary rewrite core.
It must not run the nested cleanup replay documented here.

Practical test rule:

- `--pass dead-argument-elimination` may leave callee-local setup or other cleanup debris that remains valid;
- the optimizing sibling may clean that debris only when `dae-optimizing` or `dead-argument-elimination-optimizing` is requested.

If a future plain pass starts matching every optimizing golden, check whether it accidentally imported the sibling scheduler.

## Exact local code surfaces

Current reusable code surfaces:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - the registry already exposes both `dae-optimizing` and `dead-argument-elimination-optimizing` with the same summary;
  - future preset-spelling and documentation sync point if the partial/full split changes.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - current module-pass dispatcher surface, shared DAE boundary core, touched-function tracking, and guarded nested cleanup scheduler;
  - current home of the function-filtered `local-cse` and `reorder-locals` adapters, nested-pass trace lines, and size-skip guards.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
  - CLI/config plumbing for pass selection, tracing, and `closed_world` behavior.
- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt)
  - function types and direct / indirect / reference call instruction shapes.
- [`src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
  - type rules for `call`, `call_indirect`, `call_ref`, `return_call`, and `return_call_ref`.
- [`src/validate/validate.mbt`](../../../../../src/validate/validate.mbt)
  - module-level reference validation.
- [`src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
  - text-fixture lowering for call and tail-call families.

Missing code surfaces for a faithful port:

- a real `precompute-propagate` sibling or equivalent nested prefix replay;
- a performant default-function-pipeline replay for touched functions without the current small-module guards;
- broader function-filtered adapters or safe batching for still-module-shaped cleanup passes that Binaryen reruns after productive DAE changes;
- final debug-artifact output parity and pass-local runtime attribution closure;
- Binaryen-oracle focused test coverage for any newly enabled cleanup families beyond the current guarded slice.

## Validation ladder

Use this ladder when implementing:

1. **Registry honesty**
   - Assert `dead-argument-elimination-optimizing` is boundary-only before the port.
   - Decide whether to add a `dae-optimizing` alias; if yes, test both names.
2. **Analyzer-only tests**
   - No output changes.
   - Candidate classifications for private direct calls, exports, imports, `ref.func`, call-reference escape, indirect calls, and tail calls.
3. **Minimal scalar rewrite tests**
   - One unused param, one private callee, one direct caller.
   - Multi-caller direct boundary.
   - Removed actual with side effect preserved.
   - Export/import/reference negatives.
4. **Binaryen oracle comparison**
   - Run focused `wasm-opt --dae-optimizing -S` comparisons for each supported slice.
   - Normalize only known textual noise; do not normalize away missing side effects or signature differences.
5. **GC/refinement tests**
   - Port the `dae-gc*` families only after local type-section and validator behavior are stable.
6. **Dropped-result tests**
   - Cover all-results-dropped positives, tail-call negatives, and uninhabited-result repair.
7. **Nested cleanup replay tests**
   - Keep a fixture where the boundary rewrite changes a function and the optimizing replay is required to reach the final shape.
8. **Sibling split tests**
   - Keep a fixture where plain DAE leaves valid cleanup debris that the optimizing sibling would remove.

## Beginner checklist

If you are unsure whether a future local rewrite belongs in `dae-optimizing`, ask:

- Does it change a function boundary?
- Can every caller that observes that boundary be found and repaired?
- Are removed operands still evaluated when needed?
- Are tail-call and uninhabited-result rules preserved?
- Is the result still valid before running any cleanup pass?
- Would the expected cleanup only happen under `dae-optimizing` in Binaryen?

If the answer to the last question is yes, keep it out of plain DAE and into the optimizing sibling.

## Sources

- [`../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md)
- [`../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md`](../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md)
- [`../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md`](../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md)
- [`../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./signature-updates-and-nested-reruns.md`](./signature-updates-and-nested-reruns.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../dead-argument-elimination/starshine-port-readiness-and-validation.md`](../dead-argument-elimination/starshine-port-readiness-and-validation.md)
