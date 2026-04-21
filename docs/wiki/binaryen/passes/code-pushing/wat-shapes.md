---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-selection-and-barriers.md
  - ../../no-dwarf-default-optimize-path.md
---

# `code-pushing` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen’s `code-pushing` pass.

## Read this page with one mental model

Binaryen is trying to make work more **path-local**.

It is not asking:

- “is this duplicate code?”

It is asking:

- “is this work currently done in a common prefix even though it is really only needed later inside some control-dependent region?”

If yes, Binaryen may sink that work deeper.

## Quick glossary

- **common prefix**: code that runs before control flow splits
- **candidate suffix**: the tail of that prefix Binaryen is currently considering moving
- **separator**: the following `if` or branchy structure that might receive the moved suffix
- **target segment**: a specific downstream region that would get a cloned copy of the suffix
- **one-arm case**: only one reachable destination needs the value
- **two-arm case**: two reachable `if` arms need the value

## Shape 1: pure arithmetic used only in both `if` arms can sink into both arms

Conceptual before:

```wat
(local.set $tmp
  (i32.add
    (local.get $x)
    (i32.const 1)))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (drop (local.get $tmp))))
```

Conceptual after:

```wat
(if
  (local.get $cond)
  (then
    (drop
      (i32.add
        (local.get $x)
        (i32.const 1))))
  (else
    (drop
      (i32.add
        (local.get $x)
        (i32.const 1)))))
```

Why it can sink:

- the value is only needed inside the arms
- the segment is pure enough for the strict two-arm `if` rules
- duplicating it makes the work path-local

## Shape 2: pure work used in only one arm can sink into only that arm

Conceptual before:

```wat
(local.set $tmp
  (i32.mul
    (local.get $x)
    (i32.const 8)))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (nop)))
```

Conceptual after:

```wat
(if
  (local.get $cond)
  (then
    (drop
      (i32.mul
        (local.get $x)
        (i32.const 8))))
  (else
    (nop)))
```

Why it can sink:

- only the `then` arm uses the value
- there is no use after the `if`
- the candidate segment is still pure enough for the `if` rewrite family

This is a good reminder that Binaryen is not only “duplicate into both arms.”

## Shape 3: if one arm is already `unreachable`, Binaryen can be more permissive

Conceptual before:

```wat
(call $side-effect-free-helper)
(if
  (local.get $cond)
  (then
    (unreachable))
  (else
    (drop (i32.const 0))))
```

Conceptual after, in spirit:

```wat
(if
  (local.get $cond)
  (then
    (unreachable))
  (else
    (call $side-effect-free-helper)
    (drop (i32.const 0))))
```

Why this family matters:

- Binaryen treats the one-arm-reachable case differently from the strict two-arm case
- it is closer to postponing work than to duplicating it into two live paths
- that is why the pass can sometimes sink here even when the general two-arm rules would reject the same segment

## Shape 4: branchy block / switch-like shapes also participate

Conceptual before:

```wat
(local.set $tmp
  (i32.add
    (local.get $x)
    (i32.const 1)))
(block
  (br_table $a $b $c
    (local.get $which))
  ;; various target segments later use $tmp
)
```

Conceptual after:

```wat
(block
  (br_table $a $b $c
    (local.get $which))
  ;; the relevant target segments now each contain
  ;; their own cloned copy of the pushed suffix
)
```

Why it matters:

- `code-pushing` is not only an `if` pass
- the generic family uses `BranchSeeker` and target segments
- but it still stays within structured block segments rather than arbitrary CFG regions

## Shape 5: GC operations can push when the same safety rules allow it

The shipped `code-pushing-gc.wast` tests show positive families involving operations like:

- `struct.get`
- `array.get`
- `ref.cast`
- `ref.as_non_null`

Conceptual idea:

```wat
(local.set $tmp
  (ref.cast (ref $T)
    (local.get $r)))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (nop)))
```

can become a shape where the `ref.cast` itself lives in the consuming arm.

Why it matters:

- the pass is not limited to integer arithmetic
- but ref-typed and trap-sensitive operations make the barrier story more important, not less

## Shape 6: if the value is still used after the `if`, do **not** expect a one-arm sink

Before and after stay the same in the important part:

```wat
(local.set $tmp
  (i32.add
    (local.get $x)
    (i32.const 1)))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (nop)))
(drop (local.get $tmp))
```

Why Binaryen keeps it:

- the value is still needed after the `if`
- sinking it into only one arm would strand the later use

This is one of the most important negative rules in the `into_if` tests.

## Shape 7: a value-typed `if` blocks the strict two-arm family

Before and after stay the same in the important part:

```wat
(local.set $tmp
  (i32.add
    (local.get $x)
    (i32.const 1)))
(drop
  (if (result i32)
    (local.get $cond)
    (then
      (local.get $tmp))
    (else
      (local.get $tmp))))
```

Why Binaryen keeps it:

- when both arms are reachable, `optimizeIntoIf(...)` rejects `if` expressions with concrete result types
- this is one of the pass’s least-obvious type-shape rules

## Shape 8: calls and other visible side effects stop the strict two-arm `if` path

Before and after stay the same in the important part:

```wat
(local.set $tmp
  (call $helper))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (drop (local.get $tmp))))
```

Why Binaryen keeps it under the default rules:

- duplicating the call into two live arms changes visible behavior and cost
- the strict two-arm `if` family rejects calls, side effects, throws, memory traffic, table traffic, and mutable-global traffic

## Shape 9: default trap sensitivity is a real barrier

Before and after often stay the same under default settings:

```wat
(local.set $tmp
  (i32.load
    (local.get $ptr)))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (drop (local.get $tmp))))
```

Why it matters:

- a trapping load is not treated like a harmless integer add
- moving or duplicating it can change when a trap would happen

The dedicated `ignore-implicit-traps` and `traps-never-happen` test files exist because changing those options changes this barrier story.

## Shape 10: option-relaxed modes unlock more pushing

The shipped tests explicitly cover the looser modes:

- `code-pushing_ignore-implicit-traps.wast`
- `code-pushing_tnh.wast`

Practical takeaway:

- if a load-like or trap-capable operation does not move in the default tests,
- but does move in the option-specific tests,
- that is not inconsistency — it is part of the intended contract

## Shape 11: EH structure is a bailout-rich zone

The shipped `code-pushing-eh.wast` tests show why exception handling needs explicit attention.

Conceptual before-and-after lesson:

- `try` / `catch` / `pop` / `throw` shapes can make a candidate look sinkable in a superficial dataflow sense
- but moving it can change when values exist or when exceptional control flow is observed
- Binaryen is therefore conservative here

Beginner takeaway:

- EH is one of the easiest reasons for an apparent non-move to be correct

## Shape 12: even safe code may still be skipped if the heuristic says it is not worth it

Conceptual example:

```wat
(local.set $tmp
  (i32.const 1))
(if
  (local.get $cond)
  (then
    (drop (local.get $tmp)))
  (else
    (drop (local.get $tmp))))
```

Why Binaryen may skip it:

- duplicating a tiny constant may not buy enough to justify the rewrite
- the pass uses a real local `benefit > cost` test

That means some non-rewrites are heuristic choices, not semantic impossibilities.

## What later passes tend to do with the new shape

`code-pushing` is designed to help nearby passes, not replace them.

### Unlock family 1: `tuple-optimization`

The pass sits immediately before tuple-opt in the default no-DWARF path. A more path-local body can make tuple-local cleanup more precise.

### Unlock family 2: `simplify-locals-nostructure`

Once work has been sunk nearer its consumers, early local cleanup sees a body with less shared-prefix temporary traffic.

### Unlock family 3: later cleanup passes

After tuple and local cleanup, `vacuum` and `reorder-locals` can clean up the reshaped structure further.

## A simple rule of thumb

When you look at a possible `code-pushing` candidate, ask these questions in order:

1. Is this really a contiguous suffix in one block?
2. Is there an immediate later structured separator Binaryen actually knows how to target?
3. Are all the important uses inside those target segments or arms?
4. Does the effect model allow the move?
5. Is this the strict two-arm `if` family, the one-arm-unreachable family, or the generic branchy family?
6. Is the move likely worth the duplication cost?

If any answer is “no,” expect Binaryen to keep the prefix where it is.

## Source strength note

- The positive and negative families above come directly from Binaryen’s shipped `code-pushing*` lit tests plus the `version_129` implementation comments.
- The pass-interaction explanations are derived from the scheduler placement in `pass.cpp` and the repo’s no-DWARF pathway docs.

## Sources

- [`../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md`](../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` lit tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>
