# SGO call and effect boundary study

Date: 2026-05-25

Slice: `[SGO]003E` Read-Only-To-Write Call And Effect Boundary Study

## Scope

Decide whether call-shaped read-only-to-write positives are source-backed enough to implement now, and how they relate to the `[SGO]003I` read-summary design in [`0634`](./0634-2026-05-25-sgo-function-effect-read-summary-study.md). This is a research slice only: no optimizer behavior changed.

## Probe command

Ad hoc fixtures were written under `.tmp/sgo003e-probes` and checked with:

```sh
wasm-opt --all-features --simplify-globals-optimizing -S <fixture>.wat -o -
```

All fixtures use a candidate mutable global `$g` initialized to `0` and an outer no-else same-global write of `1`, so removing the write is not merely same-init removal.

## Probe results

### Candidate-derived call operand

Shape:

```wat
(global $g (mut i32) (i32.const 0))
(func $use (param i32))
(func (export "run")
  (if (block (result i32) (global.get $g) (call $use) (global.get $g))
    (then (i32.const 1) (global.set $g))))
```

Binaryen preserved the mutable global, the `global.get $g` operand to `call $use`, the later `global.get $g`, and the `global.set $g`. This confirms the strongest Starshine guardrail: a candidate-derived call operand is not a read-only-to-write event.

### Direct no-read/no-write call

The direct no-read/no-write call probe from [`0634`](./0634-2026-05-25-sgo-function-effect-read-summary-study.md) was Binaryen-positive: Binaryen made `$g` immutable and preserved only the independent call effect.

This is the only low-noise positive found so far, but it requires a read summary to distinguish from the next negative.

### Direct callee reads candidate global

The direct callee-read probe from [`0634`](./0634-2026-05-25-sgo-function-effect-read-summary-study.md) was Binaryen-negative: Binaryen preserved `$g` as mutable and kept the outer guard. A callee read of the candidate global is therefore a hard blocker for local call transparency.

### Direct callee writes candidate global

The direct callee-write/no-remaining-read probe from [`0634`](./0634-2026-05-25-sgo-function-effect-read-summary-study.md) was Binaryen-positive in that reduced module, but it should not be treated as a general local-call transparency rule. It depends on global no-read reasoning and removal of both the callee write and outer write as fake traffic. Starshine should keep this deferred until a broader global-effect proof exists.

### Imported call

Shape:

```wat
(import "env" "tick" (func $tick))
(global $g (mut i32) (i32.const 0))
(func (export "run")
  (if (i32.add (global.get $g)
               (block (result i32) (call $tick) (i32.const 0)))
    (then (i32.const 1) (global.set $g))))
```

Binaryen made `$g` immutable and preserved `call $tick`. A variant with an exported `$set` function that writes `$g` was also Binaryen-positive: Binaryen removed `$set`'s write and left `call $tick` in `run`.

This is source evidence that Binaryen can be more aggressive around imported calls than Starshine's current conservative runtime fact model. It is not a safe next implementation target without modeling Binaryen's generated-effects / whole-module visibility assumptions. Starshine should not use this probe alone to mark imported calls transparent.

### Indirect call with clean operands

Shape:

```wat
(type $t (func))
(table 1 funcref)
(elem (i32.const 0) $tick)
(global $g (mut i32) (i32.const 0))
(func $tick)
(func (export "run")
  (if (i32.add (global.get $g)
               (block (result i32)
                 (i32.const 0)
                 (call_indirect (type $t))
                 (i32.const 0)))
    (then (i32.const 1) (global.set $g))))
```

Binaryen made `$g` immutable and preserved the `call_indirect`. As with imported calls, this is a Binaryen-positive probe but not an immediate Starshine implementation target. It requires target/effect reasoning that Starshine does not currently expose to the SGO local matcher.

### Wrong-global read

Shape:

```wat
(global $g (mut i32) (i32.const 0))
(global $h (mut i32) (i32.const 0))
(func $read_h (result i32) (global.get $h))
(func (export "run")
  (if (i32.add (global.get $g) (call $read_h))
    (then (i32.const 1) (global.set $g))))
```

Binaryen made both globals immutable and preserved only `call $read_h` with its result dropped. Wrong-global reads can be independent for the candidate `$g`, but implementing this safely still requires read/write summaries by global.

## Decision

Do **not** implement `[SGO]003E` behavior now.

The probes prove there are Binaryen-positive call-shaped cases, but they are not safely representable in Starshine's current local syntactic matcher:

- candidate-derived call operands are definitely negative,
- direct callee reads of the candidate global are definitely negative,
- direct wrong-global/no-read cases require per-global read summaries,
- callee-write positives require whole-module no-read/fake-traffic reasoning beyond a local call whitelist,
- imported and indirect positives require generated-effects / target visibility semantics that Starshine has not modeled for SGO.

## Future implementation plan

A future behavior-bearing call slice should be split after a summary upgrade, not landed as broad matcher tolerance:

1. Extend `SgoFunctionGlobalEffects` to include fixed-point per-global `reads` and `mutates` arrays, preserving conservative all-read/all-write behavior for unknown dynamic/imported/escaping calls until generated-effects semantics are deliberately modeled.
2. Add tests before implementation for direct no-read/no-write positive, wrong-global read positive, callee candidate-read negative, candidate-derived operand negative, imported/dynamic barriers, and recursive-cycle summaries.
3. Only then allow direct ordinary calls in read-only-to-write condition scanning when operands are candidate-clean and the transitive callee summary neither reads nor mutates the candidate global.
4. Keep callee-write/no-remaining-read and imported/indirect positives separate until their whole-module/generated-effects proof is explicit.

## Status

`[SGO]003E` is complete as a research/boundary slice and deferred for behavior. The active implementation backlog should prefer `[SGO]003B` or `[SGO]003G` wrapper composition, or a new dedicated read/write-summary implementation slice if call behavior becomes the priority. `[SGO]003` remains active/partial; this note does not claim full Binaryen `SimplifyGlobals.cpp` parity.
