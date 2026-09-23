---
kind: concept
status: supported
last_reviewed: 2026-09-12
sources:
  - ../../release-horizon-and-oracles.md
  - ./index.md
  - index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `memory-packing`: segment-op rewrites and traps

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

This page exists because the hardest part of Binaryen `memory-packing` is **not** “find zero bytes.”
It is preserving the behavior of segment-using instructions after the raw segment bytes change.

## September 12 correctness invariants

This supersedes earlier descriptions that allowed active runtime reads using the
initialization byte length, dropped zero-length checks, or tied passive lifetime
checks to the first retained range. Active runtime source length is zero after
instantiation. Initialization bytes and retained physical ranges do not represent
runtime liveness.

Every split passive segment has an independent lifetime. The initial repair
represented each with a generated global. The size follow-up supersedes that
storage choice: retained data parts carry the lifetime because every original
`data.drop` drops all its parts. A leading nonempty retained copy checks lifetime
before its own first write. If reconstruction starts with a fill, or a nonzero
source offset has zero length, a zero-length `memory.init` at destination 0,
source 1 probes a retained part first. Retained parts have at least one byte
while live; after drop the same probe traps without writing. Source 0/length 0
needs no lifetime check. Byte-free segments still get independent globals when
any `data.drop` exists; without a drop instruction they remain live forever.
This is a per-operation proof, not an assumption about the full segment's first
range. No calls or original operand evaluations intervene between preflight and
replacement writes. Dropping one segment cannot affect another.

For dynamic destinations, the preflight first checks `destination >> 16 <= memory.size`, then
checks `ceil(((destination & 65535) + length) / 65536)` against the remaining
pages. This avoids computing an unrepresentable full memory byte size, handles
Memory32 and Memory64 at their unsigned limits, and checks zero-length offsets.
For constant destinations, the optimizer computes the full required page count
and omits the runtime check only when the memory's declared minimum proves the
complete range fits (memory can grow but cannot shrink). Otherwise it emits one
comparison with `memory.size`; it separately handles an endpoint
of exactly 2^64 and rejects larger endpoints without wrapping.
Source constants are checked against the complete original live segment length.
All checks precede the first write; destination expressions are evaluated once.
Overflowing active retained-byte addresses keep the original segment rather than
wrapping or saturating a trap marker. Active segments with GC data users are
retained so storage removal cannot leave invalid remapped data indices.

The local verified `wasm-opt version 132 (version_132-49-gd03c25ea4)` also
incorrectly removes the instantiation trap for `(memory 65536)` with an active
`"\00\00"` segment at `(i32.const -1)`. The `full32-marker` execution regression
compares against the original module and preserves this trap. Matching that
oracle's output would reintroduce a demonstrated correctness bug. The separate
full-Memory32 zero-length runtime copy at destination `-1` succeeds in the
original and Starshine output but traps in this oracle's output. In the initial
96-case execution matrix, the same oracle matched 92 originals; four Memory32/64
full-segment out-of-bounds copies (including effectful destinations) trapped after
changing memory. Complete preflight is therefore a demonstrated semantic
correctness improvement even when canonical output differs from this oracle.

Implementation: [memory_packing.mbt](../../../../../src/passes/memory_packing.mbt).
Regression evidence: [white-box tests](../../../../../src/passes/memory_packing_wbtest.mbt)
and [runtime tests](../../../../../scripts/test/optimizer-correctness-runtime.ts),
which validate both modules and compare full exported memory, mutable globals,
results, and traps under Node, including Memory64.

Validation on this repair: the original 125 execution regressions pass; the
shared suite now has 127 with the imported-global alias follow-up,
including full 4 GiB Memory32 end-byte observations without full-memory copying;
41 focused memory-packing tests, 10 helper tests, and 319 CLI tests pass.
Before constant-check folding, `bun validate full --profile ci --target wasm-gc`
passed all 11,311 tests and 100,772 attempts across 14 CI fuzz suites. After the
refinement, all 10 memory helper tests pass on wasm-gc and the default
`moon test` passed 11,316/11,316 before the imported-global alias follow-up.
The final full wasm-gc gate, including that follow-up, passes 11,315 tests and
100,768 attempts across 14 CI fuzz suites (seed `117260405384703254`).
`moon info`, `moon fmt --check`, API sync,
and the CI workflow contract pass with no public `.mbti` changes.

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

The new implementation/test-map page makes that phase split explicit, which helps avoid teaching these rewrites as an incidental prepass instead of a real owned part of `MemoryPacking.cpp`.

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

That is the central passive-segment idea. It is only profitable above Binaryen's referrer-sensitive threshold: passive metadata contributes `2`, each `memory.init` contributes `19` for an interior split and `9` at an edge, and each `data.drop` contributes `3` to an interior split. Starshine matches those thresholds; a smaller valid zero run is deliberately retained rather than expanded into larger runtime code.

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

The local rewrite and user-discovery walkers also traverse decoded legacy `try` protected bodies and every typed/catch-all handler. Segment indices and replacement sequences are rewritten inside those regions without changing the try block type, catch ordering, tags, catch-all shape, or delegate target.

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

A released v131 rule now matters for active overlaps: merged PR #8882 allows a narrow imported-memory overlap path only when this option is enabled and every active segment is provably within the declared allocation. It neutralizes bytes from an earlier segment that a later segment tramples before range packing. This is not a general relaxation of overlap safety. Starshine now implements the same source-order cleanup and imported all-active-segments in-bounds gate, including overflow-safe memory64 page-count reasoning. See [`index.md`](index.md).

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

## 2026-07-21 operand-boundary correction

The passive-segment `memory.init` operand scanner uses the validator's stack
deltas for `table.set`, `array.copy`, `br_on_null`, `ref.test_desc`, and
`ref.cast_desc_eq`. `ref.test_desc` consumes one reference and produces one
`i32`; the cast scanner models the current two-operand descriptor binary form
while the validator also accepts older local one-operand cast fixtures. The earlier
two-operand `ref.test_desc` scanner claim and white-box expectation were wrong.
Incorrect deltas can make `mp_find_value_start` splice an enclosing pending
stack value into the destination expression or decline a valid rewrite. The
white-box count and active dispatcher regression now cover a valid one-operand
descriptor test before `memory.init`.

When MemoryPacking emits a changed data section, its module rebuild carries
`compiler_fact_custom_section` forward unchanged. The direct pass and active
dispatcher regressions in `memory_packing_test.mbt` start with structured facts
and a profitable active zero-range rewrite, then assert the optimized segment
and preserved facts. The facts are independent metadata and do not become
invalid merely because data segments were packed.

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
