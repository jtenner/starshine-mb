---
kind: concept
status: supported
last_reviewed: 2026-07-16
sources:
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-nested-call-argument-impact.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-add-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-pure-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-pure-binary-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-add-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-two-multiplies-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-sub-two-multiplies-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-subtract-const-multiply-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-subtract-multiply-const-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-multiply-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-multiply-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-add-multiply-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-nontrapping-binary-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-nontrapping-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-root-sequence-with-trap-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-root-sequence-with-unreachable-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-direct-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-call-argument-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-conversion-call-argument-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-constant-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-plus-constant-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-conversion-plus-constant-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-constant-argument-vector-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-one-rich-argument-vector-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-unary-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-conversion-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-binary-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-conversion-pair-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-rich-argument-vector-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-one-multiply-child-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-multiply-children-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-deeper-two-multiply-children-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-direct-drop-const-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-multiply-roots-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-multiply-add-roots-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-trapping-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-call-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-call-argument-suffix-refresh.md
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

The current implementation applies this plan to supported scalar ordinary operands and to reachable/unreachable `local.tee` nodes at function roots, structured-region roots, and ordinary operand positions. Reachable tees append their source work before an explicit write to the original local and replace the value position with `local.get`; unreachable tees preserve the real unreachable in the owner prelude and leave an unreachable placeholder at the old operand position. Nested terminal `br`, `br_table`, `return`, `return_call`, `return_call_indirect`, `return_call_ref`, `throw`, and `throw_ref` operands now use the same owner-local placeholder rule: branch payload, tail-call operand, or throw-argument work is flattened first in source order, the real effect is sequenced once in the owning region, and the old child slot becomes `unreachable`. Owner-region tracking prevents a terminal already present as an earlier root from being duplicated. Branch-free defaultable scalar block/if values; branch-free defaultable multivalue blocks and ifs, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, plus zero-input loops with payloadless backedges, independently scalar tails, and one exclusive repeated HOT consumer span; plain terminal or nested multivalue block `br` payloads, including mixed independently scalar fallthrough tails, with the same typed-vector ownership; branch-targeted multivalue if arms with independently scalar fallthrough tails, terminal plain exits, or same-vector conditional exits whose false-path values form one exact exclusive tail span; branch-free scalar and per-arm independently produced or exact separately owned tuple-made multivalue legacy try tails with supported scalar component origins behind an explicit nested-pop/delegate repair gate, with multivalue results requiring one exclusive repeated consumer span; defaultable scalar branch-targeted if values; and zero-input or independently scalar inputful/no-backedge scalar-result loop values also route through owner-local temps. Inputful loops stage each independently scalar entry exactly once in source order, or scalarize one exact tuple-made entry whose immediate reversed direct-drop prefix owns every lane; both routes redirect body uses through typed locals, remove the loop parameter prefix, and keep that entry channel separate from result traffic. Scalar results use one separate temp. Inputful multivalue-result lanes use a separate ordered result vector for independently scalar tails or one exact exclusively owned tuple-made result tail, while backedges may use an exact independently scalar or exclusively tuple-made plain `br`, an exact same-vector `br_if` from independently scalar or one exclusively owned tuple-made payload whose immediate reversed false path contains direct drops, exact single-use same-typed binary expressions with simple opposite operands or exact one-use rich right operands when the payload is left, or exact single-use unary/conversion expressions, or when an exact multivalue table targets the loop plus an enclosing block, one repeated exclusive if-result tail, or one repeated exclusive block-result tail. Payloadless zero-input backedges remain valid after result routing; independently scalar defaultable one- or multi-parameter `br`/`br_if` backedges write typed entry locals before branching. Multi-parameter payloads retain source order and one evaluation per producer; rich conditional payloads run once before their condition, and false-path flow reads the same typed locals. Defaultable independently scalar one- or multi-parameter loop-targeting `br_table` stages every payload once in source order and copies each vector into every unique loop entry-local vector before the selector. One exact exclusively owned `TupleMake` repeated across the table payload slots follows the same scalar staging path when its ordered components match every target vector; nondefaultable and other multivalue single-producer table backedges remain whole-function fail-closed. Branch-targeted ifs preflight both arm tails and every label use, share one temp across fallthrough arms plus carried `br`/`br_if` flow, and leave nondefaultable payload families whole-function fail-closed; unsupported root value-controls remain outside scalar body-result materialization. Broader control values, remaining branch payload channels, `rethrow`/`delegate`, and EH repair still require dedicated rewrite families; they must not be generalized by moving arbitrary work across the recorded owner boundary.

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

Starshine now handles both the same-type one-temp case and this source-backed two-temp mismatch for supported scalar payloads. The mismatch route evaluates the payload once through the flow temp before copying it into the target channel, and rich ordinary producers retain one shared origin across false-path uses. The first block/if multivalue route is deliberately narrower: exact same target/flow vectors, independently scalar payload origins, and one contiguous exclusive false-path tail; mismatched or ambiguously shared vectors remain separate work. Legacy-try multivalue flow additionally admits immediate reversed independently scalar or exclusively tuple-made unary/conversion and same-typed binary consumers with simple opposite operands or exact one-use rich right operands when the payload is left; all results are directly dropped. That double-temp rule is one of the most important beginner-unfriendly details in the whole pass.

## Why `switch` / `br_table` duplicates work

For switch values, flatten first stores the carried value once and then copies it into all unique target temps. Starshine implements that route for supported defaultable scalar payload origins and block targets, including exact terminal scalar legacy-try tables with any complete strict direct-enclosure chain of matching block/if controls in structural order and no hardcoded count cap, or one exact inputful-loop ancestry when the table payload matches the loop input and existing loop preflight succeeds; independently scalar multivalue tables admit the same arbitrary direct block/if order plus the separately proven direct inputful-loop route; exclusively tuple-made multivalue tables admit arbitrary strict direct block/if order and the exact inputful-loop route after separate exclusive-ownership, component, one-evaluation, loop-backedge, and safe-deletion preflight; a supported try table may have only direct `Unreachable` roots after it in the same arm, any positive number of exclusively owned distinct direct `drop(const)` roots, either exact two-root mixed order of direct `drop(const)` and direct `Unreachable`, either exact two-root mixed order of direct `drop(i32.add(const, const))` and direct `Unreachable`, any positive ordered sequence whose roots are independently owned direct `drop(const)`, direct `Unreachable`, or independently owned direct `drop(i32.add(const, const))`, `drop(i32.sub(const, const))`, `drop(i32.mul(const, const))`, `drop(i32.and(const, const))`, `drop(i32.clz(const))`, `drop(i64.extend_i32_s(const))`, or `drop(i32.div_s(const, const))`, or exact owned direct resultless calls with zero arguments, any positive vector of distinct scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exact scalar constant, `i32.add(const, const)`, `i32.div_s(const, const)`, `i32.clz(const)`, or `i64.extend_i32_s(const)` argument, or exact one- or two-multiply-child outer-add or outer-subtract drop trees with constant leaves, or one exact bounded outer add/subtract tree combining a matching two-multiply-child subtree and one direct constant; separately admitted single-root suffixes include exact `drop(i32.sub(const, const))`, any positive number of independently owned direct `drop(i32.mul(const, const))` roots, exact `drop(i32.and(const, const))`, exact `drop(i32.clz(const))`, exact `drop(i64.extend_i32_s(const))`, or exact `drop(i32.div_s(const, const))` root, and exact owned direct resultless calls with zero arguments, any positive vector of distinct exclusively owned scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct exclusively owned scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exclusively owned scalar constant, exact `i32.add(const, const)`, exact `i32.div_s(const, const)`, exact `i64.extend_i32_s(const)`, or exact `i32.clz(const)` argument are admitted through existing try-table ancestries; routing removes that exact detached suffix before the terminal try-result proof; it sequences rich payloads before rich selectors, deduplicates repeated labels, keeps try and block channels distinct, clears the table payload, and removes the HOT terminal payload-root artifact before control-result erasure. Structured suffix roots remain fail-closed because deleting a HOT control without a matching label-removal mutation invalidates its owned label, while retaining a live detached owner would not be complete subtree deletion. The multivalue correspondence admits exact defaultable target vectors: each independently scalar component or exclusively owned repeated-`TupleMake` lane is staged once in source order, repeated labels produce one target-vector copy, nested block targets each receive one vector copy, and selector work remains afterwards. The strict target roster is now checked by building direct structural parent links once and walking outward from the try, replacing the prior repeated-candidate scan; the three-block-plus-thirty-two-if focused fixture completed in 0.187s on a warm local run. A nested target may feed its enclosing target only through one exclusive ordered repeated-control region tail. Exact fanout between an inputful multivalue loop and its enclosing block is admitted when entries, table payloads, and fallthrough results are independently scalar and exact. Exact loop-plus-if fanout is also admitted when one repeated exclusive if-result tail feeds the loop. Staged payload, loop-entry, if-result, and loop-result vectors remain distinct. Broader mixed-control fanout, nested or nonexclusive conditional loop control, mismatched vectors, and ambiguous ownership remain open. See the tagged v130 switch refresh in [`../../../raw/binaryen/2026-07-13-flatten-version-130-switch-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-switch-refresh.md), the repeated-tuple two-block-plus-if admission evidence in [`../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-tuple-refresh.md), the scalar multiple-if ancestry evidence in [`../../../raw/binaryen/2026-07-14-flatten-version-130-scalar-try-two-if-table-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-scalar-try-two-if-table-refresh.md), and the independently scalar multivalue extension in [`../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-if-table-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-if-table-refresh.md), and the reverse try-inside-if-inside-block evidence in [`../../../raw/binaryen/2026-07-14-flatten-version-130-reverse-try-if-block-table-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-reverse-try-if-block-table-refresh.md), and the separate repeated-tuple ownership audit in [`../../../raw/binaryen/2026-07-14-flatten-version-130-reverse-try-if-block-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-14-flatten-version-130-reverse-try-if-block-table-tuple-refresh.md).

That may look redundant, but it expresses the right truth:

- before the branch fires, Binaryen does not know which label will be taken
- so each possible target’s carried-value channel must be made explicit

Again, flatten prefers a simple explicit representation over a clever compact one.

## Owned dead-call argument trees after unconditional table transfer

Starshine's internal legacy-try table route now uses one recursive resultless direct-call argument collector instead of bounded one-multiply, two-multiply, and deeper special cases. It records every immediate call argument first, then recursively records supported unary, conversion, and binary descendants in source operand order without a tree-depth cap. Every node must remain live, scalar, distinct, and one-use before complete suffix deletion; direct `i32.sub`, `i32.mul`, `i32.and`, `i32.or`, `i32.xor`, `i32.shl`, `i32.shr_s`, and `i32.shr_u` join the established top-level root roster, while `i32.rotl` remains the tested boundary. One lightweight reachable node-use-count snapshot owns the suffix proof without full use-site/local-use allocation, one cached label-use bitset serves support plus rewrite routing, and exact terminal-table decisions are keyed by table, label, payload arity, and mixed-target policy. Admission caches exact owned node vectors, owner regions, and terminal support; after exact same-region detachment, mutation tombstones the complete distinct vector with one HOT revision invalidation. A missing fact after rewriting starts fails closed, so no stale or partial analysis can widen ownership or target support.

This is not generic purity or effect analysis. Binaryen v130 keeps unreachable suffixes in Flat IR order; Starshine deletes them only because the preceding `br_table` is unconditional and no deleted node can execute or be shared. Alternate unary/conversion opcodes, repeated descendants, result calls, indirect/reference calls, and broader structured roots remain gated.

The structured-control prerequisite is now partially resolved. `hot_delete_detached_control_subtree(...)` proves a complete exclusive descendant tree, no root or outside child owner, no shared/cyclic descendant, exact live control-label ownership, and no outside branch or try-table catch user before tombstoning every node and owned label with one revision advance. Flatten uses it for three exact single-root suffixes after an unconditional scalar legacy-try table: one void block containing direct `drop(const)`, one constant-condition void if with complete direct `drop(const)` arms and both region holders, and one zero-input/no-backedge void loop containing direct `drop(const)`. Every descendant and owned label disappears; richer/partial controls, loop inputs/backedges, try-like controls, mixed/multiple roots, outside targets, and sharing remain whole-function fail-closed.

Pinned v130 direct flatten retains all three structured controls, while matched `--vacuum --dce` reduces each encoded probe from `76` to `63` bytes. This supports the direct Starshine deletion as cleanup-neighborhood progress under the existing unconditional-transfer proof, not as generic output drift. On the refreshed earlier three-probe matrix, nonthrowing synthetic-try elision remains `212` Starshine bytes versus Binaryen's `275` direct and `236` cleanup bytes. Current candidate-dense pass-local timing remains the unrequalified `970.5 us`, or `3.65x` Binaryen. See [`../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md`](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md).

### Exact branch-use indexing and one-for-one tail mutation

The rewrite state now records each live branch-like node once per targeted label before mutation, including deduplicated repeated/default `br_table` labels and `try_table` catch labels. `label_used` is derived from that same index. Scalar target support therefore iterates only exact target users rather than rescanning every live node; the cache remains immutable and a missing post-mutation proof still fails closed.

When control-result routing only replaces one region root with `local.set(temp, oldRoot)`, flatten uses exact HOT region-root replacement instead of rebuilding the holder's complete child array through a splice. A private invariant locks sibling identity, old-value ownership, one revision advance, and pass-analysis invalidation. When an admitted unconditional legacy-try table makes every later same-region root unreachable, `hot_region_truncate_suffix(...)` now detaches that ordered suffix by shortening the existing holder span; a red-first IR invariant locks prefix identity, child-storage stability, detached-root order, and one revision advance before the existing exact distinct-node batch deletion. Scalar mutation-time `br`, `br_if`, and `br_table` target checks also consume the immutable pre-mutation branch index, so post-snapshot nodes cannot widen the admitted target population.

The same proof boundary now applies to multivalue block/if targets. Recursive nested-target support, deferred rich-payload admission, and mutation-time `br`, `br_if`, and `br_table` routing iterate only the exact branch nodes captured for that label before mutation. Once a table has passed complete target/type/control preflight, flatten resolves each unique target's complete typed local vector once and reuses the vector for every staged payload lane. The resolver first checks every target and any existing vector without mutation, is available only after the rewrite boundary starts, and then allocates only missing block/if/try vectors; loop vectors must already match.

Multivalue legacy-try label support now uses that same exact branch population. Its `br_if` flow proof, plus the corresponding multivalue loop proof, uses lightweight reachable `HotNodeUseCounts` for exact two-use payload/tuple ownership and one-use consumer-expression ownership. Admission reads the pre-mutation snapshot; rewrite requires `rewrites_started` before consuming it. This removes full node-use/use-def allocation without changing evaluation order, result vectors, false-flow placement, EH gates, or deletion ownership.

Exact multivalue `TupleMake` region tails now use the same frozen ownership population. Because the tuple is already observed at the exact region-tail root and slot, a total reachable use count of one proves exclusive ownership without allocating a use-site vector; mutation-time block, if, loop, and legacy-try routes require `rewrites_started` before consuming that cached fact. Inputful-loop proof likewise uses the pre-mutation per-label branch population for both general backedges and exact multivalue `br_if` flow, and reuses the same reachable counts for tuple flow during admission and rewrite.

The same rule now covers two scalar/control-adjacent families. A tuple-made inputful-loop entry is already known to occupy every entry slot and every immediate reversed body-prefix drop, so exact reachable count `2 * input_arity` proves complete ownership. A scalar legacy-try `br_if` payload is already known at the branch plus one immediately adjacent false-flow consumer, so payload count two and one-use rich-consumer count replace full site allocation. Dedicated rewrite helpers require `rewrites_started`, while uncached checks can still observe later uses and fail.

Tuple-made plain branch and table payloads now use the same frozen counts: direct structural checks already prove that every payload slot contains the tuple, so exact total count equal to payload arity proves no other reachable owner. Generic tuple-made block/if `br_if` cannot use counts alone because rewrite needs the exact false-flow parent and contiguous start slot. Admission therefore runs one reachable-root locator, caches the exact positive or negative site result by branch id, and rewrite refuses uncached discovery after mutation starts while rechecking that the cached slots still contain the tuple.

These changes do not relax any result-type, label-use, ownership, EH, trap, effect, or complete-subtree-deletion gate.

Distinct non-tuple block/if `br_if` flow now uses the same admission/rewrite boundary: admission caches the exact contiguous false-flow parent/start or a negative result, and rewrite cannot discover a new site. Scalar `br_if` flow needs to tolerate region-holder slot shifts caused by inserted preludes, so it snapshots exact parent populations rather than fixed final slots. Rewrite rescans only those parents, requires the same occurrence count, and accepts a chained branch replacement only when the same state recorded the replacement node. A post-snapshot use under any other parent is left untouched. The scalar fixture showed slight targeted overhead (`22 -> 23 ms`), so this is a failure-atomicity improvement rather than a performance win.

### Sparse proof storage does not weaken the mutation boundary

The latest internal state no longer allocates node-count-sized arrays for every possible conditional, terminal table, suffix, and scalar try. It stores exact entries only when admission inspects a branch, value, table, or try owner. This is a storage/layout change, not a semantic shortcut: multivalue negative flow decisions remain explicit entries, scalar flow retains exact pre-mutation parent populations and same-state replacement identity, terminal table entries retain label/payload/mixed-target identity, and dead suffix entries retain the exact owner region and node vector. Any absent entry after `rewrites_started` still fails closed.

The red-first sparse-cache invariants pass at private flatten `161/161`. Coarse reconstructed timing is directional or flat rather than a public-readiness win, so the unrequalified `970.5 us` checkpoint and all EH/label/signoff gates remain authoritative.

### Generic postorder routing and sequenced-root storage are now exact

Commits `7801166ac` and `18101a947` narrow two run-wide rewrite costs without changing any WAT-level transform. Generic postorder recursion now dispatches only carried plain `br` nodes to the remaining generic router; payload-bearing `br_if` and `br_table` already route and return in dedicated arms, while payloadless and ordinary nodes need no late router call. Sequence-root deduplication still binds the exact owner-region holder and node id, but stores only roots whose frozen pre-mutation reachable count proves more than one owner. A snapshot node limit makes rewrite-created ids fail the storage predicate instead of indexing stale counts.

The new invariants preserve the original reason for sequence tracking: a terminal effect already emitted as an earlier root in the same region must not be duplicated when HOT also exposes it under a later operand. Unique roots and post-snapshot nodes cannot satisfy that proof. Native-release pass-only measurement found an `8.86%` targeted win on the root-heavy recursive fixture after dispatch narrowing; shared-root sparsity was timing-flat but reduced exact bookkeeping from all processed roots to the one shared root in the invariant. Private flatten is now `163/163`; the durable `970.5 us` gate and all EH/label/signoff blockers remain authoritative.

### Single-target table staging and inputful-loop support are now exact

Commit `81cfb9619` keeps Binaryen's source-order rule—payload work before selector work—but removes a redundant local channel when every repeated/default table label resolves to one unique target. The payload is written directly into the already-resolved target vector; multi-target tables retain the separate staging vector and complete fanout. Existing verifier-backed tests prove scalar, tuple, loop, try, suffix, and nested-placeholder shapes all keep their target/result channels. A focused encoded module shrank `51 -> 47` bytes, so this is a measured Starshine size and local/operation-count win rather than an unmeasured representation drift. The pinned Binaryen v130 probe still emits the separate staging local and target copy.

Commit `dda2bdfe3` freezes the complete supported/unsupported result for each inspected inputful loop. Admission computes the result from exact types, entry ownership, label branches, conditional-flow sites, backedges, and result-tail ownership; rewrite may consume only that cached result. A missing entry after `rewrites_started` fails closed. The inputful-loop benchmark was timing-flat (`2,589 -> 2,584 us`), so the durable value is repeated-support removal and one stronger mutation-time proof boundary.

### Branch-user append and admission discovery now share one exact scan

Commits `6a74918d6` and `1acb9bc14` do not change the Flat-IR output contract. The immutable live-node scan now appends each branch user in constant time by remembering only the last node recorded for each label; repeated/default table labels from that same node are suppressed, while later branch nodes remain in exact HOT id order. That scan also records the complete pre-mutation loop, legacy-try, and payload-bearing branch candidate populations used by admission.

The new red-first invariants prove exact label populations, duplicate suppression, exact candidate rosters, and exclusion of 256 unrelated roots. Admission still performs every type, ownership, control, EH, effect, trap, and failure-atomicity proof; it merely starts from the exact relevant owner vectors instead of rediscovering them with three more whole-function scans. Targeted native-release measurement improves the branch-dense fixture `13.72%` and the root-heavy fixture `6.45%`. No transform family is admitted.

### EH prerequisites and Flat IR classification now share the immutable scan

Commits `7706110c1` and `2c5a54ac3` preserve the Flat-IR output and admission contracts while removing two more run-wide discovery traversals. The pre-mutation node index now records the exact typed-catch-payload and exceptional-transfer repair requirements alongside label branches and candidate rosters; `Delegate` still records its label target while selecting the exceptional-transfer gate. The same scan also accumulates the complete rich-operand, value-control, tee, control-under-set, body-flow, and hard-unsupported classification used by `flatten_run`.

The standalone `flatten_classify_hot(...)` path remains available and shares the same per-live-node and function-tail helpers, while rewrite state freezes the indexed report before mutation. The red-first invariants prove equality with the standalone classifier and exact EH outcomes in functions padded with 256 unrelated roots. No target, type, ownership, control, EH, effect, trap, deletion, or post-boundary failure rule changed. Code 1 produced a `6.28%` reconstructed representative reduction; code 2 timings overlapped or regressed by run order and is classified as scan consolidation only. The durable `970.5 us` / `3.65x` gate remains authoritative.

### Sparse proof lookup stays exact at candidate density

Commits `c420a9950` and `9b5c4170a` keep scalar-try, dead-suffix, and terminal-table proof storage sparse while replacing repeated linear lookup with sorted insertion and binary search. The ordering key is the exact pre-mutation try or table node id. Dead-suffix entries still bind the owner region and complete owned-node vector; terminal entries still bind label, payload arity, mixed-target policy, and support; scalar-try entries still bind the exact owner and support result. The first cached fact remains authoritative, and absent post-boundary facts remain rejection rather than an invitation to rediscover support.

The red-first tests query three owners in descending/mixed order and require the resulting sparse populations to remain sorted and exactly retrievable. Targeted native-release reconstruction measured `5.99%` improvement at 512 scalar tries per function and `58.49%` improvement at 256 terminal-table candidates per function. Representative timing overlapped by run order, so this is candidate-density work rather than public performance requalification. No Flat-IR, type, label, EH, effect, trap, ownership, deletion, or output-shape contract changed.

### Inputful-loop and scalar-flow lookup stays exact at candidate density

Commits `e32819f5b` and `fc5c89bff` extend the same sorted sparse contract to inputful-loop support, scalar `br_if` flow sites, and same-state scalar replacements. Loop entries are keyed by the exact pre-mutation loop id; flow-site entries by branch id; replacement entries by the original flowing value id. Admission still computes complete type, entry, ownership, branch, conditional-flow, result-tail, and current-parent facts before mutation. Rewrite still rejects an absent entry, rechecks current structure only within the frozen parent population, and accepts chained replacement identity only from the same state. Existing scalar replacement entries retain update semantics rather than first-proof immutability because they describe the current same-state replacement, not an admission decision.

The red-first invariants queried owners in descending/mixed order and failed on append order before sorted insertion landed. Fixed-total native-release density fixtures improved inputful loops `9.57%` and scalar flow `3.34%` at 128 candidates per function. No Flat-IR family, WAT output shape, type, label, EH, effect, trap, ownership, deletion, or public surface changed.

### Tuple and distinct multivalue conditional-flow lookup stays exact

Commits `80e6a652b` and `efb8fdfa2` complete sorted sparse lookup for the two remaining multivalue block/if `br_if` flow populations. Tuple-made and distinct-flow entries are keyed by exact pre-mutation branch id; admission still records an explicit positive or negative result, rewrite still checks the current cached parent/slots, and an absent entry after mutation starts still rejects.

The red-first invariants queried three branches in mixed order and failed on append order before sorted insertion. Exact cached-lookup reconstruction measured `47.34%` reduction for tuple flow and `66.89%` for distinct flow at 512 candidates. No Flat-IR, WAT shape, type, label, EH, effect, trap, ownership, deletion, or public-surface contract changed.

### Table-target and terminal-payload lookup stays exact

Commits `bdad9efaf` and `902848fca` remove two measured repeated linear scans without changing any Flat-IR rule. Unique table-target collection now marks labels once while retaining first source order and default-target-last behavior. Terminal payload roots remain a sparse exact set keyed by pre-mutation node id; sorted insertion and binary membership replace recursive traversal's repeated linear `contains` calls.

The red-first invariants lock duplicate suppression, invalid-label rejection, mixed-order sparse insertion, duplicate payload rejection, exact retrieval, and absent-root rejection. Dense reconstruction improves 512-label target extraction from `437,000 us` to `16,000 us` and 512-root payload membership from `110,000 us` to `20,000 us`. Type, target, ownership, EH, effect, trap, deletion, current-structure, and mutation-boundary proofs remain in their existing family helpers; no WAT or public surface changes.

### Run-wide immutable indexes and reusable scratch preserve the contract

The allocation/index follow-up changes storage, not Flat IR semantics. A `br_table`'s first-source-order unique targets are frozen once in a flat run-wide pool and borrowed by admission and rewrite; cache absence after the mutation boundary rejects. Direct structural parents are built lazily before mutation and ancestry queries reuse generation marks. Recursive traversal keeps one prelude array per active region depth, clears it between roots, and passes it only to `pass_splice_region(...)`, which copies the ids into HOT storage rather than retaining the caller's array.

Dead-suffix and loop-entry visitation reuse node-generation marks. Duplicate ownership scans are removed only where exact use counts are complete: a repeated reachable acyclic owned node would necessarily raise its root/child use count, and a repeated conditional payload would exceed the exact branch-plus-consumer count. Table target-local allocation still performs all-target nonmutating preflight first, but rewrite now reads `state.label_temps[target]` directly instead of creating `Array[Array[Int]]`. Type-result vectors are cached per run and scalar type checks avoid array creation entirely. Target, type, label, ownership, EH, effect, trap, deletion, current-structure, and failure-atomicity rules are unchanged.

### Shared-root and multivalue-flow lookup remain exact

Commits `4a03de7f3` and `aa295d38b` remove two more linear identity scans without changing Flat IR. Shared terminal roots remain a sparse set of exact `(region holder, node id)` pairs admitted only by the frozen pre-mutation use count; the pairs are now lexicographically sorted and binary-searchable when deciding whether a terminal effect was already sequenced. Rewrite-created ids still cannot enter that proof. Distinct multivalue `br_if` payload ids retain source order but use one temporary node mark set for duplicate rejection and payload-root exclusion during reachable false-flow discovery; cached parent/start slots and current-structure checks remain authoritative.

The red-first invariants lock mixed-order pair insertion, duplicate and cross-pair rejection, exact payload mark population, and duplicate payload rejection. At 512 candidates, the targeted lookup reconstructions improve sequenced-root membership `31,569 -> 2,664 us` (`91.56%`) and payload distinctness `64,554 -> 2,757 us` (`95.73%`). These are owner-specific internal results, not representative-gate requalification or semantic admission.

### Multivalue flow indexing preserves the same proof

Commits `f1dc57565` and `24b909b2d` change only query-local lookup inside the existing block/if multivalue `br_if` proofs. Distinct payload ids now map directly to their source slots, so each reachable child edge updates exactly one payload count instead of scanning the whole payload vector. Tuple-made flow slots now use one parent-sized mark array for duplicate rejection while retaining the ordered slot vector used by the final sort-and-contiguous-span check.

The semantic boundary is unchanged: each distinct payload still needs exactly the branch use plus one non-branch use; branch slots remain excluded from the false-flow parent; all false-flow lanes still share one parent and contiguous source order; tuple sites still require complete branch-slot coverage, exact total site count, and one non-branch parent; cached parent/start identity, current child slots, ownership, and post-mutation missing-proof rejection remain mandatory. The 512-candidate lookup reconstructions improve `97.92%` and `97.71%`, but they admit no new Flat-IR or WAT shape.

### Reversed multivalue binary consumers stay on the false path

Commits `2ae0a6adb` and `d64535310` extend the exact immediate binary-consumer family without changing prelude order. For independently scalar lanes, or one exclusively owned repeated `TupleMake`, a false-path binary may now contain the restored lane in child zero **or child one** when the opposite child is already Flat-IR-simple. Only the matching payload slot becomes a local read. The simple sibling and exact binary opcode remain in place after `br_if`, so effects and traps are not hoisted onto the taken path.

The proof still requires one immediate directly dropped, single-use, same-typed binary per lane; exact branch-plus-consumer ownership; complete tuple branch-slot and consumer coverage; defaultable lane types; and the pre-mutation admission boundary. Rich siblings, type-changing results, nesting, sharing, delayed consumers, and repair-sensitive EH remain gated.

### Rich right operands remain after the conditional branch

Commits `5c4a664dd` and `a4055b7a9` extend only the payload-left orientation. The right operand may be one exact one-use supported scalar origin. Postorder operand flattening then inserts that operand's `local.set` after the payload-free `br_if` and before the binary consumer. This is valid for the shared exact legacy-try and inputful-loop consumer helper because the right operand is evaluated only on the not-taken path in the source stack order.

### One exact rich left operand remains before the conditional branch

Commits `e5c2a91ea` and `d0a53acf9` implement the source-order proof that the payload-right orientation requires. For an independently scalar vector, or one exclusively owned repeated `TupleMake` with simple components, exactly one one-use rich left operand may precede the complete payload vector. Because the branch consumes the top payload vector and false flow consumes lanes in reverse order, that pre-branch value can pair only with lane zero after all higher lanes have been consumed. Rewrite emits its `local.set` before payload staging and `br_if`, replaces the binary's left child with the matching read, and leaves the binary itself after the branch.

Pinned Binaryen v130 probes show the same order: rich left call, payload values, condition, `br_if`, higher-lane consumption, then the lane-zero binary. Commits `843614438` and `35ac3740a` apply the same exact proof to inputful loops for independently scalar lanes and one exclusively owned repeated `TupleMake`. Commits `3cb5577ad` and `c5a0a738a`, followed by `61055698d` and `d9aa4cd94`, first established the left-before-child-prelude order for one rich payload in loops and legacy tries. Commits `6e4229bae` and `f223f14d6` then remove that temporary count cap for independently scalar and exclusively tuple-made vectors in both control families.

Every non-simple payload must still be an individually supported scalar origin. Independently scalar lanes retain exact two-use branch-plus-consumer ownership; tuple components remain under one exclusively owned repeated shell with complete branch-slot and consumer coverage, and the shell is deleted only after exact replacement. The rich-left write stays before every child-generated payload prelude, payload calls remain in vector order, the condition and payload-free `br_if` follow, and the binary remains on the not-taken path. Multiple or non-lane-zero rich lefts remain gated. Result typing, defaultability, direct-drop placement, current structure, complete tuple deletion, and the pre-mutation proof boundary remain unchanged.

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

Starshine makes the prerequisites executable as `flatten_eh_repair_requirement(...)`: legacy `Catch`/`CatchAll` require typed catch-payload tracking, while `Rethrow`/`Delegate` require exceptional-transfer classification. `FlattenRunAdmission` consumes that cached classification before mutation and returns the distinct deferred outcome for every unsupported population. The scalar and arbitrary ordered same-tag payload transactions now implement bounded-path `Pop` relocation subsets; scalar traversal includes an `if` condition but not either arm, while broader payload extraction remains fail-closed.

Pinned Binaryen v130 source also resolves two exact exceptional-transfer policies. `Flatten.cpp` has no dedicated rethrow/delegate rewrite, `eh-utils.cpp` only relocates nested payload `Pop`, and `wasm.h` represents delegation as `Try::delegateTarget`. Starshine therefore admits one depth-zero catch-all rethrow under direct block ancestry and lowers it through `catch_all_ref`, one captured `exnref` local, and `throw_ref`. It also admits one resultless inner try whose sole delegate targets the directly enclosing outer try and whose own label is unused; lowering keeps the outer target active and makes only that inner legacy shell transparent. Nonzero or non-direct rethrow, typed-catch composition, nested-catch ownership, non-direct/value-carrying/mixed delegate forms, used inner labels, and broader nested populations still select the deferred outcome before unrelated flatten work.

The later `3c819922c` / `41533e603` iteration superseded only the earlier one-rethrow and direct-block-only ceilings. At that checkpoint, one active catch could own any positive number of depth-zero rethrows while sharing one captured exception-reference local, and each path could cross direct blocks plus at most one resultless, untargeted `if` arm.

Commit `9c237165d` supersedes that temporary single-if ceiling. Each rethrow may now resolve through an arbitrary strict direct chain of resultless untargeted `if` arms and direct blocks. Every if still requires zero result arity and no label users; lowering visits only then/else regions, never conditions, loops, or nested try/catch regions. Commit `88197c97e` also widens the exact delegate representation: the delegated try's sole catch root may be a strict direct chain of resultless single-root blocks ending in the delegate, provided every block label and the inner try label are unused. Lowering recognizes the same chain and removes only those semantically empty wrappers while the exact outer target remains active.

For the narrower synthetic resultless catch-all representation, lowering still proves whether the try body may throw: a nonthrowing body omits the dead handler and lowers directly, retaining only a void block when the try label is targeted, while a possibly throwing body keeps the nested `try_table` bridge. This removes cleanup-only EH scaffolding without weakening the remaining typed-catch, nested-pop, or exceptional-transfer gates.

## Exact structured suffix cleanup after unconditional transfer

The internal legacy-try table route admits three exact structured root kinds after an unconditional `br_table`: void `block { drop(const) }`, void `if (const) { drop(const) } else { drop(const) }`, and zero-input/no-backedge void `loop { drop(const) }`. A positive suffix vector may now mix those controls with any ordinary root that already passes an exact dead-suffix recognizer, provided both ordinary and structured roots are present and every root is proven before mutation. This is not ordinary prelude motion. The table proves the suffix cannot execute; immutable root recognition proves the complete vector; and `hot_delete_detached_forest(...)` removes the full descendant/label union atomically after one detachment. `hot_delete_detached_control_forest(...)` and `hot_delete_detached_control_subtree(...)` remain validating wrappers.

The generic forest proof rejects duplicate or overlapping roots, cross-tree sharing, cycles, outside owners, incomplete control-label ownership, and outside branch/delegate/try-table-catch users before mutation. The if proof includes its condition, both HOT region-holder blocks, both arm drops/constants, the if label, and both region labels. The loop proof requires void type, zero branch arity, no loop-label users or backedges, one body root, and exclusive drop/constant ownership. Fresh pinned Binaryen v130 keeps an ordered `drop(const) + block + if + loop + unreachable` suffix under direct flatten at `76` bytes, while matched `--vacuum --dce` removes it at `63` bytes. Richer controls, shared descendants, external targets, and unsupported ordinary roots remain fail-closed before any flatten rewrite.

## Starshine catch-payload representation decision

Binaryen v130 represents a legacy catch payload as a typed `Pop` expression and repairs it with `handleBlockNestedPops(...)` after flatten may introduce blocks. Starshine's stack-oriented `lib` has no corresponding `Pop` instruction. The selected local bridge is therefore an explicit HOT catch-entry pseudo-value rather than a new public stack opcode:

- `hot_build_catch_payload(...)` creates one childless scalar `HotOp::Catch` value carrying its tag and exact type;
- every payload lane must be an ordered leading root of exactly one legacy catch region;
- HOT lowering treats those roots as values already present on the exception-handler stack and emits no standalone instruction for them;
- the bounded-path lowerer supports one scalar lane or any positive same-tag scalar lane vector by targeting a matching scalar or existing result-only multivalue handler block from `try_table`;
- normal completion branches over the handler, while exceptional transfer enters the handler with the payload.

This representation supports two source-backed Binaryen-equivalent entry extraction families without manufacturing a fake lib `Pop`. The scalar APIs retain the one-marker first-descendant contract and now follow direct blocks plus an `if` condition. `hot_ordered_catch_payloads_repairable(...)` and `hot_repair_ordered_catch_payloads(...)` admit any positive same-tag marker vector when either one exclusive direct block chain ends in the matching ordered lane roots or the first post-marker catch-region roots independently own those lanes. Each lane may then follow the exact first child of a non-control expression. Locals retain source lane order; capture roots run in reverse stack order; exact old positions become matching local reads. Internal flatten performs the complete transaction before ordinary rewrites and rebuilds its immutable analysis state afterwards.

A partial lane vector, mixed tag, then/else path, other non-first-descendant or repeated use, direct-root composition outside the exact first ordered lane roots, nested catch, loop/multiple execution, catch-all payload extraction, and sharing/outside ownership remain separately deferred. Direct exceptional transfer now handles any positive depth-zero catch-all rethrow population under one active catch through arbitrary strict direct resultless untargeted block/if ancestry, plus one direct scalar value-if arm whose opposite arm is a matching simple value, and an outer-target resultless delegate whose sole catch representation is either direct or a strict direct resultless single-root unused-label block chain. Nonzero depth, typed composition, loops, nested catches or nested tries, targeted or broader value-carrying ifs, and non-block/mixed/value-carrying/used-label/nested delegate populations keep the complete function unchanged before unrelated flatten mutation.

## First-child EH repair and active delegate ancestry

The ordered catch transaction now mirrors Binaryen v130's first-descendant walk more closely. After the leading same-tag payload markers and exclusive direct block chain are proven, each lane may descend through child zero of a non-control expression even when that expression has later children. Repair changes only the exact payload child to a local read; later children remain in place and ordinary flattening may independently spill the containing expression. Non-first children, repeated/shared/outside uses, loops, nested tries, try tables, mixed tags, and partial vectors still reject before mutation.

Delegation has two separately proven strict chains. Inside the delegated try's catch representation, only resultless single-root unused-label blocks may wrap the delegate. Outside the delegated try, resultless untargeted single-root blocks and if arms may connect it to the exact active target. Lowering preserves the outer controls and removes only the semantically empty catch wrappers and obsolete inner handler shell. Conditions, loops, value-carrying or targeted controls, nested tries, mixed catches, used labels, and non-active targets remain excluded.

These slices are covered by red-first whitebox transitions `196/197 -> 197/197` and `197/198 -> 198/198`; no public flatten or `.mbti` surface changed.

## Independent direct catch roots and scalar value-if rethrows

The newest catch transaction no longer treats all multi-lane independence as one blocker. After the leading same-tag markers, the first ordered direct catch roots may each own a different first-child line. This is still stack repair, not arbitrary code motion: captures are inserted in reverse stack order before the original roots, each exact old payload position becomes a source-ordered local read, and later roots or later expression children retain identity.

The newest exceptional-transfer subset composes the existing rethrow capture with scalar control-result routing. A direct `Rethrow(0)` arm contributes no fallthrough value; the opposite arm writes the matching scalar local, the value if becomes void, and the surrounding scalar legacy try writes/reads its own result channel. Admission proves that exact shape before mutation, so generic scalar-if routing cannot use a rethrow outside a supported active-catch population.

The red-first transitions are `198/199 -> 199/199` and `199/200 -> 200/200`. Final validation is HOT mutation `16/16`, HOT lower `89/89`, IR `326/326`, focused flatten `263/263`, passes `5,793/5,793`, and full `9,262/9,262`; public flatten remains removed.

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
