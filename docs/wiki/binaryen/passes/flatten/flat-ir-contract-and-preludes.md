---
kind: concept
status: supported
last_reviewed: 2026-07-14
sources:
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-tuple-refresh.md
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
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-try-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-try-rich-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-try-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-try-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-try-conditional-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-reversed-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-scalar-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-11-flatten-current-main-and-local-status-recheck.md
  - ../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md
  - ../../../raw/research/0422-2026-04-27-flatten-port-readiness.md
  - ../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md
  - ../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `flatten`: Flat IR contract and preludes

## Why this page exists

The easiest way to misunderstand `flatten` is to think it simply “introduces locals for nested values.”

That is too vague.

The real pass is defined by two things together:

- the exact Flat IR contract in `src/ir/flat.h`
- the exact `preludes` movement algorithm in `src/passes/Flatten.cpp`

The 2026-04-27 port-readiness check, plus the 2026-07-11 source recheck in Binaryen current-main [`Flatten.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp), found no teaching-relevant drift in those two upstream surfaces from the tagged `version_129` dossier.

This page focuses on those two pieces. The local analyzer-first plan for proving this contract in Starshine is tracked separately in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## The formal Flat IR contract

`flat.h` defines Flat IR as four exact AST properties.

## 1. Ordinary operands must be simple

For ordinary instructions, children must already be one of:

- `local.get`
- constant expression
- `unreachable`
- `ref.as_non_null`

That means flatten is trying to eliminate children like:

- nested arithmetic trees
- nested calls
- nested `block (result ...)`
- nested `if (result ...)`
- nested `local.tee`
- nested branch payload producers

by computing them earlier and then reading a local instead.

## 2. Control flow may not return values

After flattening, these structures must no longer flow a value directly:

- `block`
- `loop`
- `if`
- `try`

The function body also must not remain a concrete value expression by itself.

This is why the pass does not just flatten *children*; it also rewrites the control nodes themselves.

## 3. `local.tee` is forbidden

In flat IR:

- `local.set` is the only allowed setting operation in expression positions
- `local.tee` must be eliminated into explicit earlier set plus later get behavior

## 4. `local.set` cannot directly hold control flow

Even if some control-flow child is otherwise type-correct, it is still too structured to sit directly under `local.set` in Flat IR.

That rule is easy to miss, but it is one reason flatten has to use placeholder `unreachable` nodes in some rewritten positions.

## Important nuance: `ref.as_non_null`

`flat.h` explicitly allows nested `ref.as_non_null`.

That is a special-case rule, not a generic exception for any non-null producer.

At the same time:

- `Flatten.cpp` still has an open non-nullability TODO
- shipped tests prove some non-null families already work

So the honest summary is:

- some non-null cases are already allowed
- some remain unfinished
- the exact supported set is narrower than “all non-null values” but broader than “none of them”

## The `preludes` model

The most important implementation idea in `Flatten.cpp` is the `preludes` map.

A prelude is:

- code that must execute immediately before a specific expression

That code is usually:

- a `local.set` computing a formerly nested value
- a rewritten control-flow expression that now runs earlier
- a real control effect such as an `unreachable`-typed exit that cannot stay nested in place anymore

## Why preludes exist

Consider a nested expression like:

```wat
(i32.add
  (block (result i32)
    (i32.const 1)
  )
  (i32.const 2)
)
```

Flat IR does not allow that `block (result i32)` child.

Binaryen therefore needs to turn it into something like:

```wat
(block
  (local.set $tmp
    (i32.const 1)
  )
)
(i32.add
  (local.get $tmp)
  (i32.const 2)
)
```

The block part is the prelude. The `local.get` is the flattened replacement child.

## The migration rule

After Binaryen builds `ourPreludes` for the current node, it decides where they can move.

### Case 1: non-control parent

If the parent exists and is **not** a control-flow structure:

- Binaryen migrates the current node’s preludes upward into the parent’s prelude list

Why that is safe:

- the parent is just another ordinary expression
- the prelude still executes immediately before the parent uses the child result

### Case 2: control-flow parent

If the parent is a control-flow structure, or there is no parent:

- the preludes stay attached to the current expression
- the control-flow parent will later place them explicitly in the right region

This is why control-flow nodes need custom logic.

They are where placement stops being purely local.

## Why this preserves evaluation order

The key source-derived reason flatten preserves side-effect order is:

- a nested effectful computation is not deleted
- it is merely moved into a prelude that executes immediately before the use site (or before the nearest enclosing control node that can place it correctly)

Starshine now makes that placement rule explicit in `src/passes/flatten.mbt`:

- each structured region is scanned independently;
- each region root owns one ordered prelude list;
- ordinary operand trees are visited postorder and sibling operands append spills left to right;
- the complete list is inserted immediately before the owning root;
- `if` conditions use the enclosing root list, while then/else bodies own separate regional lists;
- block, loop, and legacy-try bodies are scanned through their own `HotRegionRef` instead of migrating work across a control boundary.

The current implementation applies this plan to supported scalar ordinary operands and to reachable/unreachable `local.tee` nodes at function roots, structured-region roots, and ordinary operand positions. Reachable tees append their source work before an explicit write to the original local and replace the value position with `local.get`; unreachable tees preserve the real unreachable in the owner prelude and leave an unreachable placeholder at the old operand position. Nested terminal `br`, `br_table`, `return`, `return_call`, `return_call_indirect`, `return_call_ref`, `throw`, and `throw_ref` operands now use the same owner-local placeholder rule: branch payload, tail-call operand, or throw-argument work is flattened first in source order, the real effect is sequenced once in the owning region, and the old child slot becomes `unreachable`. Owner-region tracking prevents a terminal already present as an earlier root from being duplicated. Branch-free defaultable scalar block/if values; branch-free defaultable multivalue blocks and ifs, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, plus zero-input loops with payloadless backedges, independently scalar tails, and one exclusive repeated HOT consumer span; plain terminal or nested multivalue block `br` payloads, including mixed independently scalar fallthrough tails, with the same typed-vector ownership; branch-targeted multivalue if arms with independently scalar fallthrough tails, terminal plain exits, or same-vector conditional exits whose false-path values form one exact exclusive tail span; branch-free scalar and per-arm independently produced or exact separately owned tuple-made multivalue legacy try tails with supported scalar component origins behind an explicit nested-pop/delegate repair gate, with multivalue results requiring one exclusive repeated consumer span; defaultable scalar branch-targeted if values; and zero-input or independently scalar inputful/no-backedge scalar-result loop values also route through owner-local temps. Inputful loops stage each independently scalar entry exactly once in source order, or scalarize one exact tuple-made entry whose immediate reversed direct-drop prefix owns every lane; both routes redirect body uses through typed locals, remove the loop parameter prefix, and keep that entry channel separate from result traffic. Scalar results use one separate temp. Inputful multivalue-result lanes use a separate ordered result vector for independently scalar tails or one exact exclusively owned tuple-made result tail, while backedges may use an exact independently scalar or exclusively tuple-made plain `br`, an exact same-vector `br_if` from independently scalar or one exclusively owned tuple-made payload whose immediate reversed false path contains direct drops, exact single-use same-typed binary expressions with simple right operands, or exact single-use unary/conversion expressions, or when an exact multivalue table targets the loop plus an enclosing block, one repeated exclusive if-result tail, or one repeated exclusive block-result tail. Payloadless zero-input backedges remain valid after result routing; independently scalar defaultable one- or multi-parameter `br`/`br_if` backedges write typed entry locals before branching. Multi-parameter payloads retain source order and one evaluation per producer; rich conditional payloads run once before their condition, and false-path flow reads the same typed locals. Defaultable independently scalar one- or multi-parameter loop-targeting `br_table` stages every payload once in source order and copies each vector into every unique loop entry-local vector before the selector. One exact exclusively owned `TupleMake` repeated across the table payload slots follows the same scalar staging path when its ordered components match every target vector; nondefaultable and other multivalue single-producer table backedges remain whole-function fail-closed. Branch-targeted ifs preflight both arm tails and every label use, share one temp across fallthrough arms plus carried `br`/`br_if` flow, and leave nondefaultable payload families whole-function fail-closed; unsupported root value-controls remain outside scalar body-result materialization. Broader control values, remaining branch payload channels, `rethrow`/`delegate`, and EH repair still require dedicated rewrite families; they must not be generalized by moving arbitrary work across the recorded owner boundary.

So a good mental model is:

- flatten converts stack-style nesting into statement-style sequencing
- it does not change the intended order of observable work

## Why flatten creates so many locals

Flatten is allowed to be wasteful.

That is deliberate.

Its job is:

- normalize shape first
- let later passes such as `simplify-locals-notee-nostructure` and `local-cse` clean up the extra traffic later

This is why `pass.cpp` immediately schedules those neighbors after `flatten` in aggressive mode.

## Named target temps for carried branch values

The second key implementation map is `breakTemps`.

This map stores:

- one temp local per named branch target

Starshine represents every admitted block, if, and loop target with one per-label typed local vector, so scalar channels are the one-element case and wider channels can reuse the same type-checked allocation path. Its admitted payload slices mirror Binaryen's shape for plain scalar `br` and scalar `br_if` into a defaultable scalar block target: the carried value becomes ordered local traffic, the branch payload is cleared, and the target block reuses the named-target temp when erasing its result type. For same-type `br_if`, every later HOT use of the peeked payload is redirected to one shared `local.get`. Rich ordinary scalar payloads bypass generic root spilling, keep their original producer as the one local-set input, and are sequenced before any rich condition prelude; repeated chained conditionals then consume local reads rather than reevaluating the producer. For the Binaryen v130 target-type versus flowing-out-type mismatch, Starshine allocates a second flow-typed temp, evaluates the payload into it once, copies its `local.get` into the target-typed temp, and redirects false-path uses to the flow temp. The rewrite preflights every use of the target, permits mixed supported `br`/`br_if` exits, and also admits scalar `br_table` targets when every unique label can be repaired together. Rich ordinary table payloads retain one producer, are stored and fanned out before selector preludes, and are tracked through removal of the HOT terminal payload root. For same-vector multivalue `br_if` into defaultable block/if targets, Starshine writes each ordered payload once into the target vector, replaces the exact contiguous false-path tail with matching local reads, clears only the payload children, and preserves the condition. Vector type mismatch, ambiguous/shared false-path ownership, and multivalue `br_table` still trigger a whole-function fail-closed gate before operand spilling. `BrOn*` and other deferred families also remain gated so label arity cannot be partially repaired.

The purpose is simple:

- once Flat IR forbids branch instructions from carrying arbitrary nested value trees directly, those values need somewhere explicit to live

So flatten rewrites them through locals keyed to the target name.

## Why `br_if` is trickier than `br`

A plain `br` either exits or it does not matter what happens next.

A `br_if` is different:

- if the condition is false, its carried value may still matter to the surrounding expression context

`Flatten.cpp` documents a real mismatch case where:

- the target block expects one type
- the inner flowing-out context expects another type

When that happens, Binaryen may need:

- one temp for the target block’s carried type
- another temp for the value that can still flow outward when the branch is not taken

Starshine now handles both the same-type one-temp case and this source-backed two-temp mismatch for supported scalar payloads. The mismatch route evaluates the payload once through the flow temp before copying it into the target channel, and rich ordinary producers retain one shared origin across false-path uses. The first block/if multivalue route is deliberately narrower: exact same target/flow vectors, independently scalar payload origins, and one contiguous exclusive false-path tail; mismatched or ambiguously shared vectors remain separate work. Legacy-try multivalue flow additionally admits immediate reversed independently scalar or exclusively tuple-made unary/conversion and same-typed binary consumers with simple right operands; all results are directly dropped. That double-temp rule is one of the most important beginner-unfriendly details in the whole pass.

## Why `switch` / `br_table` duplicates work

For switch values, flatten first stores the carried value once and then copies it into all unique target temps. Starshine implements that route for supported defaultable scalar payload origins and block targets, including exact terminal scalar legacy-try tables with any complete strict direct-enclosure chain of matching block/if controls in structural order and no hardcoded count cap, or one exact inputful-loop ancestry when the table payload matches the loop input and existing loop preflight succeeds; independently scalar multivalue tables admit the same arbitrary direct block/if order plus the separately proven direct inputful-loop route; exclusively tuple-made multivalue tables admit arbitrary strict direct block/if order and the exact inputful-loop route after separate exclusive-ownership, component, one-evaluation, loop-backedge, and safe-deletion preflight; it sequences rich payloads before rich selectors, deduplicates repeated labels, keeps try and block channels distinct, clears the table payload, and removes the HOT terminal payload-root artifact before control-result erasure. The multivalue correspondence admits exact defaultable target vectors: each independently scalar component or exclusively owned repeated-`TupleMake` lane is staged once in source order, repeated labels produce one target-vector copy, nested block targets each receive one vector copy, and selector work remains afterwards. The strict target roster is now checked by building direct structural parent links once and walking outward from the try, replacing the prior repeated-candidate scan; the three-block-plus-thirty-two-if focused fixture completed in 0.187s on a warm local run. A nested target may feed its enclosing target only through one exclusive ordered repeated-control region tail. Exact fanout between an inputful multivalue loop and its enclosing block is admitted when entries, table payloads, and fallthrough results are independently scalar and exact. Exact loop-plus-if fanout is also admitted when one repeated exclusive if-result tail feeds the loop. Staged payload, loop-entry, if-result, and loop-result vectors remain distinct. Broader mixed-control fanout, nested or nonexclusive conditional loop control, mismatched vectors, and ambiguous ownership remain open. See the tagged v130 switch refresh in [`../../../raw/binaryen/2026-07-13-flatten-version-130-switch-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-switch-refresh.md), the repeated-tuple two-block-plus-if admission evidence in [`../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-tuple-refresh.md), the scalar multiple-if ancestry evidence in [`../../../raw/binaryen/2026-07-14-flatten-version-130-scalar-try-two-if-table-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-scalar-try-two-if-table-refresh.md), and the independently scalar multivalue extension in [`../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-if-table-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-if-table-refresh.md), and the reverse try-inside-if-inside-block evidence in [`../../../raw/binaryen/2026-07-14-flatten-version-130-reverse-try-if-block-table-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-reverse-try-if-block-table-refresh.md), and the separate repeated-tuple ownership audit in [`../../../raw/binaryen/2026-07-14-flatten-version-130-reverse-try-if-block-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-reverse-try-if-block-table-tuple-refresh.md).

That may look redundant, but it expresses the right truth:

- before the branch fires, Binaryen does not know which label will be taken
- so each possible target’s carried-value channel must be made explicit

Again, flatten prefers a simple explicit representation over a clever compact one.

## The placeholder `unreachable` rule

One surprising part of `Flatten.cpp` is the generic rule for expressions that become `Type::unreachable`.

Binaryen does **not** just delete them.

Instead:

- it keeps the real expression in preludes
- it leaves a placeholder `unreachable` in the original spot

Why that matters:

- the original control effect still happens in the right order
- but the remaining AST position stays valid under Flat IR’s structural restrictions

This is especially important when a formerly nested control effect can no longer sit directly where it used to.

## Function-body repair

Flat IR also disallows the function body itself from being a concrete value expression.

So in `visitFunction(...)`, Binaryen:

- wraps a still-concrete body in `return`
- then attaches any remaining body preludes

This is why even a simple function body result can become extra local traffic after flattening.

## EH pop repair is part of the real contract

`Flatten.cpp` finishes functions with:

- `EHUtils::handleBlockNestedPops(...)`

That is not optional cleanup polish.

The source comment says flatten can create blocks inside `catch`, which invalidates where `pop` is allowed to appear.

So the real flatten contract includes:

- flattening first
- then repairing the EH stack discipline after the structural rewrite

A future port that skips this step would not be faithfully implementing the source contract.

Starshine now makes the missing prerequisites executable as `flatten_eh_repair_requirement(...)`: legacy `Catch`/`CatchAll` require typed catch-payload tracking, while `Rethrow`/`Delegate` require exceptional-transfer repair. The classifier is used by the whole-function fail-closed gate; it is not a repair implementation. Current lib/HOT lift-lower has no first-class Binaryen-style typed catch-payload `Pop`, so entry extraction, exact local typing, nested-catch exclusion, and old-position replacement remain blocked.

## Unsupported and surprising boundaries

## `BrOn*` and `TryTable`

In `version_129`, Binaryen does not merely decline to optimize those.

It hard-fails with:

- `Unsupported instruction for Flatten`

That is a major boundary and should be documented explicitly in any future port plan.

## Selective non-null support

The source set is intentionally mixed here:

- `flat.h` treats `ref.as_non_null` specially
- `Flatten.cpp` still has a non-nullability TODO
- tests prove at least some non-null families work

So if a future Starshine port hits a non-null flatten case, the right question is not:

- “does flatten support non-null?”

The right question is:

- “is this one of the selective non-null families Binaryen already handles, or one of the families the TODO still covers?”

## Bottom line

The cleanest summary is:

- Flat IR is a very specific contract
- preludes are the mechanism that makes that contract implementable without reordering work
- `breakTemps` are the mechanism that makes carried branch values explicit
- placeholder `unreachable` plus EH pop fixup are part of the real correctness story
- and that is why flatten is much more than a generic “remove nesting” pass
