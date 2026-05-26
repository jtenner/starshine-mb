# SGO function-effect read summary study

Date: 2026-05-25

Slice: `[SGO]003I` Runtime Function-Effect Summary Reads/Writes Upgrade

## Scope

Audit whether `simplify-globals-optimizing` needs callee global-read summaries in addition to the current callee global-write summaries before any broader call-shaped read-only-to-write work. This is a research/design slice only: no optimizer behavior changed.

## Current Starshine model

Source audit of `src/passes/simplify_globals_optimizing.mbt` found two distinct call paths:

- **Runtime trace replacement:** `sgo_collect_function_global_effects(...)` builds a fixed-point direct-call summary of globals each function may mutate. Imported functions start as mutating every global. Dynamic calls (`call_indirect`, `call_ref`, return-call dynamic forms) mark all globals. `sgo_runtime_trace_clear_call_effects(...)` then clears only facts for globals the direct callee may mutate.
- **Syntactic read-only-to-write guards:** FlowScanner-style condition matchers treat calls as allowable only when the current candidate-derived stack is not tainted. Calls can be preserved as independent effects, but calls do not themselves prove or consume a local syntactic candidate read. Existing tests in `src/passes/simplify_globals_optimizing_test.mbt` keep get-call, set-call, get+set-call, wrong-global, dynamic-call operand, and generated-effects-shaped negatives visible.

The current write-only summary is therefore enough for the landed runtime fact propagation slice, but it is not enough to safely decide whether a call can participate in read-only-to-write removal. For that decision, a callee read of the candidate global is observable: removing the surrounding fake global traffic could change which value the callee reads or could reduce the total reads below Binaryen's safe pattern count.

## Binaryen probes

Ad hoc probes were run under `.tmp/sgo003i-probes` with:

```sh
wasm-opt --all-features --simplify-globals-optimizing -S <fixture>.wat -o -
```

Relevant reduced fixtures used a mutable `$g` initialized to `0`, a final same-global write of `1`, and a call in the condition expression.

### Direct call with no candidate-global read

Shape:

```wat
(global $g (mut i32) (i32.const 0))
(func $tick)
(func (export "run")
  (if (i32.add (global.get $g)
               (block (result i32) (call $tick) (i32.const 0)))
    (then (i32.const 1) (global.set $g))))
```

Binaryen output made `$g` immutable and preserved only `call $tick` in `run`. This is a positive for independent direct calls that neither read nor write the candidate global.

### Direct call that reads the candidate global

Shape:

```wat
(global $g (mut i32) (i32.const 0))
(func $read (result i32) (global.get $g))
(func (export "run")
  (if (i32.add (global.get $g) (call $read))
    (then (i32.const 1) (global.set $g))))
```

Binaryen preserved `$g` as mutable, kept `global.get $g` inside `$read`, and kept the outer read/write guard. This is the key negative: callee reads of the candidate global must block call-shaped read-only-to-write removal.

### Direct call that writes the candidate global

Shape:

```wat
(global $g (mut i32) (i32.const 0))
(func $write (i32.const 2) (global.set $g))
(func (export "run")
  (if (i32.add (global.get $g)
               (block (result i32) (call $write) (i32.const 0)))
    (then (i32.const 1) (global.set $g))))
```

Binaryen eliminated both writes and left `call $write` with a `nop` body, making `$g` immutable. This does **not** justify a broad Starshine positive by itself: Binaryen can globally reason that the post-call write and callee write are fake global traffic when no remaining read observes them. Starshine should not infer local call transparency from this one shape without a read/write summary and paired observable-read negatives.

## Design conclusion

Do not implement call-shaped read-only-to-write positives with the current write-only summary alone.

If `[SGO]003E` later accepts call-shaped positives, first extend the summary data structure from:

```moonbit
SgoFunctionGlobalEffects::{ mutates: Array[Bool] }
```

to a fixed-point summary with at least:

- `reads: Array[Bool]`
- `mutates: Array[Bool]`
- conservative all-read/all-write rows for imports and dynamic/escaping calls
- direct-call transitive closure over both reads and writes
- cycle handling by monotone fixed point, matching the current mutation summary style

Proposed acceptance contract for any future call-positive implementation:

- A direct call may be considered independent for syntactic read-only-to-write only when every operand is candidate-clean, the callee summary says it does **not** read or write the candidate global, and no dynamic/imported/escaping call is reachable from that callee.
- A direct call that reads the candidate global is a hard negative, even if it does not mutate the global.
- A direct call that mutates the candidate global requires separate proof; do not accept it just because Binaryen can remove a narrow no-read fixture.
- Imported calls, indirect calls, `call_ref`, `return_call`, recursive cycles with unknown summaries, and candidate-derived call operands remain conservative.

## Recommended next tests if implementation resumes

Behavior-bearing follow-up should add tests first for:

1. direct no-read/no-write positive if Binaryen probe is adopted,
2. direct callee-read negative,
3. direct callee-write negative or explicitly deferred status,
4. wrong-global read/write separation,
5. imported call barrier,
6. indirect / `call_ref` / return-call barriers,
7. recursive cycle fixed-point behavior.

## Status

`[SGO]003I` is complete as a research/design slice. It produces a prerequisite design and probe evidence for `[SGO]003E`, but it intentionally leaves behavior unchanged. `[SGO]003` remains active/partial and no full Binaryen `SimplifyGlobals.cpp` parity claim is made.
