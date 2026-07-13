---
kind: concept
status: supported
last_reviewed: 2026-05-19
sources:
  - ../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dae-optimizing/index.md
  - ../inlining-optimizing/index.md
---

# `simplify-globals-optimizing`: linear traces, `read-only-to-write`, and reruns

This page focuses on the parts of Binaryen `simplify-globals-optimizing` that are easiest to misunderstand.
It is anchored to the retained 2026-04-24 research inventory, direct tagged source URLs, and the 2026-04-25 readiness bridge:

- why startup-time propagation is broader than runtime code propagation
- what `read-only-to-write` really means in the source
- why actual AST `global.get` / `global.set` nodes matter more than effect summaries there
- why the optimizing rerun is part of the real pass contract

## The big beginner warning

If you summarize the pass as:

- “constant-fold global reads”

you will miss most of the implementation.

The real story is closer to:

- “use whole-module global traffic facts to remove fake state, collapse easy one-time indirections, and propagate only the values Binaryen can still justify safely in the current context.”

## 1. Startup-time propagation and runtime propagation are different algorithms

This is the first major mental-model split.

## Startup-time propagation: later globals and segment offsets

When Binaryen is rewriting:

- later global initializers
- element-segment offsets
- data-segment offsets

it is still in module-instantiation order.

That means no runtime code has executed yet.
So if an earlier global currently has a known constant value, Binaryen can substitute that value into later init expressions even if the global is mutable at runtime.

Safe beginner phrasing:

- “mutable later” does not stop “known right now during startup.”

That is why this shape is positive:

```wat
(global $a (mut i32) (i32.const 42))
(global $b i32 (global.get $a))
```

At global-init time, `$a` is still definitely `42`, so `$b` can become `i32.const 42`.

## Runtime propagation: only when the current trace is still simple

Inside function code, Binaryen cannot make that same broad assumption.

The runtime phase starts from two narrower sources of truth:

- globally constant globals
- or globals given a known constant earlier in the **current linear trace**

So this shape is positive:

```wat
(global.set $g (i32.const 10))
(drop (global.get $g))
```

but only until a barrier appears.

## 2. Calls and nonlinear control are the major runtime barriers

`ConstantGlobalApplier` deliberately uses a cheap current-trace model, not a full CFG proof.

It forgets tracked current values when it sees:

- a call
- nonlinear control
- a write to a tracked global

That means this is a negative family:

```wat
(global.set $g (i32.const 10))
(call $maybe_changes_globals)
(drop (global.get $g))
```

Even if the call often does not write `$g`, Binaryen clears its current-value map there.

The `simplify-globals-dominance.wast` test makes this explicit: a dominated read before the call can optimize, the read after the call does not.

## 3. `connectAdjacentBlocks = true` is helpful, but not magic

The runtime walker enables adjacent-block connection.

That lets Binaryen handle some common “dominated right after this” shapes cheaply, like:

```wat
(global.set $g (i32.const 10))
(if (i32.const 0)
  (then
    (drop (global.get $g))
  )
)
```

Starshine's current subset also carries facts through top-level harmless noise, nested plain block bodies, and `if` then-bodies when no inner barrier appears; non-control noise such as `nop`, `drop`ped constants, or pure arithmetic does not clear facts:

```wat
(block
  (block
    (global.set $g (i32.const 10))
    (drop (i32.add (i32.const 1) (i32.const 2)))
  )
)
(drop (global.get $g))
```

But the pass still does **not** become a full dominator-tree analysis.

The shipped dominance test includes an explicit TODO for a dominated `else` case that Binaryen does not optimize yet.

So a future port should preserve the current narrow adjacency-based win rather than silently widening it into a different analysis contract. Starshine currently models this only for straight-line/top-level-noise, plain-block, and if-then-body runtime facts, now including imported/exported globals and reference-typed `ref.func` / `ref.null` facts when a same-trace constant write is visible, including `externref` / `ref.null extern` nested-block positives and mixed scalar/reference independent-write preservation; calls, branches, loops, `try_table`, returns, throws, non-constant writes to the same tracked global, post-if joins, and else-arm propagation remain conservative barriers or untracked boundaries. Guardrails also prove that facts established before a nested plain block are cleared when that block contains a call or branch, while a non-constant write clears only the written global and preserves independent scalar facts.

## 4. `read-only-to-write` is about fake state, not just matching names

A good beginner summary of the source rule is:

- a global qualifies only when Binaryen can prove the program reads it solely to decide whether to write that same global, and nothing else important depends on that read.

The 2026-05-18 current-main refresh found no drift from this contract at Binaryen `main` commit `d3029d2b975488acdf9253eb2994a3fc55bd3549`. The important implementation reminder is that Binaryen's condition matcher is broader than Starshine's current hard-coded surface: it accepts any safe condition expression where the actual `global.get` only contributes to the branch decision, subject to the effect and upward-flow checks below.

This is positive:

```wat
(if
  (global.get $once)
  (then
    (global.set $once (i32.const 1))
  )
)
```

This is **not** enough by itself:

- same global name appears in condition and body

The source also checks effects, actual AST nodes, and value flow.

## 5. The body must be “just write the global”

The `read-only-to-write` matcher requires the body code to have:

- exactly one written global effect
- no other remaining effects after clearing that one global write from the effect set

So these are negative families:

- the body also calls a function
- the body writes memory
- the body writes another global
- the body throws

But the body may still contain side-effect-free wrappers around the write, like a `block` with `nop` plus the `global.set`.

That is why this can still optimize:

```wat
(if
  (i32.eqz (global.get $once))
  (then
    (block
      (nop)
      (global.set $once (i32.const 1))
    )
  )
)
```

As of the 2026-05-18 Starshine slices, the local SGO matcher covers adjacent `i32.eqz`, bidirectional compare-const, a simple pure-condition self-guard family including `i32.clz` / `i32.ctz` / `i32.popcnt`, `i32.and` / `i32.or` / `i32.xor`, `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr`, `i64.eqz` / `i64` compare guards, non-trapping i64 value operators feeding those conditions, `f32` / `f64` compare guards, non-trapping `f32` / `f64` value operators feeding float compares, non-trapping numeric conversions / reinterprets / sign-extension / `trunc_sat` operators feeding final conditions, non-trapping reference predicates `ref.is_null` / `ref.eq` feeding final conditions, and non-trapping `local.get` sibling operands feeding pure final conditions, nested block-condition, block-wrapped pure-condition and block-yielded condition-read forms including `i32.eqz` / compare-const, no-op const/drop prefixes before block-wrapped condition reads, this transparent `nop` / void-`block` body family, no-op const/drop prefixes before the single constant write for self guards, and the same pure-condition subset in the exact direct and block-wrapped whole-body `if return; set` family. Starshine also has source-backed side-effecting-but-safe value-flow subsets for result-`if` arms, `select`/compare operands, block-prefix independent effects, nested same-pattern/body guards, and the latest block-prefix void-call guarded-write/if-return form. It still does not cover Binaryen's full generic safe-condition rule or the full iterative `read-only-to-write` family.

## 6. Actual AST `global.get` / `global.set` nodes matter more than effect summaries

This is one of the biggest source-level subtleties.

Binaryen does use computed function effects elsewhere in the pass, but for `read-only-to-write` it still insists on:

- an actual `GlobalGet` node in the condition
- an actual `GlobalSet` node in the body

So this is a negative family:

```wat
(if
  (block (result i32)
    (drop (call $getter))
    (i32.const 1)
  )
  (then
    (global.set $g (i32.const 0))
  )
)
```

Even if Binaryen already knows `$getter` reads `$g`, that is **not** the same as seeing an actual `global.get $g` in the condition here.

The same applies to body writes through calls.

That distinction is deliberate. The pass wants whole-program counting over concrete read/write sites before it erases the global state itself.

## 7. Value flow into side effects is the real danger

The pass does not reject every condition with side effects.

It rejects when the **global’s value** can determine side-effectful behavior dangerously.

Negative example:

```wat
(if
  (if (result i32)
    (global.get $g)
    (then (call $foo))
    (else (i32.const 1))
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Here `$g` decides whether `foo()` runs, so the read is observable for more than “should I write `$g`?”

Positive contrast:

```wat
(if
  (if (result i32)
    (call $foo)
    (then (i32.const 1))
    (else (global.get $g))
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Now the side effect exists, but `$g` does not choose whether `foo()` runs. Its value only flows safely out through the final condition result.

That is why the source needs an upward value-flow walk instead of just a flat “side effects yes/no” check. Starshine now has pure-condition positives including non-trapping numeric conversion/reinterpret/sign-extension/trunc_sat operators, non-trapping `ref.is_null` / `ref.eq` reference predicates, and `local.get` sibling operands in pure final conditions, block-prefix independent void calls in guarded-write and if-return tails, the source-backed result-`if` arm subset including pure operators in the selected arm, pure post-result operators before the value reaches the final condition, the function-level if-return/set variant, one nested result-if-arm value-flow subset, and the nested result-if-arm pure-suffix subset where an independent no-global prefix feeds the nested `if` and pure operators consume its result, the first official side-effecting `select` value-flow subset where independent load/local.tee operand effects are evaluated regardless of the global-derived select condition, the official `select` result flowing through `i32.eqz` before either a guarded write or Binaryen's function-level `if return; set` matcher, and source-backed `select` operand subsets where the global-derived operand and an independent zero-parameter/result call, `memory.size`, constant-delta `memory.grow`, `table.size`, constant-argument `table.grow`, or independent constant `local.tee` in either direct operand order only flow to the final same-global guard or Binaryen's function-level `if return; set` matcher, independent zero-parameter/result call, independent memory-op, and independent table-op compare operands in both guarded-write and if-return forms, plus source-backed block-condition subsets where an independent zero-parameter/result call, memory op, table op, local write, or global write happens before the final guarded global read for both guarded-write and if-return/set shapes. It also covers two source-backed nested-pattern carveouts: the nested-thrice same-global block-condition shape and the multi-global nested guarded-write body shape. The flow-into-`local.tee`, trapping-load-address, call-argument, flow-into-local-write, flow-into-table-op, extra-read-after-select, flow-into-`memory.grow` (including compare-operand delta), and flow-into-`table.grow` (including compare/select-operand delta) negatives remain guardrails; full Binaryen `FlowScanner` equivalence remains a future slice.

## 8. Nested appearances of the same pattern are allowed

The matcher contains an explicit carveout for another appearance of the same `read-only-to-write` pattern nested inside the current one.

That is why multi-layer examples like this can still optimize:

```wat
(if
  (block (result i32)
    (if
      (i32.eqz (global.get $once))
      (then
        (global.set $once (i32.const 1))
      )
    )
    (i32.eq (global.get $once) (i32.const 0))
  )
  (then
    (global.set $once (i32.const 1))
  )
)
```

Starshine now covers the official nested-thrice subset where a result block first runs a same-global read-only-to-write guard, then yields the same global read to an outer `i32.eqz` guard, then yields one more same-global read to the final guarded write. It also covers the official multi-global nested-body subset where a guarded-write body contains exactly one constant write to the guarded global plus nested different-global `global.get; if { ... }` read-only-to-write guard pairs. Both remain narrow source-backed carveouts, not a general arbitrary-effect block-condition or body-effect proof.

But if the nested form stops being those exact safe families, the optimization stops too.

The test suite has explicit near-miss negatives for:

- nested `if` with `else`
- extra unrelated `global.get`
- extra trailing code that breaks the exact whole-function shape

## 9. The whole-function `if return; set` family is intentionally narrow

Binaryen also recognizes this exact shape:

```wat
(block
  (if
    (global.get $once)
    (then
      (return)
    )
  )
  (global.set $once (i32.const 1))
)
```

Beginner takeaway:

- this is not a general CFG proof that “the set is guarded by an early return”
- it is an exact narrow body pattern

The function body must be exactly two elements long in the direct form. Binaryen also accepts the same guard when the condition is `global.get; i32.eqz`, `global.get; const; i32.eq/i32.ne`, `const; global.get; i32.eq/i32.ne`, a source-backed pure-condition chain from the guarded `global.get` to the return-guard `if`, a transparent result block yielding those condition forms, one more nested transparent result block, or a result block yielding `global.get` with `i32.eqz` / compare-const applied outside the block. The final same-global constant write may also be wrapped in a transparent void block, including with no-op constant/drop prefixes and including when the condition is block-wrapped or block-yielded. Add a trailing `nop`, and Binaryen preserves the original shape.

As of the 2026-05-18 follow-up slices, Starshine covers the exact, `i32.eqz`, bidirectional compare-const, pure-condition, and block-wrapped-condition/block-wrapped-pure-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-wrapped-set/block-wrapped-condition+set `if return; set` family and keeps focused trailing-`nop` negatives so it does not widen into a broader CFG proof by accident.

## 10. The optimizing rerun is part of the real pass contract

The biggest scheduler lesson is this:

- the optimizing variant is not just “simplify-globals but nicer”
- it is simplify-globals plus a deliberately chosen nested cleanup replay

When a function changes because:

- a `global.get` became a constant, or
- a `global.set` became `drop(value)`

Binaryen builds a nested `PassRunner` from the parent runner and calls:

- `addDefaultFunctionOptimizationPasses()`
- `runOnFunction(curr)`

So the new cleanup opportunities are intentionally cashed in immediately.

## What the rerun can clean up

After simplify-globals changes a function, the touched function may contain fresh debris such as:

- `drop(i32.const ...)`
- dead branches after a condition became constant
- dead locals after values stopped flowing from globals
- simpler instruction trees after a copied constant or `ref.func` arrived

The nested replay is how Binaryen turns those local wins into the final intended function body.

Starshine currently has an artifact-informed approximation of this nested replay in [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt). Focused characterization in [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../../src/passes/simplify_globals_optimizing_test.mbt) proves the current guard behavior: cleanup now runs above the earlier `8` touched-function and `100` defined-function limits, while individually large touched functions (`> 192` locals or `> 1000` instructions) are filtered out and an all-large touched set still reports `large-touched-function`. The nested cleanup trace also reports `nested-cleanup-stats touched=... cleaned=... filtered-large=...`.

A 2026-05-19 runtime slice pruned the artifact SGO nested replay to the slots that still paid for themselves on the direct debug artifact: `optimize-instructions -> local-cse -> pick-load-signs -> merge-blocks -> remove-unused-names -> merge-blocks -> coalesce-locals -> reorder-locals -> redundant-set-elimination -> vacuum`. This intentionally omits several ordinary default-function slots (`dead-code-elimination`, `heap-store-optimization`, `heap2local`, `optimize-casts`, `code-pushing`, `simplify-locals`, `code-folding`, `precompute`, and `remove-unused-brs`) because direct artifact experiments showed they mostly added wrapper/raw-skip/candidate-scan cost without improving the current size frontier. The traced direct run `.tmp/sgo-nested-pruned-trace.txt` reduced `detail:sgo:nested-total` to `86.104ms` and total SGO pass time to `139.507ms`; direct compare `.tmp/sgo-direct-debug-artifact-nested-pruned` stayed valid, stayed first-red at `defined=48 abs=69` (accepted by user decision as local/default-init representation drift), kept Starshine smaller (`2,860,269` bytes vs Binaryen `2,861,435`), and brought pass-local time inside the 2x Binaryen floor (`153.143ms` vs `107.210ms`). Upstream Binaryen has no equivalent touched-function-size guard or pruned nested list in SGO; treat this as an artifact-tuned Starshine runtime compromise that remains open for exact scheduler parity if future evidence requires it.

## 11. This rerun is smaller than the after-inlining helper

This is the crucial difference from the newly documented late boundary passes nearby.

`dae-optimizing` and `inlining-optimizing` use a helper that prepends:

- `precompute-propagate`

before replaying the default function optimization pipeline.

`simplify-globals-optimizing` does **not** do that.

It reruns only:

- the ordinary default function optimization pipeline

That is why the repo’s old maintained no-DWARF note was right to separate this pass’s nested shape from the after-inlining helper family.

## 12. Why the saved `-O4z` debug log still matters

The saved log does not reveal the exact inner pass names here, but it does prove that top-level `simplify-globals-optimizing` expands into nested work before the next top-level `remove-unused-module-elements`.

Repo-local counting on the saved log finds:

- `3` nested pass batches

That is enough to keep the scheduler lesson durable:

- this pass belongs in the tracker as a boundary/module pass with nested reruns,
- not just as “the last constant-global cleanup before RUME.”

## 13. Good mental model for future Starshine work

If you need one durable porting mental model, use this:

- simplify-globals rewrites global state only when Binaryen still has a simple enough proof,
- startup and runtime propagation use different proof styles,
- `read-only-to-write` is a real whole-program safety matcher,
- and the optimizing variant expects ordinary function cleanup to run immediately afterward.

That is what the implementation really preserves.

## Sources

- [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)

## 2026-07-06 independent `local.set` compare note

Binaryen `version_130` accepts a block condition that writes a constant to a local and then compares the guarded global with that local when the compare result reaches only the same-global guarded write or function-level if-return tail. Starshine now mirrors that exact subset and still rejects the unsafe value-flow case where the guarded global is written into the local.

## 2026-07-06 independent `global.set` compare note

Binaryen `version_130` accepts compare conditions where the guarded global is compared with a result block that performs an independent constant `global.set` to a different global and yields a constant. Starshine now mirrors that exact direct/reverse compare subset for both guarded-write and function-level if-return tails, while still rejecting the unsafe case where the guarded value is consumed by the independent global write.

## 2026-07-06 memory-store compare operand addendum

The FlowScanner audit now includes one more source-backed side-effect sibling subset: an `i32.store` inside a result-block compare operand whose address/value are constants or `local.get`s. Binaryen `version_130` treats the store as independent when the guarded global only flows to the compare and same-global guarded write or function-level `if return; set` tail; the store remains observable and is preserved. Starshine now matches that narrow shape and keeps the guarded-value-to-store negative mutable. This does not close arbitrary memory-write value flow, non-`local.get` dynamic store operands, or generic parent/child `FlowScanner` equivalence.

## 2026-07-06 local-fed `global.set` compare addendum

The FlowScanner audit now widens the independent `global.set` compare subset from constant-only stored values to constants or `local.get`s. Binaryen `version_130` treats the `$other` write as independent when the guarded global only flows to the compare and same-global guarded write or function-level `if return; set` tail; the `$other` write remains observable and is preserved. Starshine now matches that narrow local-fed shape and keeps the guarded-value-to-`global.set` negative mutable.

## 2026-07-06 local-fed local-write compare addendum

The FlowScanner audit now widens the independent local-write compare subsets from constant-only values to constants or `local.get`s. Binaryen `version_130` treats these local writes as independent when the guarded global only flows to the compare and same-global guarded write or function-level `if return; set` tail; generated unused-local shells may be cleaned away. Starshine now matches the narrow direct `local.tee` and block-condition `local.set` shapes and keeps guarded-value-to-local-write negatives mutable.

## 2026-07-06 local-fed `table.grow` compare addendum

The FlowScanner audit now widens the independent `table.grow` compare subset from constant-only ref/delta operands to constants or `local.get`s. Binaryen `version_130` treats the table growth as independent when the guarded global only flows to the compare and same-global guarded write or function-level `if return; set` tail; the `table.grow` remains observable and is preserved as `table.grow; drop`. Starshine now matches that narrow local-fed shape and keeps guarded-value-to-`table.grow` delta negatives mutable.

## 2026-07-06 local-fed `memory.grow` compare/select addendum

The FlowScanner audit now widens the independent `memory.grow` compare and select subsets from constant-only deltas to constants or `local.get`s. Binaryen `version_130` treats the memory growth as independent when the guarded global only flows to the compare/select guard and same-global guarded write or function-level `if return; set` tail; the `memory.grow` remains observable and is preserved as `memory.grow; drop`. Starshine now matches that narrow local-fed shape and keeps guarded-value-to-`memory.grow` delta negatives mutable. Broad generic `FlowScanner` parent/child equivalence remains open.

## 2026-07-06 local-fed `table.grow` select addendum

The FlowScanner audit now widens the independent `table.grow` select subset from constant-only ref/delta operands to constants or `local.get`s. Binaryen `version_130` treats the table growth as independent when the guarded global only flows through the select to the same-global guarded write or function-level `if return; set` tail; the `table.grow` remains observable and is preserved as `table.grow; drop`. Starshine now matches that narrow local-fed shape and keeps guarded-value-to-`table.grow` delta flow mutable.

## 2026-07-07 independent call `i32.add` addendum

The FlowScanner audit now includes a broader parent/child subset beyond grow-specific operand follow-ups: an independent zero-parameter/result call may be the sibling operand to `global.get $guard` under a pure `i32.add`, with either operand order and with either a same-global guarded write or function-level `if return; set` tail. Binaryen `version_130` treats the call as independent because the guarded value does not determine whether or how it runs; the call remains observable as `call; drop`. Starshine now matches that narrow family and still rejects guarded-value-to-call-argument flow plus unprobed arbitrary side-effect parents.


## 2026-07-07 independent call nontrapping `i32` binary addendum

The independent-call parent/child subset is now broader than `i32.add`: local Binaryen `version_130` accepts independent zero-parameter/one-result calls as sibling operands under nontrapping pure `i32` binary operators (`add`, `sub`, `mul`, bitwise ops, shifts, rotates) in either operand order and for both same-global guarded-write and function-level `if return; set` tails. Starshine now matches that narrow family and preserves the independent call as `call; drop`. Trapping `i32.div_*` / `i32.rem_*` forms remain excluded because local Binaryen probes keep the guard mutable; guarded-value-to-call-argument flow, extra guarded reads, arbitrary side-effect parents, and generic `FlowScanner` equivalence remain open.

## 2026-07-07 independent call binary `i32.eqz` suffix addendum

The FlowScanner audit now includes one more source-backed parent/child subset: an independent zero-parameter/one-result call may be the sibling operand under a nontrapping pure `i32` binary parent, and that binary result may flow through `i32.eqz` before the same-global guarded write or function-level `if return; set` tail. Binaryen `version_130` treats the call as independent in direct/reverse and if-return probes; Starshine now matches that narrow shape and preserves the call as `call; drop`. Trapping `i32.div_s; i32.eqz` remains excluded, as do guarded-value-to-call-argument flow, arbitrary pure suffix chains, arbitrary side-effect parents, extra guarded reads, and generic `FlowScanner` equivalence.

The FlowScanner audit now extends the independent-call/nontrapping-`i32` binary parent subset through one additional source-backed pure suffix family: `i32.clz`, `i32.ctz`, or `i32.popcnt` may consume the binary result before the same-global guarded write or function-level `if return; set` tail. Binaryen `version_130` accepted the direct/reverse/if-return unary-suffix probes and preserved the independent call as `call; drop`; the paired `i32.div_s; i32.clz` probe kept the guard mutable. Starshine now matches this narrow unary-suffix shape, but const-fed comparisons, multiple/arbitrary pure suffix chains, non-`i32` call-result parent chains, arbitrary side-effect parents, guarded-value-to-call-argument flow, extra guarded reads, and trapping binary parents remain open.

## 2026-07-07 independent call binary constant-fed comparison addendum

The parent-chain audit now includes one constant-fed equality comparison after the independent-call/nontrapping-`i32` binary result. Binaryen `version_130` accepts `i32.eq` / `i32.ne` with one `i32.const` in either comparison operand order, including reverse call/binary operands and function-level `if return; set` tails; Starshine now matches that narrow family and preserves the call as `call; drop`. A trapping `i32.div_s` parent remains mutable. Relational comparisons, multiple suffixes, arbitrary side-effect parents, guarded-value-to-call-argument flow, extra reads, and generic `FlowScanner` equivalence remain open.

## 2026-07-07 independent `i64` call binary suffix addendum

Local Binaryen `version_130` also accepts the analogous `i64` parent chain: an independent zero-parameter/one-result `i64` call and guarded `i64` global feed a nontrapping `i64` binary parent, whose result reaches exactly one `i64.eqz` or constant-fed `i64.eq` / `i64.ne` before the same-global guard tail. Direct `i64.add; i64.eqz`, constant-first reverse `i64.mul; i64.eq`, and reverse if-return `i64.xor; i64.eqz` probes make the guard immutable and preserve `call; drop`; `i64.div_s; i64.eqz` keeps it mutable. Starshine now matches that narrow family.

## 2026-07-07 independent float call binary-comparison addendum

The typed parent-chain audit now also covers `f32` / `f64`. An independent zero-parameter/one-result float call may be the sibling of the guarded same-typed float global under one IEEE binary operator (`add`, `sub`, `mul`, `div`, `min`, `max`, or `copysign`), and that result may feed exactly one same-typed comparison with a float constant before the same-global guarded-write or function-level if-return tail. Direct/reverse binary operands and result-first/constant-first comparison orders are covered; `f32.div`, NaN-sensitive `f32.min`/`f32.eq`, and `f64.copysign` probes confirm that these nontrapping parents remain safe for the FlowScanner criterion. Starshine preserves the call as `call; drop`. Flow into a call argument, extra guarded reads, deeper pure chains, and arbitrary effectful parents remain rejected.

## 2026-07-07 generic scalar straight-line addendum

The independent-call subset now follows the source-level parent/child rule more directly for scalar straight-line expressions. Once the guarded value and an independent scalar call meet at a nontrapping parent, a typed parser follows repeated result-first nontrapping unary/conversion and constant-fed binary/comparison parents to the outer guard. This removes the former one-suffix limit and covers integer relational, float unary, and float-promotion chains. The parser still rejects trapping integer div/rem and trapping float-to-int truncation parents.

This does not yet generalize the flat instruction analysis to arbitrary independent effect siblings or structured parents. The remaining architecture step is an abstract stack that records guarded dependency separately from independent effects, coupled to cleanup that can replay every independent effect in order.

## 2026-07-07 multiple constant-first scalar parents addendum

Binaryen `version_130` also accepts constant-first parents at more than one depth around the dependent scalar expression. The direct probe `i32.const 9; i32.const 7; global.get $guard; call $imp; i32.add; i32.mul; i32.lt_s` and its reverse first-parent operand order both make `$guard` immutable and retain only `call; drop`. Starshine's typed suffix parser now consumes a contiguous LIFO stack of typed constant-first operands as well as result-first constants, and the cleanup parser uses the same ordering proof. Generic non-constant siblings, structured parents, and arbitrary independent-effect reconstruction remain open.

## 2026-07-07 reverse pre-parent scalar fragment addendum

When the independent call result is transformed before the guarded global reaches the first shared parent, cleanup now distinguishes removable operations from replay-required effects. Same-type unary operations and nontrapping conversions disappear with the fake guard shell, producing `call; drop`. Trapping float-to-int truncations are replayed before the final drop, producing `call; trunc; drop`. The guarded-dependent path still rejects trapping parents. This closes the probed reverse pre-parent cleanup family without claiming generic independent-effect or structured-parent FlowScanner equivalence.
