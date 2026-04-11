# 0074 - Binaryen Multivalue Call Local Disparity

## Scope

- Explain why Binaryen creates extra locals around reduced multivalue call repros even when no optimization pass runs.
- Separate that behavior from the `reorder-locals` pass itself.
- Decide whether matching those extra locals is a meaningful requirement for Starshine `reorder-locals` parity.

## Conclusion

- The extra locals are not created by `ReorderLocals.cpp`.
- They are created by Binaryen's multivalue read/write boundary:
  - the IR builder reads multivalue calls as tuple-valued `Call` expressions
  - when stack consumers need individual elements, the IR builder hoists the tuple into scratch locals and emits `tuple.extract`
  - the binary writer then expands tuple locals back into multiple scalar wasm locals and may allocate additional scalar scratch locals to lower `tuple.extract`
- On the minimal imported-call witness, one Binaryen roundtrip adds exactly the shape needed to explain the observed `+5` local growth:
  - one tuple scratch local of type `(tuple i32 i32 i32)`, which writes out as `3` scalar wasm locals
  - two scalar scratch locals that stage extracted values while preserving stack order
- That means raw emitted-wasm parity for `reorder-locals` is currently testing Binaryen's multivalue call materialization layer, not the local-sorting algorithm.
- For this pass specifically, porting that layer does not look necessary unless Starshine wants Binaryen-style raw emitted-wasm parity for multivalue call writeback as an independent goal.

## Oracle Version

- Local toolchain check:
  `wasm-opt --version` reports `wasm-opt version 125 (version_125)`.
- This note treats Binaryen `version_125` as the canonical source.

## Primary Sources

- Binaryen README:
  - `README.md:72-84`
- Binaryen IR builder:
  - `src/wasm/wasm-ir-builder.cpp:54-142`
  - `src/wasm/wasm-ir-builder.cpp:455-480`
  - `src/wasm/wasm-ir-builder.cpp:1380-1389`
- Binaryen stack writer:
  - `src/wasm-stack.h:45-52`
  - `src/wasm-stack.h:149-157`
  - `src/wasm/wasm-stack.cpp:175-223`
  - `src/wasm/wasm-stack.cpp:2257-2278`
  - `src/wasm/wasm-stack.cpp:2895-3030`
- Existing local pass note:
  - [0073](./0073-2026-04-02-reorder-locals-binaryen-comparison.md)

## Binaryen IR Facts That Matter

- Binaryen's README explicitly says its IR is tree-based, not a direct model of wasm's stack machine.
- The same README also says stacky and multivalue code is represented with tuple types that do not exist in wasm itself.
- Binaryen therefore allows tuple-typed locals and tuple operations in IR even though wasm binaries do not.
- The README also notes that better native multivalue support in the core IR looked like a small win, so Binaryen did not redesign the entire IR around exact wasm multivalue shape.

That means Binaryen must do real lowering work at both boundaries:

- reading wasm into Binaryen IR
- writing Binaryen IR back to wasm binary

The observed extra locals live in that boundary code.

## Reader-Side Cause

The first half of the disparity is in the IR builder.

- `makeCall(...)` constructs a `Call` with the full tuple result type from the callee signature.
- When later consumers need a specific number of stack values, `pop(size)` calls `hoistLastValue()` and `packageHoistedValue(...)`.
- If the hoisted value is a tuple and it needs to be broken apart, `packageHoistedValue(...)`:
  - allocates a scratch local for the tuple if one does not already exist
  - rewrites the top value into `tuple.extract(..., 0)`
  - pushes additional `tuple.extract(local.get scratch, i)` nodes for the later tuple elements

The important consequence is that a plain multivalue call in wasm is not kept as a raw wasm-like stack sequence in Binaryen IR. It becomes:

- a tuple-valued `Call`
- plus a tuple scratch local
- plus explicit `tuple.extract` nodes when the caller wants the individual results

That is already outside `reorder-locals`.

## Writer-Side Cause

The second half is in the StackIR/binary writer.

- `wasm-stack.h` documents scratch locals used to lower `tuple.extract`.
- `visitLocalGet` and `visitLocalSet` in `wasm-stack.cpp` expand tuple locals into per-element binary locals.
- `visitTupleExtract` emits the lowering:
  - if the tuple source is already a `local.get`, `local.tee`, or `global.get`, Binaryen can optimize and directly get the needed extracted element
  - otherwise Binaryen lowers nonzero extracts by saving to a scratch local, dropping the unwanted stack values, then reloading the desired value
- `mapLocalsAndEmitHeader()` and `countScratchLocals()` explicitly account for:
  - tuple locals
  - tuple scratch locals
  - other locals needed to resolve stacky format

So even with no optimization pass, Binaryen may emit more wasm locals than existed in the input because tuple IR locals must be scalarized again for the binary format.

## Minimal Imported-Call Witness

This reduced witness is enough to expose the behavior:

```wat
(module
  (type $triple_t (func (param i32 i32) (result i32 i32 i32)))
  (type $combine_t (func (param i32 i32 i32) (result i32)))
  (import "env" "triple" (func $triple (type $triple_t)))
  (import "env" "combine" (func $combine (type $combine_t)))
  (func (param i32) (result i32)
    (local i32 i32 i32 i32 i32 i32)
    i32.const 100
    local.set 1
    local.get 0
    local.get 1
    call $triple
    local.set 4
    local.set 3
    local.set 2
    local.get 4
    local.tee 5
    local.set 6
    local.get 3
    local.set 6
    local.get 2
    local.get 5
    local.get 6
    call $combine))
```

Printing Binaryen StackIR with no passes:

```text
wasm-opt /tmp/rl-call3-min.wat --all-features --print-stack-ir -o /tmp/rl-call3-min.wasm
```

shows the key extra locals and the exact staging pattern:

```text
(local $scratch (tuple i32 i32 i32))
(local $scratch_8 i32)
(local $scratch_9 i32)
...
call $triple
local.tee $scratch
tuple.extract 3 0
local.set $scratch_9
local.get $scratch
tuple.extract 3 1
local.set $scratch_8
local.get $scratch
tuple.extract 3 2
local.set $4
local.get $scratch_8
local.set $3
local.get $scratch_9
local.set $2
```

This is the full explanation for the `+5` local jump:

- original witness body locals: `6`
- Binaryen-added tuple scratch local: `+1` IR local, but it writes out as `+3` scalar wasm locals
- Binaryen-added scalar staging locals: `+2`
- total emitted-wasm growth per roundtrip: `+5`

That matches the observed `11 -> 16 -> 21 -> 26` style growth on the internal/imported reduced call families.

## Why The Call Case Keeps Growing

The critical point is that the multivalue call itself survives every roundtrip.

- After one Binaryen roundtrip, the emitted binary still contains a multivalue `call`.
- On the next read, `makeCall(...)` reconstructs that as a tuple-valued Binaryen `Call`.
- The IR builder then has to split that tuple again for the downstream scalar consumers.
- The stack writer then scalarizes the new tuple scratch local again on output.

So the same boundary logic re-runs every time. The call remains a live multivalue producer, and the Binaryen IR/binary conversion keeps rebuilding the tuple-materialization scaffolding around it.

That is why no-pass call roundtrips keep growing instead of converging.

## Why The Block Witness Can Stabilize

A matching block-only witness shows a different outcome.

```wat
(module
  (type $combine_t (func (param i32 i32 i32) (result i32)))
  (import "env" "combine" (func $combine (type $combine_t)))
  (func (result i32)
    (local i32 i32 i32 i32 i32 i32 i32)
    block (result i32 i32 i32)
      i32.const 10
      i32.const 20
      i32.const 30
    end
    local.set 4
    local.set 3
    local.set 2
    local.get 4
    local.tee 5
    local.set 6
    local.get 3
    local.set 6
    local.get 2
    local.get 5
    local.get 6
    call $combine))
```

The first StackIR print still introduces tuple machinery:

- one tuple scratch local
- one scalar scratch local for staging
- one more scalar local used in the emitted scalar chain

But repeated no-pass roundtrips settle quickly:

- round 1 still contains scratch-based tuple staging
- round 2 is scalar-only and stable
- round 3 matches round 2

The reason is that the block source does not persist as an irreducible multivalue producer in the same way the call does. Once Binaryen has scalarized that value flow into a simple local chain, rereading the binary does not force it back through the same tuple-valued call path.

In short:

- multivalue blocks can collapse into a stable scalar form
- multivalue calls remain multivalue calls, so the same tuple packaging path keeps reappearing

## Implication For `reorder-locals`

This disparity is upstream and downstream of `reorder-locals`, not inside it.

- `ReorderLocals.cpp` only counts local accesses, sorts body locals, and drops zero-count locals.
- The extra locals appear before and after that pass because Binaryen's multivalue boundary code creates them.
- Starshine's current `reorder-locals` implementation already matches the raw Binaryen sort rule on the actual pass algorithm.

So the remaining raw compare failure does **not** mean:

- Starshine sorts locals differently from Binaryen
- Starshine rewrites local indices incorrectly
- `reorder-locals` itself is still missing a call-specific tie-break rule

It means the two engines are not sorting the same effective local set once Binaryen's multivalue call materialization layer is involved.

## Recommendation

For the `reorder-locals` slice, the honest options are:

1. Define parity at a representation-stable boundary instead of raw emitted wasm.
   - The new `--binaryen-nop-roundtrips <n>` and `--binaryen-nop-until-stable <max>` compare-tool options are enough to make that explicit.
   - `--require-binaryen-nop-converged` can now enforce that a self-opt compare only counts as valid if the until-stable boundary actually converges.
   - Live reduced-witness proof:
     - `bun scripts/self-optimize-compare.ts /tmp/rl-block3-min.wasm --binaryen-nop-until-stable 5 --require-binaryen-nop-converged --reorder-locals` converges after `2` no-pass rounds and compares green.
     - `bun scripts/self-optimize-compare.ts /tmp/rl-call3-min.wasm --binaryen-nop-until-stable 5 --require-binaryen-nop-converged --reorder-locals` fails immediately with `Binaryen no-pass writeback did not converge within 5 roundtrips`.
2. Treat non-converging multivalue-call writeback as out of scope for `reorder-locals`.
   - The pass is done once raw sort parity and stable-boundary parity are proven.
3. Only port Binaryen's multivalue call materialization layer if Starshine wants broader raw emitted-wasm parity for Binaryen's read/write boundary.

My read after this investigation is that option `2` is the most honest near-term target.

Porting this machinery purely to make `reorder-locals` artifact bytes line up does not buy confidence in the sorter itself. It buys confidence that Starshine also reproduces Binaryen's tuple-packaging and scratch-local writeback strategy for multivalue calls.
