---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
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

For a zero-input loop with independently scalar defaultable multivalue tails, payloadless backedges, and one exclusive repeated consumer span, Starshine writes each ordered result to the shared typed label-local vector, preserves payloadless loop control, clears the loop result arity, and replaces the consumer span with ordered local reads. For a typed loop with defaultable parameters and one scalar result, Starshine either evaluates independently scalar entries once in source order or scalarizes one exact tuple-made entry whose immediate reversed direct-drop prefix exclusively owns every lane. It stores the lanes in typed locals, redirects body uses through local reads, removes the loop parameter prefix, and routes the final result through a distinct temp. Payloadless zero-input backedges continue to work; independently scalar one- or multi-parameter `br`/`br_if` backedges write typed entry locals before branching, with rich payloads evaluated once in source order before the condition and reused on the false path. Independently scalar one- or multi-parameter loop-targeting `br_table` stages every payload once in source order, copies the vector into each unique target's entry locals, and evaluates its selector afterwards. An inputful multivalue-result loop is now admitted for exact independently scalar plain `br` backedges or one exact exclusively owned tuple-made plain `br` payload matching the loop parameter vector, plus same-vector `br_if` backedges from independently scalar or one exact exclusively owned tuple-made payload when the immediate reversed false path contains direct drops, exact single-use same-typed binary expressions with a simple opposite operand or one exact one-use rich right operand when the restored payload is left, or exact single-use unary/conversion expressions, and the table-backed family, with independently scalar entries and either independently scalar fallthrough tails or one exact exclusive tuple-made result tail plus one exclusive outer consumer span. The table may target the loop entry vector plus an enclosing block vector, or one repeated exclusive block/if-result vector with an optional enclosing-block target; loop-result routing remains distinct, yielding separate staged-payload, entry, nested-control, enclosing-target, and result channels as applicable. Nondefaultable and multivalue single-producer table backedges remain whole-function fail-closed. Sources: [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-conditional-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-conditional-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-unary-convert-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-unary-convert-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-result-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-result-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-entry-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-entry-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-loop-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-loop-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md), and [`../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md).

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

Starshine routes defaultable legacy `try` results when both the do and catch regions have exact supported exits. Scalar results use one shared typed local. Named-target scalar support admits plain carried `br` exits after complete label-use preflight and one exact carried `br_if` family whose matching payload has exactly one immediate direct-drop, unary, conversion, or same-typed binary false-flow consumer with a simple opposite operand in the same arm; payload work stays before condition work, the false path reads the shared local, and every other arm remains an independently scalar matching fallthrough. Multivalue results use one shared typed vector and require one exclusive repeated HOT consumer or region-tail span so result ownership is unambiguous. The matching multivalue `br_if` slice accepts independently scalar lanes or one exclusively owned repeated `TupleMake`. Independently scalar lanes or one exclusively owned repeated `TupleMake` may use one immediate reversed span of direct drops or single-use exact unary/conversion consumers whose results are directly dropped. Independently scalar lanes and one exclusively owned repeated `TupleMake` also admit exact single-use same-typed binaries with a simple opposite operand, one exact one-use rich right operand when the restored payload is left, or one exact one-use pre-branch rich left when the restored payload is right and every rich origin in the complete payload vector is individually supported. The rich-left rule covers legacy tries and the exact inputful-loop counterpart, pairs only with lane zero, and keeps trapping binaries after the branch. Payload components write the shared result vector once in source order, and false-flow inputs become reversed local reads without hoisting their consumers. Exact terminal scalar `br_table` slices allow one repeated try label or that try plus any complete strict direct-enclosure chain of matching defaultable block/if controls in structural order without a hardcoded count cap. Exact multivalue slices allow one repeated try label; independently scalar payloads may target the same arbitrary strict direct mixed order, including try-inside-if-inside-block; one exclusively owned repeated `TupleMake` may target the same arbitrary strict direct block/if ancestry after separate exclusive-ownership, component, one-evaluation, and safe-deletion preflight without a hardcoded count cap; both routes stage each lane before selector work and copy it into distinct per-label typed channels. Scalar and independently scalar terminal try tables also admit one exact inputful-loop ancestry when loop inputs exactly match the table payload, existing entry/backedge/result preflight succeeds, and loop-entry locals remain distinct from try and loop-result channels; one exclusively owned repeated-HOT-`TupleMake` payload admits the same loop ancestry after separate component-order, exact-use, one-evaluation, type/defaultability, loop-backedge, and safe-deletion proof. A supported try table may also be followed in the same arm by any number of direct `Unreachable` roots, any positive number of exclusively owned distinct direct `drop(const)` roots, either exact two-root mixed order of direct `drop(const)` and direct `Unreachable`, either exact two-root mixed order of direct `drop(i32.add(const, const))` and direct `Unreachable`, any positive ordered sequence whose roots are independently owned direct `drop(const)`, direct `Unreachable`, or independently owned direct `drop(i32.add(const, const))`, `drop(i32.sub(const, const))`, `drop(i32.mul(const, const))`, `drop(i32.and(const, const))`, `drop(i32.clz(const))`, `drop(i64.extend_i32_s(const))`, or `drop(i32.div_s(const, const))`, or exact owned direct resultless calls with zero arguments, any positive vector of distinct scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exact scalar constant, `i32.add(const, const)`, `i32.div_s(const, const)`, `i32.clz(const)`, or `i64.extend_i32_s(const)` argument, or exact one- or two-multiply-child outer-add or outer-subtract drop trees with constant leaves, or one exact bounded outer add/subtract tree combining a matching two-multiply-child subtree and one direct constant; separately admitted single-root suffixes include `drop(i32.sub(const, const))`, any positive number of independently owned direct `drop(i32.mul(const, const))` roots, `drop(i32.and(const, const))`, `drop(i32.clz(const))`, `drop(i64.extend_i32_s(const))`, or `drop(i32.div_s(const, const))` root, plus exact owned direct resultless calls with zero arguments, any positive vector of distinct exclusively owned scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct exclusively owned scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exclusively owned scalar constant, exact `i32.add(const, const)`, exact `i32.div_s(const, const)`, exact `i64.extend_i32_s(const)`, or exact `i32.clz(const)` argument through admitted try-table ancestries; those exact detached nodes are removed during routing before the existing terminal result proof runs. Structured suffix roots use verified descendant-plus-owned-label forest deletion only for the exact admitted block/if/loop shapes; richer, shared, externally targeted, inputful, value-carrying, or try-like controls remain fail-closed. Multivalue try fallthrough uses an exclusive repeated-control tail before copying into the block vector. The exact named-target multivalue slice admits only plain `br` uses whose payload is an independently scalar exact vector or one exclusively owned repeated `TupleMake`; ordered defaultable lanes write the shared vector before the payload-free branch, while either try arm may still use independently scalar or separately owned tuple-made fallthrough tails. Each arm may independently use scalar tails or a separately owned exact `TupleMake` tail whose ordered defaultable scalar components match that vector and have supported non-control origins. Rich tuple components spill once in source order inside their own region before the tuple shell is replaced by shared-vector writes and deleted, so mixed tuple/scalar arms still feed one shared result vector. Each region writes its tails in source order, the `try` becomes void, and the outer consumer reads matching `local.get` nodes. The whole function remains pre-gated for every unsupported legacy EH population. `flatten_eh_repair_requirement(...)` distinguishes catch-payload from exceptional-transfer work; the typed HOT entry markers plus generic transaction now admit scalar first-descendant paths through direct blocks or an `if` condition and arbitrary ordered same-tag direct-block-chain lane vectors, while partial/mixed-tag vectors, then/else paths, other non-first-descendant or repeated uses, broader lane paths, nested catches, loops/multiple execution, catch-all payloads, and sharing/outside ownership remain deferred. Exceptional transfer separately admits any positive depth-zero catch-all rethrow population through arbitrary strict direct resultless untargeted block/if ancestry and one resultless outer-target delegate whose sole catch representation is direct or a strict direct resultless single-root unused-label block chain; broader populations remain deferred. Broader mixed-target table try exits, shared/mixed tuple table payloads, nonterminal tables with any non-`Unreachable` suffix roots other than any positive number of exclusively owned distinct direct `drop(const)` roots, either exact two-root mixed order of direct `drop(const)` and direct `Unreachable`, either exact two-root mixed order of direct `drop(i32.add(const, const))` and direct `Unreachable`, any positive ordered sequence whose roots are independently owned direct `drop(const)`, direct `Unreachable`, or independently owned direct `drop(i32.add(const, const))`, `drop(i32.sub(const, const))`, `drop(i32.mul(const, const))`, `drop(i32.and(const, const))`, `drop(i32.clz(const))`, `drop(i64.extend_i32_s(const))`, or `drop(i32.div_s(const, const))`, or exact owned direct resultless calls with zero arguments, any positive vector of distinct scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exact scalar constant, `i32.add(const, const)`, `i32.div_s(const, const)`, `i32.clz(const)`, or `i64.extend_i32_s(const)` argument, or exact one-multiply-child outer-add or outer-subtract drop trees with the multiply on either side, or one exact owned richer `drop` family, `drop(i32.add(const, const))`, either `drop(i32.add(const, i32.mul(const, const)))` or `drop(i32.add(i32.mul(const, const), const))`, `drop(i32.sub(const, const))`, any positive number of independently owned direct `drop(i32.mul(const, const))` roots, `drop(i32.and(const, const))`, `drop(i32.clz(const))`, `drop(i64.extend_i32_s(const))`, `drop(i32.div_s(const, const))`, zero-argument void-call, one-scalar-constant-argument void-call, one-exact-add-argument void-call, one-exact-trapping-binary-argument void-call, one-exact-signed-conversion-argument void-call, and one-exact-unary-argument void-call families, shared/mixed tuple branch ownership, multiple or non-lane-zero rich-left flow, non-immediate/shared, or nested conditional false flow, and arbitrary single multivalue producers remain gated. Sources: [`../../../raw/binaryen/2026-07-13-flatten-version-130-try-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-try-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-try-conditional-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-try-conditional-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-unary-convert-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-unary-convert-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-reversed-binary-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-reversed-binary-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-two-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-two-block-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-table-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-table-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-tuple-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-tuple-refresh.md), [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-tuple-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-tuple-refresh.md), and [`../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-break-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-break-refresh.md).

### Current Starshine recursive dead-call argument slice

After an unconditional legacy-try `br_table`, Starshine can delete one exact owned resultless direct call whose supported immediate arguments contain recursively owned audited expression trees, with any number of distinct scalar constants at other immediate positions. The former one-multiply, two-multiply, and bounded-deeper shapes remain examples rather than depth caps:

```wat
(call $dead
  (i32.add
    (i32.mul (i32.const 9) (i32.const 10))
    (i32.const 11)))
```

```wat
(call $dead
  (i32.sub
    (i32.mul (i32.const 9) (i32.const 10))
    (i32.mul (i32.const 11) (i32.const 12))))
```

```wat
(call $dead
  (i32.add
    (i32.add
      (i32.mul (i32.const 9) (i32.const 10))
      (i32.mul (i32.const 11) (i32.const 12)))
    (i32.const 13)))
```

The call and complete subtree are deleted only after immediate argument order, nested left-to-right order, distinctness, one-use ownership, and unconditional transfer are proven. Direct `i32.sub`, `i32.mul`, `i32.and`, `i32.or`, `i32.xor`, `i32.shl`, `i32.shr_s`, and `i32.shr_u` roots use the same proof; `i32.rotl` is the current outside-roster boundary. Admission caches exact owned nodes and owner regions from one lightweight reachable node-use-count snapshot, label-use facts once per rewrite state, and exact terminal-table support keyed by table, label, payload arity, and mixed-target policy; mutation fails closed on a missing exact cache. After same-region suffix detachment, the complete distinct owned vector tombstones with one revision invalidation.

Three exact structured suffix root kinds are now admitted too: one void block with direct `drop(const)`, one constant-condition void if with complete direct `drop(const)` arms, and one zero-input/no-backedge void loop with a direct `drop(const)` body. The table is unconditional, so none can execute. Starshine accepts one root, a positive control-only vector, or a vector that mixes these controls with any existing exactly recognized ordinary dead-suffix roots. It requires complete exclusive nonoverlapping descendants, live labels owned by each control or if-region holder, and no outside branch/delegate/try-table-catch user before detaching and atomically tombstoning the entire forest and labels in one revision.

Pinned Binaryen v130 keeps all three control kinds under direct flatten; the fresh `drop(const) + block + if + loop + unreachable` probe is retained at `76` bytes, while matched `--vacuum --dce` removes it at `63` bytes. Nonconstant/effectful or partial ifs, inputful/value loops, backedges, external targets, sharing, and unsupported ordinary or structured roots remain gated. Nonthrowing synthetic catch-all lowering keeps the refreshed three-probe cleanup matrix a measured 24-byte Starshine win, while current candidate-dense pass-local performance remains `3.65x` Binaryen and blocks public exposure. See the [current impact evidence](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md).

### Current branch-index and tail-write implementation detail

Admission precomputes the exact branch-like nodes targeting each label, deduplicating a `br_table` that repeats the same label in explicit and default positions. Result routing still performs the same ordered `local.set` transformation shown above, but a one-for-one region tail changes only that root slot; sibling roots are not copied into a rebuilt child array. For an admitted unconditional table followed by exact owned unreachable debris, suffix roots are detached by shortening the existing holder span before batch deletion instead of rebuilding its prefix. Scalar, multivalue block/if, and multivalue legacy-try mutation-time branch checks keep using the pre-mutation target-node population even after new nodes are allocated during rewriting. For multivalue `br_table`, each unique target's complete typed local vector is resolved once after all target/type/control proof succeeds and then reused for every payload lane.

For the tuple-made legacy-try and loop `br_if` shapes above, exact two-use tuple/payload ownership and one-use intermediate consumer ownership now come from the lightweight reachable count snapshot. Exact tuple-made block/if/loop/try region tails use the same snapshot: because the tuple is already observed at the exact tail root and slot, total use count one is sufficient to prove exclusive ownership. Inputful-loop `br_if` and general backedge support iterate the exact pre-mutation branch population for the loop label rather than every live node.

Tuple-made inputful-loop entries now use that snapshot too: the tuple must appear in every entry slot and every immediate reversed body-prefix drop, with no other reachable use. Scalar legacy-try `br_if` false flow similarly requires exactly the branch use plus one adjacent consumer; a unary, conversion, or binary consumer remains one-use and structurally audited. Tuple-made plain `br`/`br_table` payloads use exact total count equal to payload arity because their branch slots are already known. Generic tuple-made and distinct non-tuple block/if `br_if` now cache exact contiguous false-flow parents during admission, and rewrite cannot discover a new site after mutation begins. Scalar flow caches exact parent populations instead of fixed slots because inserted preludes can shift holder positions; rewrite searches only those parents and requires the same occurrence count. The output shape is unchanged: entry/payload lanes still stage once in source order, false-flow consumers stay after the conditional branch, and try/loop result channels remain distinct. These implementation details are guarded by red-first invariants and do not change the WAT-level transform contract or admit any new opcode/control family.

### Latest sparse-cache implementation detail

The WAT-level shapes above are unchanged by commits `e165fde1c` and `476848f9d`. Instead of allocating proof slots for every HOT node, admission appends exact entries only for inspected conditional branches, flowing values, terminal tables, dead suffix owners, and scalar tries. Tuple and distinct multivalue negative flow results are still cached explicitly; scalar `br_if` still freezes exact parent populations; terminal entries still bind table, label, payload arity, and mixed-target policy; suffix entries still bind the exact region and owned nodes. Rewrite cannot discover a missing entry after mutation starts. The red-first invariants pass at private flatten `161/161`; no new opcode, control, payload, EH, or deletion shape is admitted.

### Latest recursive-dispatch and shared-root implementation detail

Commits `7801166ac` and `18101a947` do not alter any WAT shape above. Payload-bearing `br_if` and `br_table` are still routed in their dedicated recursive arms; the generic postorder tail now dispatches only a carried plain `br`. Sequence-root identity is still the mechanism that prevents a terminal already present as an earlier root in the same owner region from being emitted again under a later operand, but unique roots are no longer stored. Only nodes with multiple reachable owners in the immutable pre-mutation count snapshot are retained, and ids allocated after that snapshot cannot query it.

The red-first shared-root invariant uses 256 unique roots, one branch that is both an earlier root and a later `select` child, and one post-snapshot node. Rewrite retains exactly the branch's holder/node pair and leaves one placeholder `unreachable` without duplicating the branch. Native measurement found an `8.86%` targeted traversal win from postorder dispatch narrowing; shared-root storage was timing-flat but reduced the invariant's bookkeeping from every root to the single shared root. No opcode, control, payload, EH, type, effect, trap, or deletion family was admitted.

### Latest one-target table and inputful-loop support detail

When all explicit/default `br_table` labels deduplicate to one target, Starshine now writes each payload lane directly into that target's resolved local vector before selector work. The WAT-level behavior is unchanged, but the intermediate shape drops one staging local and one `local.get`/`local.set` copy per lane. Multi-target tables still stage once and fan out to every unique target. A focused scalar encoded module shrinks from `51` to `47` bytes, and existing scalar, tuple, loop, legacy-try, suffix, and placeholder tests lock the reduced root counts and exact target-local identity.

Inputful-loop support is now also a frozen admission fact. Exact parameter/result types, entry and backedge ownership, conditional flow, label branches, and result tails are checked before mutation; rewrite cannot discover a new supported loop after that boundary. This changes no WAT family and measured timing was flat, but it closes another stale-proof path.

### Latest branch-index and admission-roster implementation detail

Commits `6a74918d6` and `1acb9bc14` do not alter any WAT shape above. The immutable label index now records a branch node once per targeted label without scanning earlier users: repeated/default labels emitted by the same node are suppressed by a per-label last-node guard, while later nodes remain in HOT id order. The same scan records exact loop, legacy-try, and payload-bearing branch candidates for admission.

All family-specific target, type, ownership, false-flow, EH, effect, trap, and deletion checks remain unchanged. The only behavior is less rediscovery: admission iterates exact candidate rosters rather than all live nodes three more times. The red-first roster invariant excludes 256 unrelated roots, and targeted native-release fixtures improve `13.72%` and `6.45%`. No opcode, control, payload, EH, or output family is admitted.

### Latest EH-prerequisite and flatness scan-sharing detail

Commits `7706110c1` and `2c5a54ac3` do not alter any WAT shape above. The immutable pre-mutation scan now records exact `Catch`/`CatchAll` payload-repair and `Rethrow`/`Delegate` exceptional-transfer requirements, plus the complete Flat IR violation report. `Delegate` continues to enter the label branch index while selecting the exceptional-transfer gate. `flatten_run` consumes the frozen indexed report; standalone classification uses the same per-live-node and body-tail logic.

The red-first invariants compare the indexed and standalone facts in functions padded with 256 unrelated roots. Every family-specific label, type, ownership, EH, effect, trap, control-result, deletion, and mutation-time failure boundary is unchanged. Code 1 improves one reconstructed representative by `6.28%`; code 2 has no stable timing win. No opcode, control, payload, EH-repair, or output family is admitted.

### Latest sparse proof lookup detail

Commits `c420a9950` and `9b5c4170a` do not alter any WAT shape above. Scalar legacy-try, dead-suffix, and terminal-table decisions remain sparse exact proof entries; they are now sorted by the corresponding pre-mutation try/table id and located with binary search. The entries still retain every semantic discriminator used before the change, and a missing entry after rewriting starts still rejects the route.

The red-first invariants create or inspect three owners out of order and require sorted exact lookup. Candidate-dense native-release timing improves `5.99%` for scalar tries and `58.49%` for terminal tables, while representative samples overlap by order. No opcode, control, payload, EH, type, effect, trap, ownership, deletion, or output family is admitted.

### Latest inputful-loop and scalar-flow lookup detail

Commits `e32819f5b` and `fc5c89bff` also leave every WAT shape above unchanged. Inputful-loop support entries are now sorted by exact pre-mutation loop id. Scalar `br_if` flow-site entries are sorted by branch id, and same-state replacement entries are sorted by original value id. Binary lookup replaces linear scans, but admission still proves exact loop types/entries/backedges/results or exact scalar parent populations, and rewrite still rechecks current structure and rejects a missing pre-mutation entry. Replacement entries retain update behavior for a value already replaced by the same state.

The red-first invariants queried three candidates out of order and failed on append order before implementation. Fixed-total native-release density fixtures improve inputful loops `9.57%` and scalar flow `3.34%` at 128 candidates per function. No opcode, control, payload, EH, type, effect, trap, ownership, deletion, or output family is admitted.

### Latest tuple and distinct multivalue conditional-flow lookup detail

Commits `80e6a652b` and `efb8fdfa2` leave every WAT shape above unchanged. Tuple-made and distinct non-tuple block/if `br_if` flow proofs remain sparse exact admission entries, now sorted by exact pre-mutation branch id and located with binary search. Explicit negative flow results remain cached; rewrite still validates the current cached parent and contiguous slots and refuses an absent entry after mutation begins.

The red-first invariants queried three branches out of order and failed on append order before implementation. Exact cached-lookup timing improves `47.34%` for tuple flow and `66.89%` for distinct flow at 512 candidates. No opcode, control, payload, EH, type, effect, trap, ownership, deletion, or output family is admitted.

### Latest table-target and terminal-payload lookup detail

Commits `bdad9efaf` and `902848fca` leave every WAT shape above unchanged. Unique `br_table` targets are still emitted in first explicit-target order with a previously unseen default target last; a label-sized mark set now suppresses repeats instead of rescanning the growing output. Terminal payload roots still identify exact pre-mutation values that must be removed from a region after payload staging; they are now stored sparsely in node-id order and queried with binary search.

The red-first invariants lock target order, duplicate and invalid-label handling, sparse payload order, duplicate rejection, and exact present/absent membership. Dense targeted timing improves target extraction `437,000 -> 16,000 us` and payload membership `110,000 -> 20,000 us` at 512 candidates. No opcode, control, payload, EH, type, effect, trap, ownership, deletion, or output family is admitted.

### Latest immutable-index and reusable-scratch detail

The allocation/index follow-up leaves every WAT shape above unchanged. Table targets retain first explicit-target order and unseen-default-last semantics but are frozen once per side table. Lazy structural-parent queries, node-generation marks, depth-indexed prelude buffers, direct target-local retrieval, and type-result caching alter only internal proof/query storage. Prelude buffers are safe to reuse because HOT splicing copies ids; target-local allocation remains all-target failure-atomic; post-boundary cache absence still rejects.

Private flatten reaches `182/182`, and the owner microbenchmarks improve ancestry `76.22%`, table targets `96.88%`, type results `73.33%`, target-local preflight `11.69%`, and prelude-heavy traversal `9.68%`. No opcode, control, payload, EH, type, effect, trap, ownership, deletion, or output family is admitted.

### Latest sequenced-root and multivalue-payload lookup detail

Commits `4a03de7f3` and `aa295d38b` leave every WAT shape above unchanged. Shared terminal roots still avoid duplicate emission only when the frozen pre-mutation use count proves multiple owners in the same exact holder; sorted pair storage and binary membership change only lookup. Multivalue `br_if` payloads still preserve source order and exact cached false-flow placement; a temporary mark set now rejects repeated payload ids and identifies payload roots without scanning the growing vector.

The red-first invariants lock exact mixed-order holder/node pairs, cross-pair absence, payload mark population, and duplicate payload rejection. At 512 candidates, targeted medians improve sequenced-root lookup `91.56%` and payload distinctness `95.73%`. No opcode, control, payload, EH, type, effect, trap, ownership, deletion, or output family is admitted.

### Latest multivalue flow-index detail

Commits `f1dc57565` and `24b909b2d` leave every WAT shape above unchanged. Distinct non-tuple `br_if` payload nodes now carry one query-local source-slot index during reachable flow discovery, and tuple-made false-flow child slots use one parent-sized duplicate mark array. The ordered payload/slot vectors remain available for the exact final checks.

The red-first invariants lock sparse source positions, duplicate payload/slot rejection, bounds rejection, and first-position order. At 512 candidates, targeted medians improve non-tuple flow indexing `97.92%` and tuple slot distinctness `97.71%`. Exact payload counts, branch-slot coverage/exclusion, one non-branch parent, contiguous order, cached parent/start/current-slot checks, types, ownership, EH, effects, traps, deletion, and post-boundary failure behavior are unchanged. No opcode, control, payload, EH, type, effect, trap, ownership, deletion, or output family is admitted.

### Reversed binary false-flow operands

The immediate multivalue false-path binary families above now admit the restored lane on either side:

```wat
(i32.sub
  (i32.const 20)
  (local.get $restoredLane)
)
```

The same exact rule applies when HOT repeats one exclusively owned `TupleMake` across the branch payload slots and immediate consumers. The opposite operand must already be Flat-IR-simple; the binary must be single-use, exact, same-typed, immediately dropped, and remain after the conditional branch. Only the payload child is replaced. Rich siblings, nested or delayed consumers, sharing, mixed tuple/scalar ownership, and type-changing binaries remain fail-closed.

### Rich right operands

When the restored lane is the left child, the right child may now be one exact one-use supported scalar origin:

```wat
(br_if $target ...)
(local.set $right
  (call $rightOperand))
(local.set $result
  (i32.add
    (local.get $restoredLane)
    (local.get $right)))
```

This shape is admitted for independently scalar lanes and one exclusively owned repeated `TupleMake`; the shared exact consumer helper also serves admitted inputful-loop flow. Binaryen v130 legacy-try and loop probes place the rich right call after `br_if`, so Starshine's ordinary operand prelude preserves the not-taken-only effect/trap boundary.

### One exact rich left operand

When the restored lane is the right child, one source-representable rich left may instead execute before the whole payload vector:

```wat
(local.set $left
  (call $leftOperand))
(local.set $lane0 ...)
(local.set $lane1 ...)
(br_if $target ...)
(drop (local.get $lane1))
(local.set $result
  (i32.sub
    (local.get $left)
    (local.get $lane0)))
```

This exact shape is admitted for legacy tries and inputful loops with independently scalar lanes or one exclusively owned repeated `TupleMake`. Either control family may contain any number of rich payload origins when every origin is individually supported and the complete vector satisfies its exact ownership proof. Source stack order still permits only one rich left before all payloads, so it pairs only with lane zero after higher lanes are consumed in reverse order. Four pinned Binaryen v130 probes place `call $left` before all rich payload calls in vector order, then the condition and payload-free `br_if`, while the binary remains after the branch. Loop admission freezes the exact branch root and rich-left/binary identities before entry-channel mutation; both tuple routes insert the left store before child-generated payload preludes and delete the shell only after complete replacement. Multiple or non-lane-zero rich lefts remain fail-closed.

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
- a pinned Binaryen v130 direct probe stages `(pop i32)` into a fresh local before the original drop
- Starshine represents bounded-path typed payload reads as ordered HOT catch-entry values: scalar direct-block/if-condition and arbitrary ordered same-tag lane-vector repairs are admitted, while unsupported `Catch`/`CatchAll` populations select `DeferredCatchPayloadRepair`; exceptional transfer separately admits only the direct rethrow/delegate subsets in Shape 19, with broader populations selecting `DeferredExceptionalTransferRepair`

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

## Current Starshine policy

- `FlattenRunAdmission::UpstreamHardUnsupported` is selected before any mutation;
- `flatten_run(...)` returns unchanged under an intentional fail-atomic unsupported boundary;
- whitebox coverage proves an otherwise flattenable rich operand is not partially rewritten for any of the five families;
- the public pass remains active for admitted modules, while these Binaryen-hard families stay explicitly outside the admitted compare contract rather than being misclassified as parity.

Source: [`../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md).

## Shape 17: exact dead structured suffixes may be deleted after unconditional table transfer

Current internal Starshine admits three exact resultless control kinds after an unconditional legacy-try `br_table`, either alone, in any positive control-only suffix vector, or mixed with ordinary roots already accepted by exact dead-suffix recognizers:

```wat
(block $dead (drop (i32.const 9)))

(if $dead (i32.const 1)
  (then (drop (i32.const 9)))
  (else (drop (i32.const 10))))

(loop $dead (drop (i32.const 9)))
```

The `if` must have a constant condition, complete direct arms, exclusive descendants, and no users of its control or region labels. The `loop` must be zero-input, void, have no backedge or other label user, and contain exactly one direct `drop(const)`. The whole suffix is unreachable because the preceding table always transfers. Starshine preflights every ordinary and structured root from immutable facts, detaches the complete suffix once, and atomically deletes the descendant/label forest with one revision advance. Duplicate/overlapping roots, cross-tree sharing, cycles, outside owners, incomplete labels, and outside branch/delegate/try-table-catch users reject before mutation. Fresh Binaryen v130 retains an ordered `drop(const) + block + if + loop + unreachable` suffix under direct flatten at `76` bytes; matched `--vacuum --dce` removes it at `63` bytes. Nonconstant/effectful conditions, partial/richer arms, inputful/value loops, sharing, external targets, and unsupported ordinary or structured roots remain gated.

## Shape 18: Starshine models legacy catch payload `pop` as catch-entry values

Binaryen's legacy IR writes a typed payload read as `(pop i32)` or a tuple-typed pop for a multivalue tag. Starshine does not add that pseudo-expression to its executable stack instruction model. Internally, each payload lane is represented as an ordered typed `Catch` value at the start of the catch region:

```text
try body:    throw $tag (i32.const 7)
catch entry: Catch(tag=$tag, type=i32)
catch body:  drop(Catch(...))
```

The bounded-path lowerer emits the standard stack/control equivalent for one lane and uses an existing result-only multivalue block type for any positive same-tag lane vector:

```wat
(block $done
  (block $handler (result i32)
    (try_table
      (catch $tag $handler)
      (throw $tag (i32.const 7)))
    (br $done))
  (drop))
```

The payload is already on the stack after exceptional transfer to `$handler`, so catch-entry markers emit no instructions. Internal flatten can repair the scalar direct-block/if-condition shape and arbitrary ordered same-tag lane vectors into Binaryen-equivalent entry captures:

```text
catch entry: Catch(tag=$tag, type=i32)
             Catch(tag=$tag, type=f32)
             local.set $payload1 (Catch(f32))
             local.set $payload0 (Catch(i32))
catch body:  nested blocks containing drop(local.get $payload0)
             then drop(local.get $payload1)
```

The whole function is preflighted before mutation. The scalar marker keeps its exact entry-root plus first-descendant nested-use proof; the walk may cross direct blocks or follow an `if` condition, but not then/else. Ordered vectors require same-tag markers, one exclusive direct block chain, and one matching unary lane-use root per payload; locals retain source order while captures run in reverse stack order. Partial/mixed-tag vectors, other non-first-descendant or repeated paths, broader independent paths, selected arms, loops, nested catches, catch-all payloads, sharing, or outside use reject. The source-backed positives preserve following control and validate after lowering.

## Shape 19: direct legacy exceptional transfers preserve the active owner

The exact admitted catch-all rethrow shape is:

```text
try body:   throw $tag
catch body: block { rich ordinary work; rethrow 0 }
```

Flatten may sequence the rich work, but the rethrow depth remains zero in this shape. Lowering uses a modern `catch_all_ref` handler, captures the non-null exception reference into one nullable `exnref` local, and emits `local.get` followed by `throw_ref`. At that checkpoint nonzero depth, nested-catch ownership, and non-direct ancestry rejected before mutation; Shapes 22 and 23 supersede those blanket boundaries, while typed payload plus rethrow remains open.

The exact admitted delegate shape is:

```text
outer try catch-all
  body: block {
    inner resultless try
      body: rich work; throw $tag
      delegate: outer-try-label
  }
```

The delegate target remains the exact outer try label through flatten. Because Binaryen v130 stores delegation on `Try::delegateTarget` and flatten does not rewrite it, modern lowering removes only the inner legacy handler shell and lets the exception propagate to the already-active outer handler. The inner try label must be unused. The sole catch representation may now be the delegate directly or a strict direct chain of resultless single-root blocks ending in it; every intervening block label must also be unused. Non-direct targets, value-carrying delegated tries or blocks, mixed catch/delegate regions, if/loop catch ancestry, and broader nested populations reject.

Red-first whitebox counts move `188/189 -> 189/189` and `189/190 -> 190/190`; both lowered modules validate. No public flatten surface is enabled by these internal shapes.

## Latest catch-all rethrow and delegate ancestry breadth

The earlier one-rethrow and one-if shapes are now subsets. One active catch may contain any positive number of depth-zero rethrows; the handler captures one exception reference through `catch_all_ref`, and every rethrow emits `local.get` plus `throw_ref` from that shared local. An admitted path may cross an arbitrary strict direct chain of resultless untargeted `if` arms and direct blocks. Lowering inspects then/else regions, not conditions, and does not enter loops or nested tries.

The historical red fixtures failed at whitebox `192/193` on the old lowering ceiling and `193/194` on the first if-arm gate. Commit `9c237165d` adds a two-if interleaved-block chain that failed at `194/195` under the old single-if ceiling and then passed. Commit `88197c97e` adds a delegated try whose sole catch representation is a two-block chain ending in the delegate; it failed at `195/196` before admission and lowering learned the exact chain. Final whitebox is `196/196`; HOT lower is `89/89`; both new lowered modules validate. Nonzero depth, typed catch/rethrow composition, loop or nested-catch/nested-try ownership, value-carrying or targeted ifs, and non-block/mixed/value-carrying/used-label delegate shapes remain fail-closed before mutation.

## Shape 20: strict outer delegate controls and first-child catch lanes

A delegated inner try may now sit under a strict resultless block/if path inside the active target try:

```wat
(try $outer
  (do
    (block
      (if (i32.const 1)
        (then
          (block
            ;; resultless delegated inner try
          )
        )
      )
    )
  )
  (catch_all ...)
)
```

The selected block/if path must be single-root, every wrapper label must be unused, and the exact outer target must already be active. Flatten preserves the outer controls and only removes the obsolete delegated handler shell. The delegate's own catch representation may still be direct or a strict unused-label resultless block chain.

Ordered typed catch lanes may also use the payload as the first child of a larger expression:

```wat
(catch $tag
  ;; HOT entry markers for lane 0 and lane 1
  (block
    (drop (i32.add (pop i32) (i32.const 3)))
    (drop (i32.add (pop i32) (i32.const 4)))
  )
)
```

Starshine captures the lanes into locals in source order, replaces only the exact first-child payload positions, and leaves the right constants intact. This follows v130 `getFirstPop(...)`; it does not admit second-child payloads, repeated/shared/outside uses, loops, nested tries/catches, mixed tags, or partial lane vectors.

The two red-first fixtures finish at whitebox `198/198`, and both lowered modules validate. Public flatten remains removed.

## Shape 21: independent direct catch roots and one scalar value-if rethrow

Ordered typed lanes no longer require a shared explicit block wrapper in HOT. The exact direct-root counterpart is now admitted:

```wat
(catch $tag
  ;; ordered HOT markers for two i32 lanes
  (drop (i32.add (pop i32) (i32.const 3)))
  (if (pop i32)
    (then (nop))
    (else (nop)))
  (nop))
```

The first two roots after the markers independently own lane zero and lane one. Starshine captures the implicit handler values in reverse stack order, replaces the binary's first child and the if condition with source-ordered local reads, leaves the binary's right constant and later `nop` unchanged, and then performs ordinary flattening. Non-leading roots, second-child uses, selected arms, repeated/shared/outside use, partial/mixed tags, loops, and nested catches remain deferred.

One scalar value-if exceptional shape is also admitted:

```wat
(try (result i32)
  (do (call $may_throw_i32))
  (catch_all
    (if (result i32) (i32.const 1)
      (then (rethrow 0))
      (else (i32.const 7)))))
```

The rethrow arm does not write the if-result local; the simple opposite arm does. Flatten then erases the scalar if and try results through distinct existing local channels, while lowering preserves the active caught exception through `catch_all_ref` and `throw_ref`. The if label must be unused, the rethrow must be direct and depth zero, and the opposite arm must be one matching defaultable simple scalar value. Broader value controls remain fail-closed.

The two fixtures move whitebox `198/199 -> 199/199` and `199/200 -> 200/200`; both lowered modules validate. Public flatten remains removed.

## Shape 22: nonzero rethrow may select an outer direct catch-all owner

The newly admitted normalized HOT shape is an exact direct catch chain:

```text
outer catch-all:
  middle resultless try
    middle catch-all:
      inner resultless try
        inner catch-all:
          rethrow 2
```

The outer handler captures its exception through `catch_all_ref`. The middle and inner catches still occupy active catch slots even though they do not need captured locals. `rethrow 2` indexes the outer slot and lowers to `local.get` plus `throw_ref`. Flatten preserves the depth immediate.

At that checkpoint, every owner had to be a markerless resultless catch-all try and each nested try had to be a direct root of the enclosing catch. The lower test moved `89/90 -> 90/90`; the depth-two flatten fixture moved whitebox `200/201 -> 201/201`; both lowered modules validate.

## Shape 23: nonzero rethrow may cross strict block/if catch wrappers

The direct-root restriction is now superseded for an exact strict control ancestry:

```text
outer catch-all:
  if void, unused label, selected arm only
    block void, unused label, sole root
      inner resultless try
        inner catch-all:
          block void, unused label, sole root
            if void, unused label, selected arm only
              rethrow 1
```

Every wrapper is resultless and untargeted. A block contains the current root as its only body root. An `if` contains it as the sole root of exactly one arm and does not share it with the opposite arm. Any strict block/if mix may occur before the next markerless resultless catch-all owner. Flatten preserves the rethrow immediate; lowering still reads the exact outer captured `exnref` and emits `throw_ref`.

Block-only ancestry moved whitebox `201/202 -> 202/202`; mixed block/if ancestry moved `202/203 -> 203/203`. Typed markers, targeted or value-carrying controls, multi-root selected paths, loops, nested try-body rethrows, and mixed exceptional populations remain fail-closed.

## Shape 24: nonzero rethrow may cross one exact targeted catch-if exit

The strict wrapper shape may now preserve a target on the opposite arm:

```wat
(try
  (do ...)
  (catch_all
    (if $exit (i32.const 1)
      (then
        ;; selected sole root
        (rethrow 1))
      (else
        ;; opposite sole root
        (br $exit)))))
```

The conditional counterpart is also admitted when the opposite sole root is payloadless and its condition is already a simple scalar `i32`:

```wat
(if $exit (i32.const 1)
  (then
    (br_if $exit (i32.const 0)))
  (else
    (rethrow 1)))
```

Both arms must contain exactly one root. The selected arm exclusively owns the current rethrow or nested try. The opposite branch is the label's only indexed user, is directly owned by the if, and keeps the same target. For `br_if`, the condition node also remains unchanged. Flatten preserves the rethrow immediate and the existing exact target-catch `exnref` slot; lowering still emits `catch_all_ref` plus `throw_ref`.

The plain fixture moved whitebox `203/204 -> 204/204`; the conditional fixture moved `204/205 -> 205/205`; both lowered modules validate. Multiple label users, payload values, branches outside the sole opposite arm, multi-root/value-carrying/multivalue wrappers, loops, typed composition, and broader targeted ownership remain fail-closed. The rich-condition boundary is superseded only by Shape 25's exact one-use supported scalar `i32` condition.

## Shape 25: rich targeted conditions and interleaved catch lane roots

The conditional targeted-if shape may now use one rich scalar `i32` condition:

```wat
(if $exit (i32.const 1)
  (then
    ;; stays in this arm
    (local.set $cond (i32.add (i32.const 2) (i32.const 3)))
    (br_if $exit (local.get $cond)))
  (else
    (rethrow 1)))
```

The input HOT contains the rich `i32.add` directly under `br_if`. Admission requires exactly one immutable use and a supported non-control, non-tee scalar origin. Ordinary flattening inserts the local-set prelude in the same opposite arm; it does not move the condition before the `if`, change the target, or disturb the selected rethrow arm. The behavior fixture moved whitebox `205/206 -> 206/206`.

Ordered catch lanes may also have unrelated direct roots between their use roots:

```text
catch roots:
  Catch(lane0), Catch(lane1),
  drop(add(lane0, 3)),
  nop,                         ;; unrelated preserved gap
  if(lane1) { nop } else { nop },
  nop                          ;; later root preserved
```

Starshine finds lane zero and lane one only in forward source order, captures handler values into source-ordered locals in reverse stack order, replaces the exact first-child positions, and leaves both unrelated roots unchanged. The behavior fixture moved `206/207 -> 207/207`. Reverse or ambiguous lane order, missing/partial lanes, repeated/shared/outside use, non-first-descendant paths, selected-arm payloads, loops, nested catches, mixed tags, and catch-all extraction remain fail-closed.

Final passes are `5,800/5,800` and full is `9,270/9,270`; public flatten remains removed.

## Shape 26: block-wrapped targeted exits and scalar typed rethrows

The exact targeted-if opposite exit may sit under one unused-label resultless block:

```wat
(if $exit (i32.const 1)
  (then
    (block
      (local.set $cond (i32.add (i32.const 2) (i32.const 3)))
      (br_if $exit (local.get $cond))))
  (else
    (rethrow 1)))
```

The block has one root before ordinary flattening, its own label has no users, and the branch remains the if label's only user. The rich condition stays in the block body. Multi-root, targeted, value-carrying, or repeated block chains remain fail-closed for this targeted-if subset.

One exact typed catch may also preserve a direct rethrow:

```wat
(try
  (do
    (i32.const 7)
    (throw $tag))
  (catch $tag
    ;; payload is captured to an i32 local
    (drop (local.get $payload))
    ;; catch_ref also supplies the exception reference
    (throw_ref (local.get $exn))))
```

Starshine's internal lowering uses `catch_ref` with a `[i32, exnref]` handler type, stores `exnref` first, then captures the scalar payload, and lowers `Rethrow(0)` through `throw_ref`. The validating fixture moved whitebox `208/209 -> 209/209`. Multiple payloads/rethrows, non-direct or nonzero typed rethrows, and broader typed composition remain deferred.

Final passes are `5,802/5,802` and full is `9,272/9,272`; public flatten remains removed.

## Shape 27: typed payload vectors and strict targeted block chains

A typed catch may now preserve two or more repaired scalar lanes with one direct rethrow:

```text
handler stack: lane0, lane1, ..., exnref
capture order: exnref, laneN, ..., lane0
local order:   lane0, lane1, ..., exnref scratch
```

The handler uses `catch_ref` and an existing result-only `[lane0, ..., laneN, exnref]` type. Starshine stores the top exception reference first, then the repaired payload captures consume the remaining values in reverse stack order, and `Rethrow(0)` lowers through `throw_ref`. The two-lane validating fixture moved whitebox `209/210 -> 210/210`.

The exact targeted-if opposite exit may also sit under multiple strict blocks:

```wat
(if $exit (i32.const 1)
  (then
    (block
      (block
        (local.set $cond (i32.add (i32.const 2) (i32.const 3)))
        (br_if $exit (local.get $cond)))))
  (else
    (rethrow 1)))
```

Every block is resultless, single-root, directly owned, and has an unused label. The branch remains the if label's only user, and rich condition work stays in the innermost block. The two-block fixture moved `210/211 -> 211/211`. Multi-root, used-label, targeted, value-carrying, loop, try-like, or non-strict wrappers remain deferred.

Final passes are `5,804/5,804` and full is `9,274/9,274`; public flatten remains removed.

## Shape 28: typed rethrow block chains and selected delegate catch-if chains

A repaired typed catch may keep its sole depth-zero rethrow under strict resultless blocks:

```wat
(catch $tag
  ;; repaired scalar payload captures and uses
  (block
    (block
      (rethrow 0))))
```

Every block has one root, an unused label, direct ownership, and no result. The handler remains `[lane0, ..., laneN, exnref]`; lowering stores `exnref` first, captures payloads in reverse stack order into source-order locals, preserves `rethrow 0`, and emits `throw_ref`. The two-lane fixture moved `211/212 -> 212/212`.

A legacy delegate catch representation may also follow an always-selected if chain:

```wat
;; HOT catch representation only
(if (i32.const 0)
  (then (nop))
  (else
    (if (i32.const 1)
      (then (delegate $outer))
      (else (nop)))))
```

Each if is resultless and untargeted, has one root per arm, uses an exact constant selector, and has a childless `nop` in the unselected arm. HOT retains the representation and exact delegate target; lowering recognizes the same proof and transparently propagates to `$outer`, so the representational if shells do not appear in encoded output. The fixture moved `212/213 -> 213/213`.

Final passes are `5,806/5,806` and full is `9,276/9,276`; public flatten remains removed. Non-strict typed wrappers and nonconstant/effectful/targeted/richer catch-if delegate representations remain deferred.

## Shape 29: selected typed rethrows and empty delegate opposite arms

A repaired typed payload vector may keep its sole rethrow under exact selected-if shells:

```wat
(catch $tag
  ;; repaired payload captures and uses
  (if (i32.const 0)
    (then)
    (else
      (if (i32.const 1)
        (then (rethrow 0))
        (else (nop))))))
```

Each if is resultless and untargeted, the selected arm contains exactly one continuation root, and the unselected arm is either empty or one childless `nop`. The handler remains `[lane0, ..., laneN, exnref]`; lowering stores `exnref` first, captures payloads in reverse stack order into source-order locals, preserves `rethrow 0`, and emits `throw_ref`. The fixture moved whitebox `213/214 -> 214/214`.

The same exact shell may represent a delegate catch path. Admission and lowering follow only the constant-selected root and accept an explicitly empty opposite arm without manufacturing or deleting work. The delegate fixture moved `214/215 -> 215/215`, retained the original target and empty HOT regions, and lowered without encoded ifs. Missing else regions, nonconstant/effectful selectors, executable opposite roots, targeted/value-carrying/multi-root controls, loops, nested tries, mixed catches, and non-active targets remain deferred.

Final passes are `5,808/5,808` and full is `9,278/9,278`; public flatten remains removed.

## Shape 30: grouped catch lanes and no-work opposite block chains

A repaired payload vector may combine grouped and direct roots:

```wat
(catch $tag
  (pop i32)
  (pop f32)
  (pop i64)
  (block
    (block
      (drop (pop i32))
      (drop (pop f32))))
  (drop (pop i64))
  (nop))
```

The HOT markers model the ordered handler payload lanes. Starshine may capture the first two lanes from the retained nested block group and the third from the following direct root. Locals remain `i32`, `f32`, `i64` in source order; catch-entry stores consume `i64`, `f32`, `i32` in reverse stack order. Reverse/ambiguous groups, partial lanes, mixed tags, repeated/shared/outside use, loops, and selected-arm paths remain deferred. The fixture moved `215/216 -> 216/216`.

A selected delegate path may have a structurally nonempty but semantically no-work opposite arm:

```wat
(if (i32.const 1)
  (then (delegate $outer))
  (else
    (block
      (block
        (nop)))))
```

Every block is resultless, single-root, and unused as a label; the terminal body is empty or one childless `nop`. Admission and lowering use the same proof, retain the HOT representation and exact target, and omit the representational if/block chain from encoded output. Executable roots, used labels, value results, multiple roots, loops, nested tries, missing else regions, and nonconstant/effectful selectors remain deferred. The fixture moved `216/217 -> 217/217`.

Final passes are `5,810/5,810` and full is `9,280/9,280`; public flatten remains removed.

## Shape 31: interleaved grouped lanes and multi-root no-work delegate arms

A retained grouped catch block may contain unrelated roots between exact ordered payload uses:

```wat
(catch $tag
  (pop i32)
  (pop f32)
  (pop i64)
  (block
    (drop (pop i32))
    (nop)
    (drop (pop f32)))
  (nop)
  (drop (pop i64)))
```

Starshine captures `i64`, `f32`, then `i32` from the handler stack into source-ordered locals, replaces only the exact payload positions, and retains both unrelated `nop` roots and the block wrapper. The fixture moved `217/218 -> 218/218`.

An unselected constant-selected delegate arm may now be a forest of independent no-work roots:

```wat
(if (i32.const 1)
  (then (delegate $outer))
  (else
    (nop)
    (block (block))
    (block (block (nop)))))
```

Every root must independently be childless `nop` or a resultless unused-label single-root block chain ending empty or in `nop`. Admission and lowering share the proof; the HOT forest remains represented while encoded output omits it. The fixture moved `218/219 -> 219/219`. Executable roots, used labels, value results, loops, nested tries, missing else regions, and effectful selectors remain deferred.

## Shape 32: one typed handler may serve multiple rethrows, and delegate no-work blocks may contain forests

A repaired typed catch may contain multiple depth-zero rethrows:

```wat
(catch $tag
  (drop (pop i32))
  (drop (pop f32))
  (rethrow 0)
  (rethrow 0))
```

Starshine lowers the catch through one `[i32, f32, exnref]` `catch_ref` handler. Payload locals remain source ordered, handler-stack payload captures remain reversed after the top exception-reference capture, and both rethrows read the same exception local before `throw_ref`. The fixture proves one `catch_ref`, one extra exnref local, two `throw_ref` sites, and validating output. A third unsupported-depth rethrow keeps the entire function unchanged.

A constant-selected delegate opposite arm may also contain one block whose body is a recursively proven forest:

```wat
(if (i32.const 1)
  (then (delegate $outer))
  (else
    (block
      (nop)
      (block (block))
      (block (block (nop))))))
```

Every block is resultless and unused as a label. Every nested body root must recursively be childless `nop` or another exact no-work block. Admission and lowering share the query, retain the HOT tree, and omit the representational if/block forest from encoded output. Nested executable roots, value blocks, used labels, loops, and nested tries remain deferred.

The two fixtures move whitebox `219/220 -> 220/220` and `220/221 -> 221/221`; final passes are `5,814/5,814` and full is `9,285/9,285`. Public flatten remains removed.

## Bottom line

The simplest pattern summary is:

- simple children stay simple
- rich value-producing children become temp locals
- control-flow results become explicit local channels
- tee and branch payloads become explicit local traffic
- real control effects survive as preludes plus placeholder `unreachable`
- and some feature families are still a hard unsupported boundary
