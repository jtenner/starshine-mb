---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md
  - ../../../raw/research/0422-2026-04-27-flatten-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-flatten-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../docs/0065-2026-03-24-ir2-execution-plan.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-contract-and-preludes.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
  - ../rereloop/index.md
  - ../i64-to-i32-lowering/index.md
---

# Starshine `flatten` port readiness and validation

Use this page after reading the overview in [`./index.md`](./index.md), the upstream strategy in [`./binaryen-strategy.md`](./binaryen-strategy.md), the concrete shape catalog in [`./wat-shapes.md`](./wat-shapes.md), and the current local status map in [`./starshine-strategy.md`](./starshine-strategy.md).

This page answers a narrower question: **what should the first Starshine implementation slices prove before `flatten` stops being a removed-name placeholder?**

## Current hold point

Starshine still does not implement `flatten`.

The exact current local surfaces are:

| Surface | Location | Meaning |
| --- | --- | --- |
| Removed-name registry | `src/passes/optimize.mbt:143-151` | `flatten` is known and intentionally tracked, but not runnable. |
| CLI pass-token preservation | `src/cli/cli_test.mbt:280-285` | `--flatten` survives trap-mode filtering. |
| CLI plus `-O` preservation | `src/cli/cli_test.mbt:313-316` | explicit `--flatten` survives beside an optimization-level flag. |
| Dispatcher absence | `src/passes/pass_manager.mbt` | no active `flatten` case exists. |
| Old IR2 batch plan | `docs/0065-2026-03-24-ir2-execution-plan.md:39` | `flatten` remains first in an older Batch 2 order. |
| Old registry-map plan | `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:47` | `flatten` remains removed until implemented. |
| Active backlog gap | `agent-todo.md` | no dedicated active `flatten` slice exists today. |

Do not read that as partial implementation. It is compatibility and planning scaffolding only.

## First decision: local Flat IR contract

Binaryen's pass is defined by `src/ir/flat.h`, not by the English phrase “remove nesting.”

A future Starshine port should first decide how to express the same contract locally:

1. a verifier-like analysis that reports non-flat HOT/IR2 shapes;
2. a committed normal-form invariant that downstream passes can rely on; or
3. an explicitly different Starshine invariant with documented Binaryen divergence.

The minimum analyzer should classify these families before rewriting anything:

- ordinary operands that are not constants, `local.get`, `unreachable`, or allowed `ref.as_non_null`;
- value-carrying `block`, `loop`, `if`, and legacy `try`;
- reachable `local.tee`;
- `local.set` whose value is control flow;
- concrete function-body flow that needs `return` wrapping;
- carried `br`, `br_if`, and `br_table` values;
- unsupported `BrOn*` and `TryTable` families;
- legacy EH `catch` / `pop` shapes that require repair after block insertion.

That analyzer-only slice gives reviewers a safe way to compare Starshine's shape classifier against Binaryen before the pass starts manufacturing locals.

## Minimum mutating slice

The first mutating slice should be deliberately small.

Recommended order:

1. simple expression spill;
2. function-body concrete result wrapping;
3. value-carrying `block` rewrite;
4. value-carrying `if` rewrite with arm temp stores;
5. condition-prelude placement before the whole `if` and arm-prelude placement inside each arm.

This order teaches the pass's core mechanism without immediately entangling branch payloads, EH repair, or unsupported feature policy.

The first tests should prove both positives and non-rewrites:

- nested arithmetic or call child becomes temp-local traffic;
- already-simple children stay simple;
- concrete function body becomes explicit `return` / local-read shape;
- value-carrying block result is routed through a temp;
- value-carrying if arms write the same temp;
- effectful condition work does not move into only one arm;
- `ref.as_non_null` remains governed by the special flatness rule rather than spilled blindly.

## Second slice: tees and branch payload channels

After basic value routing is green, add the payload-specific cases that make `flatten` more than a simple “spill nested values” pass:

- reachable `local.tee` lowers to `local.set` prelude plus `local.get`;
- unreachable `local.tee` keeps the unreachable effect and does not invent a reachable write;
- carried `br` stores into a named target temp;
- carried `br_if` stores into a named target temp and preserves the not-taken flowing-out value;
- the source-derived `br_if` target-type versus flowing-out-type mismatch gets two temps;
- `br_table` stores the value once and copies it into every unique target temp.

The two-temp `br_if` family is a must-have parity test because it is easy to miss and is explicitly motivated by upstream source comments.

## Third slice: loops, legacy try, EH, and unsupported features

Only after the simpler families are stable should a port claim broader pass coverage.

Required tests before any parity claim:

- value-carrying `loop` routes its body result through a temp and leaves a `local.get` outside;
- legacy `try` routes do/catch results through a shared temp;
- inserted catch blocks still validate after EH pop repair;
- placeholder `unreachable` preserves real control effects that can no longer stay nested;
- `BrOn*` and `TryTable` have an explicit documented policy.

Binaryen currently hard-fails on `BrOn*` and `TryTable`. Starshine must either match that behavior, pre-gate the pass away from those shapes, or record a deliberate no-op/divergence. Silent divergence should block a parity claim.

## Downstream validation lanes

Once direct reduced tests are green, validate the cluster role that makes `flatten` worth porting:

1. direct `--pass flatten` comparison against Binaryen for supported shapes;
2. `flatten -> simplify-locals-notee-nostructure -> local-cse` reduced lanes;
3. `flatten -> rereloop` reduced lanes;
4. `flatten -> i64-to-i32-lowering` reduced lanes;
5. saved generated-artifact `-O4z` slot replay for slot `9` once the pass is runnable;
6. nested aggressive rerun checks, because the saved Binaryen debug log showed many total `flatten` executions in a full `-O4z` run.

Use `bun fuzz compare-pass ...` or `bun scripts/pass-fuzz-compare.ts ...` only after reduced shape tests make the supported-surface policy clear. The pass has hard unsupported upstream families, so a raw broad fuzz lane without feature filtering can produce misleading failures.

## What should block removing `flatten` from `pass_registry_removed_names()`

Do not move `flatten` out of removed status until all of these are true:

- a real owner file exists;
- the dispatcher has an explicit active case;
- the CLI accepts an explicit `--flatten` request without treating it as removed;
- direct reduced shape tests cover basic spill, value-carrying control, tees, branch payloads, placeholders, and unsupported-family policy;
- the Starshine strategy page links the exact owner, dispatcher, registry, and tests;
- the tracker records whether the port is partial or parity-complete;
- the active backlog has either a completed slice or no stale `flatten` TODOs.

## Open questions

- Should Starshine implement a standalone Flat IR verifier, or should the pass itself own the analyzer/classifier?
- Should unsupported `BrOn*` and `TryTable` match Binaryen's hard failure or become Starshine pass-gates?
- Which local EH helper should own the equivalent of Binaryen `EHUtils::handleBlockNestedPops(...)`?
- Should the first runnable port be HOT-based, IR2-based, or a module/function hybrid that only uses HOT for eligible bodies?

## Bottom line

The safe local sequence is:

1. prove the Flat IR classifier;
2. land narrow value-spill and control-result rewrites;
3. add tee and branch-payload channels;
4. add EH and unsupported-feature policy;
5. only then wire aggressive-cluster and Binaryen-oracle validation.

That keeps `flatten` honest as a structural normalizer and prevents a future port from becoming a vague nesting cleanup with the upstream name.
