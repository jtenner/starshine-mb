---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `memory-packing`: segment-op rewrites and traps

This page exists because the hardest part of Binaryen `memory-packing` is **not** “find zero bytes.”
It is preserving the behavior of segment-using instructions after the raw segment bytes change.

## Keep two stories separate in your head

### Story 1: active segments at startup

- Active segments write into memory during instantiation.
- If the memory starts zero-initialized, zero runs can often be omitted.
- But startup traps must still happen if the original segment would have trapped.

### Story 2: passive segments at runtime

- Passive segments are not written automatically.
- They are read later by instructions like `memory.init`.
- If the segment is split, those instructions must be rewritten to act as if the original unsplit segment still existed.

A lot of beginner confusion comes from mixing those stories together.

## Why active `memory.init` and active `data.drop` get simplified first

Before the main split logic, upstream runs `optimizeSegmentOps(...)`.

That helper pass rewrites some cases immediately:

- active `memory.init` that must trap
- active zero-size `memory.init`
- active in-bounds `memory.init`
- active `data.drop`

The main reason is not just speed.
It also gives later code a cleaner world to reason about.

## Active `data.drop` is easy

If a segment is active, dropping it later does not matter.
Its bytes were already applied at startup.
So upstream rewrites:

```wat
(data.drop $active)
```

into:

```wat
(nop)
```

That is a simple but important rule.

## Active `memory.init` is trickier than it sounds

An active segment is already applied at startup, so a later `memory.init` from it is not a normal passive-segment copy.
Binaryen rewrites those cases into explicit runtime checks or explicit traps.

### Constant impossible cases

If the offset or size is already constant and definitely out of range for the source data, Binaryen rewrites the instruction into:

- `drop dest`
- `drop offset`
- `drop size`
- `unreachable`

The values are still evaluated, which preserves side effects and stack behavior.
Then the operation traps.

### Zero-size case

A zero-length `memory.init` can still trap if the destination is out of bounds.
So Binaryen does **not** simply erase it.
Instead it emits a destination-bounds check.

That is one of the easiest behaviors to misunderstand.

## Why `ReFinalize` appears here

Those explicit trap rewrites can change the type shape of the surrounding code.
So the helper pass refinalizes functions when needed.

That is a useful clue:

- `memory-packing` is not just a bytes-only transformation.
- Some of its correctness work is ordinary IR repair after control-flow rewrites.

## Passive segments are where the real rewrite machinery lives

Suppose the original passive segment bytes were:

```text
AAAA 0000 BBBB
```

If Binaryen drops the zero run, the original `memory.init` can no longer read from one contiguous source segment that still contains the zeros.
So it must emit something like:

```wat
(memory.init $seg.part0 ... 4)
(memory.fill ... 4)
(memory.init $seg.part1 ... 4)
```

That is the central passive-segment idea.

## Why `memory.fill` is safe for zero runs

`memory.fill` writes explicit zero bytes into the destination memory.
That matches what reading zero-filled bytes from the original passive segment would have produced.

So zero subranges do not need stored segment bytes anymore.
They can be regenerated at runtime.

## Why dropped-segment state becomes a problem

Here is the subtle trap rule:

- `memory.init` traps if the source passive segment was already dropped.
- `memory.fill` does **not** know or care whether the original segment was dropped.

So if a rewritten sequence begins with `memory.fill`, it could accidentally succeed where the original program would have trapped.

That is why Binaryen sometimes creates a synthetic global like:

```wat
(global $__mem_segment_drop_state (mut i32) (i32.const 0))
```

and then checks it explicitly before the first `memory.fill`.

## The drop-state global is lazy, not unconditional

This is important.
Binaryen does **not** always add a drop-state global.

It creates one only when some transformed `memory.init` needs an explicit dropped-segment check that `memory.init` itself no longer provides.

That keeps the transform smaller and more honest.

## Why only some rewritten sequences need the explicit check first

If the first emitted operation is another `memory.init`, that operation already performs the dropped-segment trap check.
So no extra explicit check is needed up front.

If the first emitted operation is `memory.fill`, then Binaryen must synthesize the check itself.

That one distinction explains a lot of the “why did this segment get a drop-state global but that one did not?” behavior.

## Rewriting `data.drop`

Once a passive segment is split, dropping it means dropping every surviving nonzero piece.
Binaryen therefore rewrites:

```wat
(data.drop $old)
```

into something conceptually like:

```wat
(global.set $__mem_segment_drop_state (i32.const 1)) ;; only if needed
(data.drop $old)
(data.drop $old.1)
(data.drop $old.2)
```

If there are no surviving nonzero split segments, the final result can be just:

```wat
(nop)
```

## Zero-size `memory.init` after splitting

Zero-size copies remain subtle even after splitting.

Binaryen still needs to preserve:

- destination-bounds behavior
- dropped-segment behavior

So a zero-size transformed init often becomes:

- an explicit bounds-or-drop-state check
- then maybe the rewritten drops later

This is why several official tests focus on zero-size cases specifically.

## Startup-trapping active segments: the "keep the top byte" rule

For active segments, if the original segment might trap during instantiation and TNH is not enabled, Binaryen preserves that effect by keeping the topmost byte that would be written.

Even if that byte is itself zero, Binaryen forces it to remain as a kept nonzero range in bookkeeping.

Why the top byte?

- Writing that final address is enough to recreate the same out-of-bounds trap.
- Keeping anything more would be unnecessary.

This is one of the best examples of an optimization that looks strange until you remember it is preserving **effects**, not just values.

## Imported memory and `--zero-filled-memory`

For module-defined memory, Binaryen knows startup memory begins zeroed.
For imported memory, it does not know that by default.

So upstream only optimizes imported-memory cases when the pass option says that imported memory is also zero-filled.

This matters because otherwise removing a zero run from an active segment would silently assume the host already provided zero bytes there.
That is not generally safe.

## Memory64 and high-bit immediates

The dedicated `memory-packing_memory64-high-addr.wast` file locks in an easy-to-miss rule:

- some segment offsets and `memory.init` immediates are stored as i32 constants even when they represent large unsigned byte positions
- when the high bit is set, those values must be interpreted as large unsigned quantities, not as negative signed numbers

So the pass uses unsigned and checked arithmetic carefully here.

## GC data-segment users are currently a conservative boundary

The pass can discover `array.new_data` and `array.init_data` referrers, but in `version_129` it mostly reacts by refusing to split those segments.

Why that conservatism makes sense:

- those instructions consume data segments too
- splitting or renumbering them without a full rewrite would be unsafe

So the current upstream policy is:

- recognize the GC user
- keep the segment intact
- leave fancy GC-aware splitting for later work

## Easy misunderstandings to avoid

### Wrong idea 1

- If the bytes are zero, they are always removable.

Why wrong:

- zero bytes can still matter for startup traps, passive dropped-state semantics, or active-segment trampling.

### Wrong idea 2

- `memory.fill` is always an acceptable replacement for zero bytes.

Why wrong:

- only if dropped-segment trapping and source-layout semantics are also preserved.

### Wrong idea 3

- `data.drop` rewriting is bookkeeping, not semantics.

Why wrong:

- dropped-state is observable because later `memory.init` can trap.

### Wrong idea 4

- The local Starshine active-segment implementation explains the whole upstream pass.

Why wrong:

- it explains only the easiest active subset, not the passive/user-rewrite half.

## Practical future-port checklist

If a future Starshine port grows toward full Binaryen parity, keep this checklist handy:

- simplify active `memory.init` / active `data.drop` first
- preserve zero-size trap behavior explicitly
- preserve dropped-passive-segment trap behavior explicitly
- add lazy drop-state globals only when a leading `memory.fill` requires them
- keep startup-trap top-byte retention separate from passive dropped-state logic
- do not assume imported memory starts zeroed without an explicit guarantee
- keep memory64/high-bit arithmetic unsigned and checked
- keep GC array-data users conservative until a full rewrite story exists
