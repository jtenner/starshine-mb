---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-dead-argument-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md
  - ../../../raw/research/0435-2026-05-04-dead-argument-elimination-current-main-recheck.md
  - ../../../raw/research/0406-2026-04-26-dead-argument-elimination-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dae-optimizing/starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dae-optimizing/index.md
  - ../signature-pruning/index.md
---

# Starshine `dead-argument-elimination` port readiness and validation

This page turns the plain `dead-argument-elimination` dossier into an implementation-readiness checklist.
It is not an implementation claim: Starshine still rejects `dead-argument-elimination` as boundary-only today.

Use it when starting a future port or when reviewing whether a plain-DAE change accidentally implements the optimizing sibling's scheduler behavior.

## Current hold point

Starshine currently has:

- a local descriptive pass name, `dead-argument-elimination`, in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt);
- boundary-only request behavior through `run_hot_pipeline_expand_passes(...)`, which returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline` for that exact name;
- no exact upstream alias `dae`;
- no owner file for module-level call-boundary analysis;
- no active preset role for the plain pass.

That is intentionally different from upstream Binaryen, where the public pass name is `dae` and `dae-optimizing` is a sibling wrapper over the same core engine.

## Why this must be a module pass

Plain DAE changes a function boundary and every owned caller together.
A HOT peephole cannot see enough of the module to do that correctly.

The minimum faithful local implementation needs all of these module facts before it mutates anything:

- function signatures and type-section users;
- imports and exports;
- direct `call` and `return_call` sites;
- function references and call-reference / indirect-call escape surfaces;
- tail-call relationships;
- all direct operands at each parameter position;
- whether each result is dropped by all owned callers;
- whether removed operands have effects that must remain evaluated.

## First safe slice: no-rewrite analyzer

Before deleting any parameter, add an analyzer-only pass or test helper that reports candidates without changing the module.

It should classify each defined function as one of:

- **closed direct-call boundary**: all relevant calls are owned direct calls and the signature may be considered;
- **visible boundary**: import/export/public/reference exposure means the signature must not change;
- **tail-call constrained**: dropped-result changes are blocked or limited by tail-call compatibility;
- **operand-localization needed**: a candidate exists, but call operands must first be localized or preserved explicitly.

Validation for this slice:

- assert no binary/text output changes;
- compare candidate classification against small Binaryen `--dae` fixtures from [`./wat-shapes.md`](./wat-shapes.md);
- add tests for exports, imports, `ref.func`, `call_ref`, `call_indirect`, and `return_call` even if the first mutating slice ignores most of them.

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
- **unprofitable-chain throttle**: preserve Binaryen's one-caller chain throttle rather than making Starshine an unbounded signature-churn pass.

## Plain-vs-optimizing guardrail

Plain `dead-argument-elimination` must stop after the shared boundary rewrite core.
It must not run the nested cleanup replay documented for [`../dae-optimizing/starshine-strategy.md`](../dae-optimizing/starshine-strategy.md).

Practical test rule:

- `--pass dead-argument-elimination` may leave callee-local setup or other cleanup debris that remains valid;
- the optimizing sibling may clean that debris only when `dead-argument-elimination-optimizing` / a future `dae-optimizing` alias is requested.

If a future plain pass starts matching every optimizing golden, check whether it accidentally imported the sibling scheduler.

## Exact local code surfaces

Current reusable code surfaces:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - lines `127-130` name the boundary-only DAE pair in the registry list;
  - lines `302-303` append those names as boundary-only entries;
  - lines `487-503` are the request-rejection path;
  - future module-pass registry and preset-spelling decision point.
- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt)
  - `Instruction::call_ref(...)` and `Instruction::return_call_ref(...)` constructors;
  - direct call / tail-call instruction representation used by future caller repair.
- [`src/validate/env.mbt`](../../../../../src/validate/env.mbt)
  - `Env::resolve_functype(...)` and `Env::get_functype_by_funcidx(...)`, needed for signature checks and repaired-call validation.
- [`src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
  - type rules for `call`, `call_indirect`, `call_ref`, `return_call`, and `return_call_ref`; these are the post-rewrite correctness oracle inside Starshine.
- [`src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
  - binary support for `call_ref` / `return_call_ref`, useful for escape-surface tests.
- [`src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
  - text-fixture lowering for call and tail-call families.

Missing code surfaces for a faithful port:

- module-level call-boundary summary;
- function signature rewrite helper;
- direct caller operand/result repair;
- type-section user remapping;
- body-local parameter-index repair;
- Binaryen-oracle focused test harness entries for plain `dae`.

## Validation ladder

Use this ladder when implementing:

1. **Registry honesty**
   - Assert `dead-argument-elimination` is boundary-only before the port.
   - Decide whether to add `dae` as an alias; if yes, test both names.
2. **Analyzer-only tests**
   - No output changes.
   - Candidate classifications for private direct calls, exports, imports, `ref.func`, call-reference escape, indirect calls, and tail calls.
3. **Minimal scalar rewrite tests**
   - One unused param, one private callee, one direct caller.
   - Multi-caller direct boundary.
   - Removed actual with side effect preserved.
   - Export/import/reference negatives.
4. **Binaryen oracle comparison**
   - Run focused `wasm-opt --dae -S` comparisons for each supported slice.
   - Normalize only known textual noise; do not normalize away missing side effects or signature differences.
5. **GC/refinement tests**
   - Port the `dae-gc*` families only after local type-section and validator behavior are stable.
6. **Dropped-result tests**
   - Cover all-results-dropped positives, tail-call negatives, and uninhabited-result repair.
7. **Sibling split tests**
   - Keep a fixture where plain `dae` leaves valid cleanup debris that the optimizing sibling would remove.

## Beginner checklist

If you are unsure whether a future local rewrite belongs in plain DAE, ask:

- Does it change a function boundary?
- Can every caller that observes that boundary be found and repaired?
- Are removed operands still evaluated when needed?
- Are tail-call and uninhabited-result rules preserved?
- Is the result still valid before running any cleanup pass?
- Would the expected cleanup only happen under `dae-optimizing` in Binaryen?

If the answer to the last question is yes, do not put that cleanup in plain DAE.

## Sources

- [`../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md)
- [`../../../raw/research/0406-2026-04-26-dead-argument-elimination-port-readiness.md`](../../../raw/research/0406-2026-04-26-dead-argument-elimination-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../dae-optimizing/starshine-strategy.md`](../dae-optimizing/starshine-strategy.md)
