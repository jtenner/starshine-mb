---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_test.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./reduced-repros-and-evidence.md
  - ./parity.md
---

# `tuple-optimization` WAT Shapes

## Reading Rule

- Binaryen's source pass talks about tuple locals written by `tuple.make` and consumed by `tuple.extract`.
- Starshine's real reduced fixtures often do not print that way after lift. The important thing is not the surface syntax alone, but whether the function is expressing the same "bundle several lanes, then immediately spill, copy, and partially consume them through locals" behavior.
- For this pass, "shape" means "the local traffic pattern that proves a multi-result bundle has not escaped."

## The Canonical Binaryen Tuple-Local Shape

The literal upstream shape is:

```wat
(local.set $tuple
  (tuple.make
    (A)
    (B)
    (C)))

(use
  (tuple.extract 0
    (local.get $tuple)))
```

Why this is transformed:

- The tuple local exists only as scratch storage.
- Later local passes cannot see that lane `1` or lane `2` may be dead while the value is still packaged as one tuple local.
- Splitting the tuple local into three scalar locals exposes dead-lane cleanup, copy propagation, dead store removal, and local reordering opportunities.

The canonical Binaryen copy-chain extension is:

```wat
(local.set $tuple0
  (tuple.make
    (A)
    (B)
    (C)))

(local.set $tuple1
  (local.get $tuple0))

(use
  (tuple.extract 2
    (local.get $tuple1)))
```

Why this is still transformed:

- The copied tuple still never escapes as a whole value.
- The extra tuple local is just a forwarding bridge.
- Binaryen therefore treats both locals as one connected component: if one side is safe, both are candidates; if either side escapes, both are poisoned.

## The Canonical Starshine HOT-Native Seed Shape

The simplest in-tree reduced seed is the direct spill bridge:

```wat
(module
  (func (result i32)
    (local i32 i32 i32)
    block (result i32 i32 i32)
      i32.const 10
      i32.const 20
      i32.const 30
    end
    local.set 2
    local.set 1
    local.set 0
    local.get 0))
```

Why this is the Starshine seed shape:

- HOT lift sees one producer with `result_arity > 1`.
- The producer's uses are exactly one `local.set` or `local.tee` per result lane.
- That is already very close to Binaryen's post-split form, which is why the Starshine pass does not need to materialize explicit tuple locals first.

What the pass is trying to preserve:

- lane identity
- lane order
- the designated host `local.tee` value, if any
- the original root/result placement when one lane is also the function or block result

## Exact Shape Family 1: Direct Spill Bridge

Pattern:

```wat
(producer ... -> (result t0 t1 ... tn))
local.set lane[n]
...
local.set lane[1]
local.set or tee lane[0]
```

Meaning:

- The producer is the root multivalue source group.
- The spilled locals are the current tuple lanes.
- This is the cheapest and safest family: no copy group yet, just direct splitting.

Why rewrite:

- It removes the "shared producer plus spill ladder" bridge when only some lanes survive.
- It lets later passes reason about each lane independently.

Current in-tree reduced coverage:

- direct multivalue spill bridge
- spill bridge ending in `local.tee`
- nested scalar-result spill bridge

## Exact Shape Family 2: Pure Exact-Copy Group

Pattern:

```wat
block (result t0 t1 t2)
  local.get a0
  local.get a1
  local.get a2
end
local.set b2
local.set b1
local.set b0
```

Meaning:

- A second lane group is reconstructing the exact same tuple payload from another group's scalar lanes.
- The copy group may have its own consumers, so this is not always redundant.

Why rewrite:

- If every use is still tuple-like, the copy group is just another scratch bundle.
- Splitting or forwarding the copy lets later local passes remove whole copied lanes or collapse copy chains.

Important subfamilies:

- lane-ordered exact copies
- scrambled destination-lane order
- overlapping copies where one destination lane aliases a source lane
- single-use copies from a host-tee source

## Exact Shape Family 3: Host `local.tee` Bridge

Pattern:

```wat
(producer ...)
local.set lane2
local.set lane1
local.tee lane0
...
use lane0 as ordinary scalar value
```

Meaning:

- One lane is not just stored; it is also the value of a `local.tee`.
- That lane becomes the "host lane" because it carries both tuple-like traffic and ordinary scalar control/data flow.

Why this is delicate:

- Replacing a tuple bridge here cannot lose the scalar value yielded by the tee.
- Binaryen solves that with `sequence(block-of-sets, local.get lane)`.
- Starshine solves it with typed scalar result blocks, anchor-host staging, or preserved host tees depending on the surrounding root structure.

What must remain true after rewrite:

- the later scalar consumer still sees the tee result in the same order
- drops and side effects around the tee do not move incorrectly
- a preserved host lane does not accidentally get replaced by a fresh split local when the original tee value must stay live

## Exact Shape Family 4: Scalar-Forward Copy Group

Pattern:

```wat
(producer ...)
local.set s2
local.set s1
local.tee s0
local.set c0 (local.get s0)
local.set c1 (local.get s1)
local.set c2 (local.get s2)
...
scalar consumer reads c0/c1/c2 directly
```

Meaning:

- The second group is not rebuilt as a visible multivalue `block`; instead it forwards lanes one-by-one through scalar locals.
- This is a HOT-native family that Binaryen's literal tuple-local source does not print, but semantically it is the same tuple-copy component.

Why rewrite:

- Without recognizing scalar-forward copies, Starshine would miss real debug-artifact families that Binaryen still optimizes.
- The group is still tuple-like if every forwarded local exists only to repackage or partially consume the same lane bundle.

Important subfamilies:

- one-hop scalar-forward bridge
- mixed direct-and-forwarded bridge from a direct multivalue producer
- chained mixed scalar-forward bridges
- direct-producer bridge where one source lane is reused directly while the others are forwarded

## Exact Shape Family 5: Nested Scalar-Result And Branch-Exit Carriers

Pattern:

```wat
block $exit (result i32)
  ...
  (producer ...)
  local.set ...
  ...
  br $exit (local.get carried_lane)
end
```

or

```wat
block (result i32)
  block (result i32 i32 i32)
    ...
  end
  local.set ...
  local.set ...
  local.set ...
  local.get carried_lane
end
```

Meaning:

- The tuple-like bundle is nested inside a larger scalar result context.
- One lane is being used as the enclosing expression result while the other lanes are just bridge state.

Why rewrite:

- Real functions use multivalue bridges inside branch exits, nested blocks, and result blocks.
- If the pass only handled flat top-level spill ladders, it would miss the same optimization opportunities Binaryen sees before later local cleanup.

Why this family is hard:

- The rewritten carrier often cannot stay as a simple flat set ladder.
- Starshine may need a typed root carrier or staged scalar copyback to keep the enclosing result shape legal.

## Exact Shape Family 6: Terminal Drop-Only Tails

Pattern:

```wat
... build tuple-like copy group ...
local.get lane1
drop
local.get lane2
drop
local.get lane0
```

or host-lane equivalent:

```wat
... build tuple-like copy group ...
local.tee lane0
local.get lane1
drop
local.get lane2
drop
```

Meaning:

- Most lanes are now only used to feed trailing `drop`s.
- One remaining lane, possibly the host lane, is the only value that still matters.

Why rewrite:

- Binaryen still wants the dead lanes exposed so later cleanup can eliminate them.
- But the pass must not keep rebuilding a full tuple-like carrier if the only surviving non-drop traffic is a single scalar lane.

Current rule surfaced by the reduced repros:

- no-host terminal drop-only children can still be worthwhile if they remain part of a larger connected component
- host-lane terminal children need special suppression or staging logic so the pass does not reintroduce redundant tuple carriers

## Exact Shape Family 7: Chained Host-Copy `tail-live0`

Pattern:

```wat
(producer ...)
... first host-copy group ...
... second host-copy group ...
local.tee lane0
drop
drop
local.get lane0
```

Meaning:

- Several host-carrying exact-copy groups are chained.
- Only lane `0` is live at the tail.
- The intermediate groups still matter because they preserve the carrier ordering and tee semantics.

Why this family matters disproportionately:

- It is a stress case for every hard part of the pass at once:
  - host-lane preservation
  - copy-group connectivity
  - redundant tuple-carrier suppression
  - typed carrier reconstruction
  - final lowering shape
- It has repeatedly been the reduced family that distinguishes "HOT rewrite looks right" from "final emitted module still matches Binaryen."

## Non-Candidate Shapes

The pass deliberately rejects these shapes:

- any group with mixed tuple-like and non-tuple-like whole-value consumers
- any lane bundle that escapes through unsupported consumer kinds
- unreachable tee chains where the type may not be trustworthy
- ambiguous scalar copies that cannot be proven to be forwarding one lane bundle
- functions containing the nested rootslot host-copy wrapper family guarded by the current conservative bailout

Concrete example of an intentional rejection:

```wat
block (result i32 i32)
  i32.const 1
  i32.const 2
end
local.set 0
drop
local.get 0
```

Why this is rejected:

- The same local traffic is participating in both bridge-like storage and a direct scalar non-bridge use.
- The pass is conservative by design and treats that mixed consumer set as an escape.

## Practical Test-Authoring Rule

- Prefer reduced fixtures that isolate exactly one tuple family at a time.
- When documenting a new bug, capture three things together:
  - the raw WAT shape
  - the intended HOT interpretation
  - the exact reason the family should rewrite or bail out
- If a family only appears after lift and not as obvious raw WAT tuple syntax, document the lifted interpretation explicitly. That is normal for this pass.

