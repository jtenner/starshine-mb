# SGO loop independent local-set prefix

Date: 2026-05-25

## Slice

`[SGO]003C5` / loop-specific read-only-to-write FlowScanner breadth.

## Goal

Extend the narrow loop-prefix matcher from [`0677`](./0677-2026-05-25-sgo-loop-independent-global-set-prefix.md) to one more exact Binaryen-positive independent effect: a constant `local.set` before the yielded candidate-global read.

## Source evidence

A focused Binaryen probe with `wasm-opt --simplify-globals-optimizing -S --all-features` showed that this shape removes the fake `$g` traffic while preserving the independent local write's observable consequence through a later exported `$sink` write:

```wat
(loop (result i32)
  i32.const 7
  local.set $x
  global.get $g
)
(if
  (then
    i32.const 1
    global.set $g
  )
)
local.get $x
global.set $sink
```

Binaryen rewrites the function to the semantic equivalent of `global.set $sink (i32.const 7)` and promotes `$g` to immutable. This is narrower than the full block FlowScanner and does not imply branchy, trapping, call, growth, or broader effect prefixes are safe in loops.

## Implementation

Updated `sgo_loop_condition_independent_global_set_prefix_read_matches(...)` in `src/passes/simplify_globals_optimizing.mbt`.

The loop-specific matcher now allows prefix pairs of:

- `const; global.set <different global>` from [`0677`](./0677-2026-05-25-sgo-loop-independent-global-set-prefix.md), and
- `const; local.set <any local>` from this slice.

It still requires the flattened loop body to end in exactly one `global.get` of the candidate and still applies only to the direct no-else same-global constant-set guard. It does not reuse the broad block scanner inside loops.

## Tests

Added `simplify-globals-optimizing removes loop-wrapped independent local-set effect prefixes` in `src/passes/simplify_globals_optimizing_test.mbt`.

The regression keeps `$sink` exported so the local write remains semantically observable, expects `$once` to become immutable, and checks that the fake candidate `global.get` disappears while the independent `local.set` / exported `global.set` path remains.

## Validation

- TDD failure before implementation: `moon test src/passes` failed at the new local-set loop-prefix regression because `$once` remained mutable.
- Focused pass tests after implementation: `moon test src/passes` passed (`1613/1613`) with the existing DAE/pass-manager warnings.
- Standard Moon validation: `moon fmt`, `moon info`, and full `moon test` passed (`3689/3689`), with existing DAE warnings during `moon info`.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-localset-0678-10000` compared `6759/10000` before the configured `20` Binaryen/tool command-failure stop, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `0` generator failures.

## Classification

This is a semantic-safe Binaryen-positive behavior implementation. The accepted family is limited by an explicit probe and a narrow transform contract: the independent local write has a constant operand and does not consume the candidate global, while the yielded loop value is the single candidate read used by the same-global guard. No fuzz mismatch is attributed to this slice.
