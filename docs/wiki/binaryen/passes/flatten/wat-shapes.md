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
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-pure-drop-suffix-refresh.md
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
  - ./flat-ir-contract-and-preludes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `flatten` WAT shapes

Use this page together with the direct tagged `version_129` URLs in [`./binaryen-strategy.md`](./binaryen-strategy.md), the current-main recheck in Binaryen current-main [`Flatten.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp), and the proof-surface map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

This page is a beginner-friendly shape catalog for the main `flatten` rewrite families. The broad direct upstream proof surface is `flatten_all-features.wast`; `flatten.wast` is only a small smoke file, and `flatten-eh-legacy.wast` carries the EH-specific proof lane. For the order in which Starshine should implement and validate these shapes, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The key question to ask in every case is:

- “does this child shape violate Flat IR?”

If yes, Binaryen tries to:

- compute it earlier,
- store it in a temp local,
- and leave behind a `local.get` or placeholder `unreachable`.

## Shape 1: simple nested arithmetic becomes a temp local

## Before

```wat
(func (result i32)
  (i32.add
    (i32.const 0)
    (i32.const 1)
  )
)
```

## After

```wat
(func (result i32)
  (local $tmp i32)
  (local.set $tmp
    (i32.add
      (i32.const 0)
      (i32.const 1)
    )
  )
  (return
    (local.get $tmp)
  )
)
```

## Why

- the function body itself cannot remain a concrete value expression in Flat IR
- so Binaryen computes the value first and returns a local read instead

## Shape 2: already-simple children stay simple

## Before

```wat
(i32.add
  (local.get $x)
  (i32.const 1)
)
```

## After

```wat
(i32.add
  (local.get $x)
  (i32.const 1)
)
```

## Why

- `local.get` and constants are already legal flat children
- flatten is aggressive, but not pointless

## Shape 3: value-carrying `block` becomes prelude block plus `local.get`

## Before

```wat
(i32.add
  (i32.const 0)
  (block (result i32)
    (i32.const 1)
  )
)
```

## After

```wat
(block
  (local.set $tmp0
    (i32.const 1)
  )
)
(local.set $tmp1
  (i32.add
    (i32.const 0)
    (local.get $tmp0)
  )
)
(local.get $tmp1)
```

## Why

- a value-carrying `block` cannot remain as a child
- flatten runs the block earlier as a prelude
- the outer consumer reads the temp instead

### Current Starshine multivalue block slice

Starshine routes a defaultable multivalue block when HOT exposes all result uses as one exclusive repeated consumer span. The branch-free family requires independently scalar tail results, except for one exact `tuple.make` tail whose ordered scalar children match the result vector, are already flat, and belong exclusively to that region tail. That tuple shell is scalarized into ordered typed local writes and deleted; shared, non-tail, mismatched, nondefaultable-reference, and other single-producer shapes remain gated. The plain-branch family admits terminal or nested `br` exits whose independently scalar payloads exactly match the block result vector, plus one exact exclusively owned `tuple.make` repeated across all HOT payload slots and scalarized to its ordered component children; mixed blocks may also retain independently scalar fallthrough tails. Every branch payload and fallthrough tail is stored once in source order into the same typed label locals before branch payloads and the block result are cleared. The consumer span becomes ordered `local.get` operands. Same-vector `br_if` is admitted only when each distinct payload has exactly one non-branch use and all false-path uses form one contiguous ordered block-tail span. Mismatched/shared `br_if`, `br_table`, shared consumers, and nonexclusive HOT ownership remain deferred rather than guessing result provenance.

## Shape 4: `if (result ...)` writes arm values into a temp

## Before

```wat
(drop
  (if (result i32)
    (i32.const 0)
    (then (i32.const 1))
    (else (i32.const 2))
  )
)
```

## After

```wat
(if
  (i32.const 0)
  (then
    (local.set $tmp
      (i32.const 1)
    )
  )
  (else
    (local.set $tmp
      (i32.const 2)
    )
  )
)
(drop
  (local.get $tmp)
)
```

## Why

- value-carrying `if` is forbidden in Flat IR
- both arms store into the same temp
- when an arm exits through a carried `br` or flows through a carried `br_if`, Starshine reuses that same target temp after preflighting the whole if-label use set
- the outer use sees only `local.get`

### Current Starshine multivalue if slice

Starshine routes defaultable multivalue `if` results when both arms end in independently scalar values matching the ordered result types or one exact exclusively owned `tuple.make` whose already-flat scalar children match that vector, terminal plain `br` exits with exact independently scalar payload vectors, or same-vector `br_if` flow whose distinct payloads have one exact contiguous false-path arm tail. Condition preludes remain before the `if`; fallthrough arms and branch exits write the same typed local vector in result order; routed branch payloads, the `if`, and label arity are cleared; and one exclusive repeated consumer reads ordered `local.get` nodes. Missing else arms, mismatched/shared `br_if`, `br_table` label uses, single multivalue arm producers, and shared/nonexclusive consumers remain fail-closed.

## Shape 5: condition preludes go before the whole `if`, arm preludes stay inside the arms

## Before

```wat
(if
  (call $cond)
  (then
    (drop (call $left))
  )
  (else
    (drop (call $right))
  )
)
```

## After shape

```wat
(local.set $condTmp
  (call $cond)
)
(if
  (local.get $condTmp)
  (then
    (local.set $leftTmp
      (call $left)
    )
    (drop (local.get $leftTmp))
  )
  (else
    (local.set $rightTmp
      (call $right)
    )
    (drop (local.get $rightTmp))
  )
)
```

## Why

- the condition executes before branch choice, so its preludes go outside
- arm-specific work must stay in the corresponding arm

## Shape 6: `local.tee` becomes set-prelude plus get

## Before

```wat
(i32.add
  (block (result i32)
    (local.tee $x
      (i32.const 0)
    )
  )
  (block (result i32)
    (local.tee $x
      (i32.const 1)
    )
  )
)
```

## After shape

```wat
(block
  (local.set $x
    (i32.const 0)
  )
  (local.set $tmp0
    (local.get $x)
  )
)
(block
  (local.set $x
    (i32.const 1)
  )
  (local.set $tmp1
    (local.get $x)
  )
)
(local.set $tmp2
  (i32.add
    (local.get $tmp0)
    (local.get $tmp1)
  )
)
(local.get $tmp2)
```

## Why

- Flat IR forbids `local.tee`
- flatten makes the write explicit and re-reads the value later
- this is one reason flatten creates many locals quickly

## Shape 7: `local.tee` with unreachable value collapses to unreachable

## Before

```wat
(drop
  (local.tee $x
    (unreachable)
  )
)
```

## After

```wat
(unreachable)
```

## Why

- if the value is already unreachable, the set never actually happens
- flatten drops the tee wrapper and keeps the real control effect

## Shape 8: carried `br_if` values go through explicit temps

## Before

```wat
(block $outer (result i32)
  (drop
    (br_if $outer
      (i32.const 4)
      (i32.const 1)
    )
  )
  (br $outer
    (i32.const 8)
  )
)
```

## After shape

```wat
(block $outer
  (local.set $targetTmp
    (i32.const 4)
  )
  (br_if $outer
    (i32.const 1)
  )
  ...
  (local.set $targetTmp
    (i32.const 8)
  )
  (br $outer)
)
(local.get $targetTmp)
```

## Why

- Flat IR does not want branches to carry arbitrary nested value trees directly
- the target temp becomes the explicit payload channel

### Current Starshine same-vector multivalue slice

For a defaultable block or if target whose result vector exactly matches the multivalue `br_if` payload vector, Starshine admits the route only when every distinct payload origin has exactly one non-branch use and those false-path uses form one contiguous ordered tail in the target region. It evaluates payloads once in source order into the target's typed local vector, replaces the false-path tail with matching reads, removes payload children from the branch, and keeps the condition in place. If control-result routing sees that exact local-read tail, it removes the tail instead of writing the same locals again. One exact exclusively owned `tuple.make` repeated across every branch slot and the contiguous false-path result span is also scalarized for block/if targets: ordered components write the shared target vector once, false flow becomes matching reads, the condition remains later, and the tuple shell is deleted. Vector mismatch, repeated/shared or noncontiguous flow uses, unsupported payload origins, and ambiguous conditional ownership remain fail-closed.

## Shape 9: `br_if` may need two temps when target type and flowing-out type differ

## Source-derived family

Binaryen documents a case like:

```wat
(block $any (result anyref)
  (block (result funcref)
    (local.tee $0
      (br_if $any
        (ref.null func)
        (i32.const 0)
      )
    )
  )
)
```

## Why it is tricky

- if the branch is taken, the carried value must match `$any`’s target type
- if the branch is not taken, the value may still flow out through the inner block’s type
- those types may differ

## Binaryen strategy

- one temp for the target block
- possibly one second temp for the still-flowing-out value

This is a very important correctness rule for a future port.

## Shape 10: `switch` / `br_table` value is copied to all unique targets

## Before

```wat
(br_table $a $b $c
  (i32.const 7)
  (local.get $index)
)
```

## After shape

```wat
(local.set $valueTmp
  (i32.const 7)
)
(local.set $tempForA
  (local.get $valueTmp)
)
(local.set $tempForB
  (local.get $valueTmp)
)
(local.set $tempForC
  (local.get $valueTmp)
)
(br_table $a $b $c
  (local.get $index)
)
```

## Why

- flatten does not know which target will be taken
- so it makes every target payload channel explicit

### Current Starshine multivalue table slice

For exact defaultable target vectors, Starshine stages each independently scalar payload component once in source order, deduplicates repeated labels, copies the staged vector once into every admitted nested block target, then evaluates any rich selector prelude. A nested target can feed its enclosing target only when HOT exposes one exclusive ordered repeated-control tail, which is replaced by the inner control plus matching local reads before the outer result is erased. This mirrors Binaryen v130's one concrete tuple staging value at HOT's ordered-child representation boundary. Exact inputful multivalue loop-plus-enclosing-block fanout is admitted when entries, payloads, and fallthrough tails are independently scalar. Exact loop-plus-repeated-control fanout is also admitted when one repeated exclusive block/if-result tail feeds the loop and the table may additionally target an enclosing block; staged payload, loop-entry, nested-control-result, enclosing-target, and loop-result locals remain distinct. One exact exclusively owned `tuple.make` repeated across every table payload slot is also scalarized when its ordered defaultable component vector matches every target: components stage once, unique target vectors receive local reads, selector work remains later, and the tuple shell is deleted. Broader mixed-control fanout, nested or nonexclusive conditional loop control, mismatched vectors, other single multivalue producers, and ambiguous ownership remain fail-closed. Source: [`../../../raw/binaryen/2026-07-13-flatten-version-130-switch-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-switch-refresh.md).

## Shape 11: inputful no-backedge loops separate entry and result channels

For a zero-input loop with independently scalar defaultable multivalue tails, payloadless backedges, and one exclusive repeated consumer span, Starshine writes each ordered result to the shared typed label-local vector, preserves payloadless loop control, clears the loop result arity, and replaces the consumer span with ordered local reads. For a typed loop with defaultable parameters and one scalar result, Starshine either evaluates independently scalar entries once in source order or scalarizes one exact tuple-made entry whose immediate reversed direct-drop prefix exclusively owns every lane. It stores the lanes in typed locals, redirects body uses through local reads, removes the loop parameter prefix, and routes the final result through a distinct temp. Payloadless zero-input backedges continue to work; independently scalar one- or multi-parameter `br`/`br_if` backedges write typed entry locals before branching, with rich payloads evaluated once in source order before the condition and reused on the false path. Independently scalar one- or multi-parameter loop-targeting `br_table` stages every payload once in source order, copies the vector into each unique target's entry locals, and evaluates its selector afterwards. An inputful multivalue-result loop is now admitted for exact independently scalar plain `br` backedges or one exact exclusively owned tuple-made plain `br` payload matching the loop parameter vector, plus same-vector `br_if` backedges from independently scalar or one exact exclusively owned tuple-made payload when the immediate reversed false path contains direct drops, exact single-use same-typed binary expressions with simple right operands, or exact single-use unary/conversion expressions, and the table-backed family, with independently scalar entries and either independently scalar fallthrough tails or one exact exclusive tuple-made result tail plus one exclusive outer consumer span. The table may target the loop entry vector plus an enclosing block vector, or one repeated exclusive block/if-result vector with an optional enclosing-block target; loop-result routing remains distinct, yielding separate staged-payload, entry, nested-control, enclosing-target, and result channels as applicable. Nondefaultable and multivalue single-producer table backedges remain whole-function fail-closed. Sources: [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-conditional-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-conditional-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-unary-convert-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-unary-convert-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-result-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-result-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-entry-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-entry-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-loop-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-loop-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md), and [`../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md).

## Shape 12: value-carrying `try` is flattened through a shared temp

## Before

```wat
(try (result i32)
  (do
    (i32.const 0)
  )
  (catch $e
    (pop i32)
  )
)
```

## After shape

```wat
(try
  (do
    (local.set $tmp
      (i32.const 0)
    )
  )
  (catch $e
    (local.set $popTmp
      (pop i32)
    )
    (local.set $tmp
      (local.get $popTmp)
    )
  )
)
(local.get $tmp)
```

## Why

- Flat IR forbids `try` from carrying a value directly
- flatten routes both the main body and catch body values through a temp

### Current Starshine legacy-try slice

Starshine routes defaultable legacy `try` results when both the do and catch regions have exact supported exits. Scalar results use one shared typed local. Named-target scalar support admits plain carried `br` exits after complete label-use preflight and one exact carried `br_if` family whose matching payload has exactly one immediate direct-drop, unary, conversion, or same-typed binary false-flow consumer with a simple opposite operand in the same arm; payload work stays before condition work, the false path reads the shared local, and every other arm remains an independently scalar matching fallthrough. Multivalue results use one shared typed vector and require one exclusive repeated HOT consumer or region-tail span so result ownership is unambiguous. The matching multivalue `br_if` slice accepts independently scalar lanes or one exclusively owned repeated `TupleMake`. Independently scalar lanes or one exclusively owned repeated `TupleMake` may use one immediate reversed span of direct drops or single-use exact unary/conversion consumers whose results are directly dropped. Independently scalar lanes and one exclusively owned repeated `TupleMake` also admit exact single-use same-typed binaries with simple right operands; trapping binaries remain after the branch. Payload components write the shared result vector once in source order, and false-flow inputs become reversed local reads without hoisting their consumers. Exact terminal scalar `br_table` slices allow one repeated try label or that try plus any complete strict direct-enclosure chain of matching defaultable block/if controls in structural order without a hardcoded count cap. Exact multivalue slices allow one repeated try label; independently scalar payloads may target the same arbitrary strict direct mixed order, including try-inside-if-inside-block; one exclusively owned repeated `TupleMake` may target the same arbitrary strict direct block/if ancestry after separate exclusive-ownership, component, one-evaluation, and safe-deletion preflight without a hardcoded count cap; both routes stage each lane before selector work and copy it into distinct per-label typed channels. Scalar and independently scalar terminal try tables also admit one exact inputful-loop ancestry when loop inputs exactly match the table payload, existing entry/backedge/result preflight succeeds, and loop-entry locals remain distinct from try and loop-result channels; one exclusively owned repeated-HOT-`TupleMake` payload admits the same loop ancestry after separate component-order, exact-use, one-evaluation, type/defaultability, loop-backedge, and safe-deletion proof. A supported try table may also be followed in the same arm by any number of direct `Unreachable` roots or one exact exclusively owned direct `drop(const)` root; those exact detached nodes are removed during routing before the existing terminal result proof runs. Multivalue try fallthrough uses an exclusive repeated-control tail before copying into the block vector. The exact named-target multivalue slice admits only plain `br` uses whose payload is an independently scalar exact vector or one exclusively owned repeated `TupleMake`; ordered defaultable lanes write the shared vector before the payload-free branch, while either try arm may still use independently scalar or separately owned tuple-made fallthrough tails. Each arm may independently use scalar tails or a separately owned exact `TupleMake` tail whose ordered defaultable scalar components match that vector and have supported non-control origins. Rich tuple components spill once in source order inside their own region before the tuple shell is replaced by shared-vector writes and deleted, so mixed tuple/scalar arms still feed one shared result vector. Each region writes its tails in source order, the `try` becomes void, and the outer consumer reads matching `local.get` nodes. The whole function remains pre-gated when legacy EH repair-sensitive `Catch`/`CatchAll`, `rethrow`, or `delegate` nodes are present. `flatten_eh_repair_requirement(...)` records whether typed catch-payload tracking or exceptional-transfer repair is missing; current HOT/lib has no first-class Binaryen-style payload `Pop`. Binaryen-equivalent entry extraction and nested-pop repair are still required before those catch shapes can be admitted. Broader mixed-target table try exits, shared/mixed tuple table payloads, nonterminal tables with any non-`Unreachable` suffix root other than the exact owned `drop(const)` family, shared/mixed tuple branch ownership, reversed/rich-right binary, non-immediate/shared, or nested conditional false flow, and arbitrary single multivalue producers remain gated. Sources: [`../../../raw/binaryen/2026-07-13-flatten-version-130-try-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-try-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-try-conditional-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-try-conditional-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-unary-convert-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-unary-convert-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-reversed-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-reversed-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-two-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-two-block-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-tuple-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-tuple-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-tuple-refresh.md), and [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-break-refresh.md).

## Shape 13: flatten may create blocks inside `catch`, so EH pop fixup is required

## Before

```wat
(block $l0
  (try
    (do)
    (catch $e-i32
      (drop (pop i32))
      (br $l0)
    )
  )
)
```

## After shape

The exact output is verbose, but the key source-backed facts are:

- flatten inserts extra block structure in the catch body
- the `pop` is rewritten through locals
- then Binaryen repairs the nested-pop placement afterwards with `EHUtils::handleBlockNestedPops(...)`

## Why

- without that repair step, the resulting EH structure would be invalid
- Starshine currently classifies this prerequisite and fails closed; it does not yet represent the typed payload `pop` needed to perform the move

## Shape 14: real control effects become preludes plus placeholder `unreachable`

## Before

```wat
(select
  (i32.const 0)
  (i32.const 1)
  (br_table 0 (i32.const 7) (i32.const 1))
)
```

## After shape

```wat
(block
  (local.set $targetTmp
    (i32.const 7)
  )
  (br_table 0
    (i32.const 1)
  )
  (select
    (i32.const 0)
    (i32.const 1)
    (unreachable)
  )
  (unreachable)
)
(local.get $targetTmp)
```

## Why

- the real control effect must still happen
- but Flat IR cannot keep that control effect nested in the old child slot
- so Binaryen keeps the real effect in earlier code and leaves a placeholder `unreachable`
- Starshine now implements this owner-local shape for nested terminal `br`, `br_table`, `return`, `return_call`, `return_call_indirect`, `return_call_ref`, `throw`, and `throw_ref`, including HOT cases where the real terminal is already an earlier region root and must not be duplicated; branch payloads, tail-call operands, and throw arguments are flattened before the terminal in source order and later sibling preludes remain later

## Shape 15: selective non-null support is real

## Before

```wat
(func (param $0 (ref $simplefunc)) (result (ref $simplefunc))
  (local.get $0)
)
```

## After

```wat
(func (param $0 (ref $simplefunc)) (result (ref $simplefunc))
  (local $1 (ref $simplefunc))
  (local.set $1
    (local.get $0)
  )
  (return
    (local.get $1)
  )
)
```

and also:

```wat
(func (result funcref)
  (ref.as_non_null
    (ref.null $none_=>_none)
  )
)
```

becoming a temp-local-returned shape in `flatten_all-features.wast`.

## Why

- some non-null families already work in shipped tests
- that means the open non-nullability TODO is narrower than a blanket “all non-null values are unsupported” claim

## Shape 16: unsupported `BrOn*` and `TryTable` are hard stop families

## Family

- `br_on_null`
- `br_on_non_null`
- `br_on_cast`
- `br_on_cast_fail`
- `try_table`

## Current `version_130` behavior

- every `BrOn` variant exits with `Unsupported instruction for Flatten`
- a direct `try_table` probe reaches the earlier unhandled control-structure arm and aborts with `unexpected expr type` / `UNREACHABLE`

## Current internal Starshine policy

- `FlattenRunAdmission::UpstreamHardUnsupported` is selected before any mutation
- `flatten_run(...)` returns unchanged while the pass remains public-removed
- whitebox coverage proves an otherwise flattenable rich operand is not partially rewritten for any of the five families
- public admission remains blocked because an unchanged internal result does not yet match Binaryen's observable failure contract

Source: [`../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md).

## Bottom line

The simplest pattern summary is:

- simple children stay simple
- rich value-producing children become temp locals
- control-flow results become explicit local channels
- tee and branch payloads become explicit local traffic
- real control effects survive as preludes plus placeholder `unreachable`
- and some feature families are still a hard unsupported boundary
