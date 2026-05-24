# SGO next breadth probe inventory

_Date:_ 2026-05-23  
_Status:_ filed into living SGO docs/backlog

## Question

After the loop self-guard micro-series, pick the next low-risk `[SGO]003` breadth direction without assuming full Binaryen `SimplifyGlobals.cpp` parity. The goal was to rank a few source-backed candidates and avoid spending an implementation slice on shapes Binaryen itself does not currently rewrite.

## Sources and commands

Primary local source anchors:

- `docs/wiki/raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/starshine-strategy.md`
- `src/passes/simplify_globals_optimizing.mbt`
- `src/passes/simplify_globals_optimizing_test.mbt`

Binaryen probe command pattern:

```sh
/usr/local/bin/wasm-opt --all-features --simplify-globals-optimizing -S -o - .tmp/<probe>.wat
```

## Probe outcomes

### 1. Same-as-init direct literal with a real later read: Binaryen positive, already covered locally

Shape:

```wat
(module
  (global $g (mut i32) (i32.const 7))
  (func $set (global.set $g (i32.const 7)))
  (func $read (result i32) (global.get $g))
  (export "set" (func $set))
  (export "read" (func $read))
)
```

Binaryen promoted `$g` immutable, rewrote `$set` to `nop`, and rewrote `$read` to `i32.const 7`.

Conclusion: useful as a baseline only. Starshine already has direct literal same-init coverage and repeated-run guardrails for narrower alias/init cases.

### 2. Same-as-init value hidden in a result block with a real later read: Binaryen negative

Shape:

```wat
(module
  (global $g (mut i32) (i32.const 7))
  (func $set
    (global.set $g
      (block (result i32)
        (i32.const 7))))
  (func $read (result i32) (global.get $g))
  (export "set" (func $set))
  (export "read" (func $read))
)
```

Binaryen preserved the mutable global, the block-wrapped set value, and the later `global.get`.

Conclusion: do not implement this as “broader expression equivalence.” Even though the value is obviously constant after other simplification, current SGO's same-init scan does not use this as a constant expression for the read-present case.

### 3. Alias initializer then direct literal same-init write: Binaryen needs care and did not remove in the one-shot probe

Shape:

```wat
(module
  (global $c i32 (i32.const 7))
  (global $g (mut i32) (global.get $c))
  (func $set (global.set $g (i32.const 7)))
  (func $read (result i32) (global.get $g))
  (export "set" (func $set))
  (export "read" (func $read))
)
```

Binaryen rewrote `$g`'s initializer to `i32.const 7` but preserved `$g` as mutable and kept the set/read in this direct run.

Conclusion: repeated-run and alias-init behavior is subtle. Do not broaden same-init aliasing without a focused fixture that proves the exact one-run/two-run behavior intended for Starshine.

### 4. Constant `global.set` fact feeding an `else` arm read: Binaryen negative

Shape:

```wat
(module
  (global $g (mut i32) (i32.const 0))
  (func $f (result i32)
    (global.set $g (i32.const 7))
    (if (result i32)
      (i32.const 0)
      (then (i32.const 1))
      (else (global.get $g))))
  (export "f" (func $f))
)
```

Binaryen preserved the `global.get` in the else arm.

Conclusion: keep Starshine's else-arm runtime propagation conservative. This is a good guardrail probe, not an implementation candidate.

### 5. Runtime trace constant set where the set operand is a result block: Binaryen negative

Shape:

```wat
(module
  (global $g (mut i32) (i32.const 0))
  (func $f (result i32)
    (global.set $g
      (block (result i32)
        (i32.const 5)))
    (global.get $g))
  (export "f" (func $f))
)
```

Binaryen preserved the `global.get`.

Conclusion: do not broaden runtime trace facts to block-wrapped constants just because the nested cleanup path might later make them literal.

## Ranking for next `[SGO]003` work

1. **Best next implementation candidate: exact `simplify-globals-dominance.wast` linear-trace subshapes not already covered by local tests.** Start by comparing Starshine's current runtime propagation tests against the official dominance lit cases and add only a Binaryen-positive straight-line or dominated-then fixture with paired call/control/write barriers. Avoid else joins; the probe above confirmed the else-read shape is not a positive.
2. **Good docs/test-only candidate: same-init guardrail coverage for expression-looking negatives.** The block-wrapped same-init and block-wrapped runtime-set probes are useful negatives if local tests do not already pin them. They prevent an over-eager expression-equivalence implementation.
3. **Medium/high risk: broader same-init expression matching.** Current probes found more negatives than positives beyond direct literals. Require an exact Binaryen-positive expression before coding.
4. **High risk: GC/refinalization replacement breadth and typed element item replacement.** These remain source-backed gaps, but they need type/refinalization fixtures and should not be batched with value-flow work.
5. **Do not continue loop broadening by default.** The current loop subset is intentionally bounded; branch/control/trapping/effectful loop bodies need fresh oracle positives and negatives.

## Non-claims

- This note does not claim full SGO parity.
- It does not replace the 2026-05-18 current-main source refresh; it only narrows the immediate next probes after the loop micro-series.
- Binaryen probe outputs were inspected for transformed shape, not committed as artifacts.
