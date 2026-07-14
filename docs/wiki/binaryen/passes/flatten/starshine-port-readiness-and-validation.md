---
kind: concept
status: supported
last_reviewed: 2026-07-13
sources:
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-legacy-eh-repair-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-terminal-throw-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-conditional-consumer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-terminal-tail-call-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-block-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-if-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-branch-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-entry-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-table-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-conditional-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-conditional-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-result-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-11-flatten-current-main-and-local-status-recheck.md
  - ../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md
  - ../../../raw/research/0422-2026-04-27-flatten-port-readiness.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../raw/research/0065-2026-03-24-ir2-execution-plan.md
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
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

Starshine now has the first internal implementation slices, but does not yet expose `flatten` as a public runnable pass.

The exact current local surfaces are:

| Surface | Location | Meaning |
| --- | --- | --- |
| Removed-name registry | `src/passes/optimize.mbt:143-151` | `flatten` is known and intentionally tracked, but not runnable. |
| CLI pass-token preservation | `src/cli/cli_test.mbt:305-309` | `--flatten` survives trap-mode filtering. |
| CLI plus `-O` preservation | `src/cli/cli_test.mbt:340-342` | explicit `--flatten` survives beside an optimization-level flag. |
| Internal owner | `src/passes/flatten.mbt` | Flat IR classification, scalar body-result materialization, reachable/unreachable tee lowering across function roots, structured-region roots, and ordinary operand positions, ordered scalar operand preludes, branch-free defaultable scalar block/if routing, branch-free defaultable independently produced multivalue block/if, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, and zero-input loop routing across payloadless backedges through exclusive consumer spans, branch-targeted independently scalar multivalue if arms with plain exits, branch-free scalar and independently produced multivalue legacy try do/catch routing behind an explicit catch-payload/exceptional-transfer prerequisite classifier, defaultable scalar branch-targeted if routing, zero-input and independently scalar or one exact tuple-made-entry inputful scalar-result loop routing with payloadless or independently scalar one- and multi-parameter `br`/`br_if` backedges, and plain scalar or independently scalar multivalue block-targeting `br`, scalar `br_if` routing including rich ordinary payload origins and the two-temp target/flow mismatch, same-vector multivalue block/if-targeting `br_if` routing across exact exclusive false-path spans, plus independently scalar `br_table` rich-origin and unique-target fanout for defaultable scalar block/if targets, exact repeated-label and nested multi-block multivalue targets, one- or multi-parameter loop entry channels, exact inputful multivalue loop plain branches and `br_if` channels with immediate direct-drop, same-typed binary with a simple right operand, unary, or conversion false flow from independently scalar or tuple-made payloads, one exact exclusive tuple-made loop result tail, and exact loop-plus-block and loop-plus-if table channels, and owner-local terminal placeholders for nested `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` are implemented. Branch-free multivalue blocks and ifs plus zero-input multivalue loops with payloadless backedges and independently scalar defaultable tails route through ordered typed locals when all repeated HOT result uses form one exclusive consumer span. Unsupported root value-controls are kept out of scalar body-result materialization. Same-vector multivalue `br_if` payloads write independently scalar origins once into the shared target vector, replace one contiguous ordered false-path tail with matching reads, preserve the condition, and clear the payload children. Mismatched/shared multivalue `br_if` plus mixed if/loop or nonexclusive multivalue `br_table` payloads remain whole-function fail-closed; branch-targeted ifs now preflight every use and share one result temp across fallthrough plus carried `br`/`br_if` flow, while nondefaultable payloads also fail closed before mutation. Inputful loops now capture each independently scalar defaultable entry once in source order, redirect body uses through typed locals, and clear the loop parameter prefix. Scalar result routing remains separate; admitted plain-branch, exact immediate direct-drop or scalar-binary false-flow conditional, and table-backed multivalue-result families use a distinct ordered result vector. Payloadless zero-input and independently scalar defaultable one- or multi-parameter `br`/`br_if` backedges reuse typed entry locals, preserve payload order and one evaluation before conditional tests, preserve false-path flow, and clear their carried arity. One- or multi-parameter loop-targeting tables stage every independently scalar payload once in source order and copy each vector into unique target entry locals. Exact inputful multivalue loop-plus-block fanout additionally routes independently scalar or one exact exclusive tuple-made fallthrough result tail through separate locals; nondefaultable and multivalue single-producer table backedges fail closed before mutation. Plain multivalue block branches now write each independently scalar defaultable payload into the shared typed target vector in source order, while mixed blocks route independently scalar fallthrough tails through that same vector; nested plain exits are admitted after complete label-use preflight. Branch/control arity is cleared and an exclusive repeated consumer span remains required. Branch-free scalar legacy tries route exact do/catch tails through one typed local. Branch-free multivalue legacy tries route exact independently scalar do/catch tails through one shared typed vector when one exclusive repeated consumer span owns the results. `flatten_eh_repair_requirement(...)` now classifies missing catch-payload tracking separately from exceptional-transfer repair before mutation. Functions containing legacy `Catch`/`CatchAll`, `rethrow`, or `delegate` nodes remain whole-function fail-closed until Binaryen-equivalent typed payload representation and nested-pop repair exist. Remaining richer tuple-made loop conditional consumers and mixed table loop backedges, mismatched or ambiguously shared multivalue `br_if`, mixed if/loop or nonexclusive multivalue `br_table`, nested or nonexclusive conditional multivalue loop controls, `rethrow`/`delegate` repair, broader legacy-try/EH shapes, and other control work remain open. |
| Old IR2 batch plan | `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md:69-70` | `flatten` remains first in an older Batch 2 order. |
| Old registry-map plan | `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md:107-108` | `flatten` remains removed until implemented. |
| Active backlog | `agent-todo.md` `[O4Z-FLAT]001` | records the remaining implementation, wiring, fuzzing, timing, and scheduler work. |

Read this as a deliberately internal partial implementation, not as public pass availability or parity evidence.

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
- branch-free defaultable scalar block results are routed through a temp, while branch-targeted blocks stay deferred until their payload channel can be repaired;
- value-carrying if arms write the same temp;
- condition work stays in the owning prelude while arm work remains inside its selected arm;
- `ref.as_non_null` remains governed by the special flatness rule rather than spilled blindly.

## Second slice: tees and branch payload channels

After basic value routing is green, add the payload-specific cases that make `flatten` more than a simple “spill nested values” pass:

- reachable `local.tee` now lowers to an ordered `local.set` prelude plus `local.get` at function roots, structured-region roots, and ordinary operand positions;
- unreachable `local.tee` now keeps the real unreachable effect in the owner prelude or region root and does not invent a reachable write;
- carried scalar `br` into a defaultable scalar block target now stores into one named-target temp, clears the branch payload, and lets a terminal branch-targeted block erase its result type;
- same-type carried `br_if` now stores once into the named target temp, clears the branch payload, and redirects the peeked false-path flow through one shared `local.get`;
- rich ordinary scalar `br_if` payloads are sequenced before rich conditions, evaluated once, and shared across repeated chained conditionals instead of being reevaluated by generic operand spilling;
- the source-derived `br_if` target-type versus flowing-out-type mismatch uses a second flow-typed temp, one payload evaluation, and a typed copy into the target temp;
- same-vector multivalue `br_if` into defaultable block/if targets now evaluates each supported scalar payload once in source order, writes the target's shared typed local vector, replaces the exact contiguous false-path tail with matching reads, clears only payload children, and preserves the condition; mismatched vectors, unsupported origins, and ambiguous/shared false-path ownership remain fail-closed before mutation;
- scalar `br_table` stores rich ordinary payloads once before rich selectors, copies into every unique target temp, deduplicates repeated labels, clears its payload, and removes the HOT terminal payload-root artifact; exact independently scalar multivalue vectors now cover repeated/nested block targets and exact inputful loop-plus-enclosing-block, loop-plus-repeated-if, and loop-plus-repeated-block families, while broader mixed-control and nonexclusive fanout remain open.

The two-temp scalar `br_if` family remains a must-have parity test because it is easy to miss and is explicitly motivated by upstream source comments. The v130 concrete-type owner also motivates the same-vector multivalue correspondence, but Starshine keeps stricter ownership gates until broader tuple-flow proof exists.

## Third slice: loops, legacy try, EH, and unsupported features

Only after the simpler families are stable should a port claim broader pass coverage.

Required tests before any parity claim:

- zero-input and independently scalar inputful scalar-result `loop` route body results through a temp and leave a `local.get` outside; admitted inputful loops capture entries once in order and clear their parameter prefix, payloadless and independently scalar one- or multi-parameter `br`/`br_if` backedges reuse entry locals, and independently scalar one- or multi-parameter `br_table` backedges stage ordered vectors into unique target entry locals. Multivalue `br_if` false-path flow admits an immediate reversed span of direct drops, exact single-use same-typed binary expressions with simple right operands, or exact single-use unary/conversion expressions; shared, nested, non-immediate, non-simple, and mismatched consumers remain gated. The inputful multivalue-result table lanes additionally permit exact loop-plus-enclosing-block fanout with independently scalar fallthrough tails, or one repeated exclusive block/if result tail that feeds a distinct loop-result vector; multivalue single-producer table channels remain explicit negatives;
- branch-free scalar and independently produced multivalue legacy `try` now route exact do/catch results through shared typed locals; multivalue ownership requires one exclusive repeated consumer span, while repair-sensitive `Catch`/`CatchAll`, `rethrow`, and `delegate` functions are explicitly pre-gated;
- the prerequisite classifier must stay fail-closed until typed catch-payload consumption is representable; inserted catch blocks must then validate after Binaryen-equivalent EH pop repair before broader legacy-EH admission;
- placeholder `unreachable` now preserves nested terminal `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` effects in their owner region without duplicating effects that HOT already exposes as an earlier root; branch payload, tail-call operand, and throw-argument work remains before the terminal in source order and later sibling preludes remain later, while `rethrow`/`delegate` stay gated with EH repair;
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

Use `moon build --target native --release src/cmd` followed by `bun fuzz compare-pass ... --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` or `bun scripts/pass-fuzz-compare.ts ... --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` only after reduced shape tests make the supported-surface policy clear. The pass has hard unsupported upstream families, so a raw broad fuzz lane without feature filtering can produce misleading failures.

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
