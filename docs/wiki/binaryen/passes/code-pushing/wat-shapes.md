---
kind: concept
status: working
last_reviewed: 2026-04-11
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/ir/hot_lower_live_repro_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./artifact-frontiers.md
  - ./parity.md
---

# `code-pushing` WAT Shapes

## Main Idea

- `code-pushing` is not a general "move any pure value later" pass.
- It is a shape-driven pass over root-level `local.set` writes whose later use is
  gated by a conditional control boundary.
- The exact printed WAT form matters because the pass is intentionally biased
  toward:
  - conditional push points
  - one-arm `if` sinks
  - result-carrier shapes that appear as dropped blocks after HOT lift

## Terms Used In This Folder

- "Pushable root" means a root-level `local.set` whose destination local is in
  the pass's SFA form and whose value subtree is movable under the current
  barrier rules.
- "Push point" means one of the exact conditional control roots the pass is
  willing to move toward: `if`, `br_if`, `br_on_null`, `br_on_non_null`,
  `br_on_cast`, `br_on_cast_fail`, or a top-level `drop` wrapped around one of
  those.
- "Carrier" means a result-producing `block` or `if` that is temporarily
  carrying a value which later becomes the child of some `local.set`.
- "Dropped carrier" means a result-producing block whose result is immediately
  wrapped in `drop`, while some internal `local.set` is only kept alive because a
  later root still reads that local.
- "Explicit exit" means a subtree containing `br`, `br_table`, `return`,
  `throw`, `throw_ref`, `rethrow`, `delegate`, or `unreachable` in a way that
  affects whether moved locals stay dead on the exited path.

## Shape 0: Expression-Position Value-Block Rewrites

Before:

```wat
(block (result i32)
  (i32.const 7)
  (local.set $a)
  (i32.const 0)
  (local.set $b)
  (if
    (local.get $cond)
    (then
      (drop (local.get $a))
      (drop (local.get $b))))
  (local.get $a))
(local.set $out)
```

After:

```wat
(block (result i32)
  (local.set $a
    (i32.const 7))
  (nop)
  (if
    (local.get $cond)
    (then
      (local.set $b
        (i32.const 0))
      (drop (local.get $a))
      (drop (local.get $b))))
  (local.get $a))
(local.set $out)
```

Why this transforms:

- Binaryen still treats the inner `local.set $b` as a normal `code-pushing`
  candidate even though the containing `block (result ...)` is only reachable
  through an expression-position wrapper.
- The same reduced pushed shape now has in-tree Starshine proofs for three
  wrapper families:
  - `local.set (block ...)`
  - `drop (local.tee ... (block ...))`
  - `global.set (block ...)`
- This is the main reason the pass now scans child-expression trees for nested
  region holders instead of only looking at direct region roots and dropped
  carriers.

## Shape 1: Plain Same-Region Reordering Past A Push Point

Before:

```wat
(local.get $src)
(local.set $tmp)
(if
  (local.get $cond)
  (then
    (call $side)))
(local.get $tmp)
(local.set $out)
```

After:

```wat
(if
  (local.get $cond)
  (then
    (call $side)))
(local.get $src)
(local.set $tmp)
(local.get $tmp)
(local.set $out)
```

Why this transforms:

- The moved root is still a root-level `local.set`.
- The destination local is SFA: one write, no parameter origin, and no earlier
  postorder `local.get`.
- The `if` is a recognized push point.
- The crossed gap does not read or overwrite the same local, and the moved value
  does not have unremovable side effects.
- The later read remains in the same region after the push point, so the write is
  not being sunk into a path where it would become dead.

## Shape 2: Sink Into Exactly One `if` Arm

Before:

```wat
(local.get $src)
(local.set $tmp)
(if
  (local.get $cond)
  (then
    (call $touch (local.get $tmp)))
  (else
    (call $other)))
```

After:

```wat
nop
(if
  (local.get $cond)
  (then
    (local.get $src)
    (local.set $tmp)
    (call $touch (local.get $tmp)))
  (else
    (call $other)))
```

Why this transforms:

- Exactly one arm reads the local.
- The opposite arm does not read that local.
- There is no later read after the `if`, or the non-target arm is terminal so
  later reads are only reachable through the target arm.
- The set is not `unreachable`-typed, so sinking it into the arm does not change
  surrounding block reachability or require refinalization.
- The pass never duplicates the set into both arms; it picks one arm or does
  nothing.

## Shape 3: Multiple Pushable Roots Move Together But Keep Order

Before:

```wat
(local.get $a)
(local.set $x)
(local.get $b)
(local.set $y)
(local.get $cond)
(br_if $label)
(local.get $x)
(call $use_x)
(local.get $y)
(call $use_y)
```

After:

```wat
(local.get $cond)
(br_if $label)
(local.get $a)
(local.set $x)
(local.get $b)
(local.set $y)
(local.get $x)
(call $use_x)
(local.get $y)
(call $use_y)
```

Why this transforms:

- The pass scans one segment backward from the push point.
- Several roots in that segment can be movable at once.
- Each movable root is removed from its old position and reinserted immediately
  before the push point.
- Original left-to-right order is preserved among all moved roots.
- Earlier movable roots that cannot cross the accumulated barrier stay put and
  themselves become part of the barrier for earlier candidates.

## Shape 4: Earlier Explicit-Exit Prefixes That Are Still Safe

Before:

```wat
(local.set $carry
  (if (result i32)
    (local.get $flag)
    (then
      (local.set $k (local.get $arg))
      (i32.const 7))
    (else
      (local.set $k (local.get $arg))
      (return (i32.const 9)))))
(local.get $arg)
(local.set $tmp)
(local.get $tmp)
(if
  (then
    (call $touch (local.get $tmp))))
(local.get $carry)
```

After:

```wat
(local.set $carry
  (if (result i32)
    (local.get $flag)
    (then
      (local.set $k (local.get $arg))
      (i32.const 7))
    (else
      (local.set $k (local.get $arg))
      (return (i32.const 9)))))
(local.get $tmp-source)
(local.set $tmp)
(if
  (then
    (call $touch (local.get $tmp))))
(local.get $carry)
```

Why this transforms:

- Not every earlier explicit exit is a global fence.
- The current pass admits some earlier explicit-exit prefixes when those exits are
  self-contained, owner-contained, terminal, or otherwise already covered by the
  pass's safe-exit rules.
- The guiding idea is the same as Binaryen's: the moved local is already dead on
  the path that exits early, so that explicit exit should not automatically block
  motion on the surviving path.
- The Starshine implementation has extra owner-aware helpers here because HOT
  lift exposes these prefixes as block and carrier regions rather than only as
  direct AST expressions.

## Shape 5: Alias Extraction Out Of A Dropped Result Carrier

Before:

```wat
(block $holder (result i32)
  (drop
    (block $outer (result i32)
      (local.get $arg)
      (local.set $moved)
      (br $outer (i32.const 0))))
  (local.get $arg)
  (local.set $used)
  (local.get $used)
  (if
    (then
      (call $touch (local.get $used))))
  (local.get $moved))
```

After:

```wat
(block $holder (result i32)
  (drop
    (block $outer (result i32)
      nop
      (br $outer (i32.const 0))))
  (local.get $arg)
  (local.set $used)
  (local.get $used)
  (if
    (then
      (call $touch (local.get $used))))
  (local.set $moved (local.get $arg))
  (local.get $moved))
```

Why this transforms:

- Binaryen's AST can often realize the final placement of the write after the
  conditional use point.
- HOT lift can strand the candidate write inside a dropped result carrier block.
- Starshine therefore performs a deliberate extraction rewrite:
  - replace the internal `local.set` with `nop`
  - reinsert the `local.set` after the sibling `if`
- This is still a no-duplication transform because the value being extracted is a
  direct alias `local.get`, not an effectful producer that would need cloning.

## Shape 6: Call-Fed Dropped-Carrier Extraction

Before:

```wat
(block $holder (result i32)
  (drop
    (block $outer (result i32)
      (local.set $moved
        (call $mk (local.get $arg)))
      (call $touch (local.get $arg))
      (br $outer (i32.const 0))))
  (local.get $arg)
  (local.set $used)
  (local.get $used)
  (if
    (then
      (call $touch (local.get $used))))
  (local.get $moved))
```

After:

```wat
(block $holder (result i32)
  (drop
    (block $outer (result i32)
      (local.tee $temp
        (call $mk (local.get $arg)))
      (call $touch (local.get $arg))
      (br $outer (i32.const 0))))
  (local.get $arg)
  (local.set $used)
  (local.get $used)
  (if
    (then
      (call $touch (local.get $used))))
  (local.set $moved
    (local.get $temp))
  (local.get $moved))
```

Why this transforms:

- The pass must not duplicate the call.
- It keeps the original call exactly where it already executes, inside the
  carrier.
- It synthesizes one temporary local and converts the internal set to
  `local.tee temp (call ...)`.
- It materializes a later alias `local.set` from that temp after the sibling
  `if`.
- The current implementation intentionally limits this family to single-result
  `i32` calls. Wider value types, multi-result calls, or more structural
  producers are still outside the kept slice.

## Shape 7: Nested Carrier-Local Wrapper Extraction

Before:

```wat
(drop
  (block $outer (result i32)
    (block $wrap
      (local.set $moved
        (call $mk (local.get $arg))))
    (br $outer (i32.const 0))))
...
(if ...)
(local.get $moved)
```

After:

```wat
(drop
  (block $outer (result i32)
    (block $wrap
      (local.tee $temp
        (call $mk (local.get $arg))))
    (br $outer (i32.const 0))))
...
(if ...)
(local.set $moved
  (local.get $temp))
(local.get $moved)
```

Why this transforms:

- The lifted carrier can contain one extra wrapper `block` or `drop (block ...)`
  layer around the actual candidate root.
- The current pass knows how to look through exactly that narrow wrapper family.
- This is not arbitrary recursive extraction. It is one deliberately bounded
  shape that showed up in the real debug-artifact reductions.

## Shape 8: Shapes That Stay Deliberately Unchanged

### Local-eligibility blockers

- Parameter locals never move.
- Locals with multiple writes never move.
- Locals with a postorder read before the unique write never move.
- A root whose value has unremovable side effects never moves.

### Conditional-shape blockers

- If both `if` arms read the local, the pass does not duplicate the set into both
  arms.
- If there is a later read after the `if` and the opposite arm can still fall
  through, one-arm sinking is blocked.
- If the local is still read after the enclosing block that contains the nested
  `if`, the pass also blocks the sink even when that nested block has no later
  same-region read after the `if`.
- Reads or writes in the `if` condition itself can block both sinking and
  reordering.
- Result-producing `if` roots are currently not sink targets in Starshine.

### Carrier and result-structure blockers

- Unsafe explicit-exit prefixes still block extraction and non-void-region motion.
- A carried branch payload is part of the prefix shape.
  If a prefix root reaches an outer owner exit through a `br` payload, and that
  payload itself hides another parent-escape branch, Starshine now treats that
  as an unsafe mixed explicit-exit carrier instead of pretending the outer `br`
  is a leaf. The pass has a reduced regression and whitebox proof for this
  exact `LocalSet(Block(...))` shape now.
- A control-region body is part of the prefix shape too.
  If an earlier `block` or similar control root hides its only branch inside the
  body region, that branch still counts as an explicit exit for non-void-region
  fencing. The pass now has both a whitebox helper proof and a pass regression
  for this nested body-region form.
- Parent-escape carrier families where the outer escape block would become
  result-producing are still intentionally fail-closed. On the current debug
  artifact, only `Func 1977` is still kept for that reason. `code-pushing` now
  rechecks suspicious lowered carriers against full-module writeback validation,
  so one writeback-valid terminal-owner / parent-escape family is now admitted
  even though the coarse suspicious-carrier heuristic still matches its lowered
  Wasm.
- One more live shape split is now explicit too:
  repeated alias-if ladders are not the same thing as the one-off terminal tail.
  Starshine now readmits the repeated ladder shape that `Func 1948` needs while
  still fencing the one-off `Func 1977` tail before lowering.
- Call-fed extraction is currently fenced to a narrow single-result `i32` slice.
- The pass does not currently synthesize the larger alias-local webs Binaryen
  appears to materialize in the later `105621` and `126757` artifact families.
- The old `func $127` wording here is now superseded by
  [`0076`](../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md):
  Binaryen `--code-pushing` leaves that function unchanged on the current
  artifact.
- The kept in-tree rule is therefore narrower:
  when an alias `local.set(local.get ...)` would cross an extra kept
  condition-set before a later `if`, and that alias comes from an earlier
  explicit-exit carried-result block, Starshine now keeps the alias where it
  is instead of treating the shape as more `code-pushing` surface.

## Practical Rule For Future Tests

- When adding a new reducer, make the printed WAT show:
  - the candidate `local.set`
  - the exact push point or carrier that justifies moving it
  - the later read that proves the move matters
  - the blocker root, if the new test is a negative boundary
- For dropped-carrier work, always pair the pass test with a HOT-lowering proof if
  the rewrite changes result-carrier structure or synthesizes a temp local.
