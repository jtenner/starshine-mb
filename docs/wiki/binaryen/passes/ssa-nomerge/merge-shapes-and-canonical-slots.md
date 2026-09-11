---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
  - ../coalesce-locals/index.md
---

# `ssa-nomerge`: merge shapes and canonical slots

This page explains the single easiest thing to misunderstand about Binaryen `ssa-nomerge`:

- **the no-merge decision is made per set, and merge participants stay on canonical slots.**

If you keep just that one mental model in your head, the pass becomes much easier to read.

## Quick glossary

- **canonical slot**: the original local index from the input function
- **fresh slot**: a new local index Binaryen allocates for one specific set
- **merge participant**: a set whose influenced gets include any get with more than one reaching set
- **entry value**: the implicit initial source seen as `nullptr` in LocalGraph
  - parameter value for params
  - zero-init value for vars

## The source-backed core rule

`SSAify.cpp` renames a set only if:

- the original index is not already SSA, and
- `hasMerges(set, graph)` is false in no-merge mode

`hasMerges(set, graph)` returns true if **any** get influenced by that set has more than one reaching set.

So the pass does **not** ask:

- “does this original local ever merge somewhere in the function?”

It asks:

- “does this particular write feed any merged read?”

That is a much more precise and much more useful rule.

## Why the rule is per set, not per local

Imagine one local `$x` used in several phases of a function:

```wat
(local.set $x (i32.const 1))
(call $use (local.get $x) (local.get $x))
(local.set $x (i32.const 2))
(call $use (local.get $x) (local.get $x))
;; later, control flow merges and reads $x again
```

The early sets can still be untangled because their influenced gets are only the nearby calls.
The later merge does not automatically poison those earlier single-source regions.

That is why `ssa-nomerge` can improve local traffic without needing to rewrite the entire local's lifetime as one all-or-nothing decision.

## The dedicated `nomerge` test is the best concrete example

The official `test/passes/ssa-nomerge_enable-simd.wast` file contains a function named `nomerge` that is basically the source-backed tutorial for this rule.

### What happens there

- first write to `$x` -> fresh slot
- second write to `$x` -> fresh slot
- third write to `$x` -> stays canonical because a later get merges it with another possible source
- one-arm `if` write to `$x` -> stays canonical because the get after the `if` can also see the earlier value
- later straight-line write after that merge region -> fresh slot again
- final two-arm `if` writes -> both stay canonical because the read after the `if` merges them

So one original local ends up split into:

- some fresh untangled regions
- some preserved merge regions
- then fresh untangled regions again

That is the real `ssa-nomerge` shape.

## Default and parameter values count as merge inputs too

A merge does not require two explicit `local.set`s.
The implicit entry/default value also counts.

### One-arm local merge with default local value

Before:

```wat
(local $x i32)
(if
  (i32.const 1)
  (then
    (local.set $x (i32.const 1))))
(drop (local.get $x))
```

After `ssa-nomerge`, conceptually:

- the get stays on canonical `$x`
- because it may see either:
  - the explicit set in the `then`, or
  - the entry zero value

So even though there is only one explicit set, this is still a merge case.

### One-arm param merge with the entry parameter value

Before:

```wat
(func (param $p i32)
  (if
    (i32.const 1)
    (then
      (local.set $p (i32.const 1))))
  (drop (local.get $p)))
```

After `ssa-nomerge`, conceptually:

- the get stays on canonical `$p`
- because it may see either:
  - the overwritten value, or
  - the original param value

That is why the pass does not treat params as a special “always rename on overwrite” case.
The same merge logic still applies.

## Both-arm writes are the obvious canonical merge case

Before:

```wat
(local $x i32)
(if
  (i32.const 1)
  (then (local.set $x (i32.const 4)))
  (else (local.set $x (i32.const 5))))
(drop (local.get $x))
```

After `ssa-nomerge`, conceptually:

- both sets stay on canonical `$x`
- the get also stays on canonical `$x`

This is the easiest merge family to recognize, but it is not the only one.

## Overwritten writes inside a merge arm can still get fresh locals

One of the subtler cases in the official golden test is this pattern inside an `else` arm:

```wat
(block
  (local.set $x (i32.const 7))
  (local.set $x (i32.const 8)))
```

The earlier set to `7` is overwritten before any relevant get reads it.
So that set itself does not feed a merged get and can still receive a fresh slot.

But the final set to `8` feeds the later post-`if` get that merges with the `then` arm's value.
So the final set stays canonical.

This is the cleanest proof that the rule is truly per set, not per arm and not per original local.

## Why `ssa-nomerge` is not “no branches”

A beginner may hear “ignoring merges” and infer:

- branches are off limits

That is too strong.

The real rule is:

- branches are fine if they do not create a multi-source get for the specific set being considered

So the pass can still rename writes inside structured control when those writes remain single-source for their uses.
It only refuses the points where control-flow joins would require merge locals.

## What full `--ssa` would do differently

The same source file contains the full `ssa` behavior for multi-source gets.
That path:

- allocates a fresh merge local
- inserts `local.tee` or entry prepends to write incoming values into it
- retargets the get to that new local

Conceptually, full `ssa` turns a merge like this:

```wat
(if
  ...
  (then (local.set $x ...))
  (else (local.set $x ...)))
(local.get $x)
```

into a shape more like:

```wat
(if
  ...
  (then
    (local.tee $merge ...)
    ...)
  (else
    (local.tee $merge ...)
    ...))
(local.get $merge)
```

`ssa-nomerge` deliberately refuses that rewrite and leaves the read on `$x`.

That is the practical meaning of “ignoring merges.”

## Why this choice helps later passes

`SSAify.cpp` itself points at the main payoff:

- the fresh locals added by `ssa-nomerge` can be easily removed by `coalesce-locals`

That tells us what Binaryen wants here:

- split obviously single-source traffic into cheaper-to-reason-about regions
- but do not yet pay for explicit phi-like copies and overlapping lifetimes

So `ssa-nomerge` is a staging pass.
It prepares better local structure for later cleanups.

## Practical rules a future port must preserve

A future parity port must keep these concrete rules honest:

- canonical slots are not failures; they are the deliberate representation for merge regions in no-merge mode
- entry param/default values count as real alternative sources when deciding whether a get merges
- overwritten writes that never feed a merged get can still get fresh slots even inside a broader merge arm
- the same original local can switch between fresh and canonical behavior multiple times through one function
- predecessor-copy or entry-prepend materialization belongs to full `ssa`, not `ssa-nomerge`

If a local implementation blurs those boundaries, it will drift away from the real Binaryen contract.


## Nested branch continuations and copy chains

The raw structured rewrite must use the liveness at a branch's actual target.
A possible write later in the enclosing text does not kill an earlier value on
a path that branches around that write. Backward structured liveness now joins
conditional and branch-table successors, tracks block exits, and solves loop
headers to a fixed point. The implicit function label has no local live-out.
Unsupported exception edges retain conservative inputs.

A Dew JSON bloom duplicate fixture exposed two inner writes feeding a read after
an outer join. LocalGraph correctly reported all three reaching writes; the raw
suffix scan nevertheless renamed two writes and left the merged read on the
old local. The reduced results were `0, 0, 9` instead of `42, 41, 9`. All three
paths now return the original values. The saved first failing nested SSA stage
and default-level inlining fixture pass in Node and Wago. The original optimize
level 4/shrink level 1 inlining case still fails later and remains in the ledger.

The improved liveness exposed another raw cleanup bug: collapsing `A -> B -> C`
used the original `B` destination after it had already been rewritten to `C`.
The final value could remain in `B`, including a loop counter update. Copy-chain
cleanup now reads the current rewritten instructions at each step. A reduced
integer regression returns 42 instead of 0, and the nested functional-while
fixture's four SSA stages pass again.

Seven focused native tests cover the merged values, LocalGraph sources,
conditional entry values, unreachable writes, branch-table successors, loop
liveness, and the copy-chain result. The final native build/test takes 49.317 s;
this exceeds Dewdrop's 30 s compiler-work budget. Scoped `moon info` passes in
2.749 s with no public API changes. The full replay of 1,000 original failed
Dew fixture/pass-order pairs passes 931 and fails 69 in 122.930 seconds, with no regression from
the 926 passing wave 11 cases. Remaining cases are open, not accepted drift.

Native assertion cleanup remains open: the old build passes 495/496 isolated
SSA tests. The liveness repair initially passes 445/496; 50 additional checks
expect the old fresh-local/branch-copy layouts, including helpers that abort
on a failed shape assertion. These require semantic and size comparison before
changing their expectations. The pre-existing stack-carried-tee local-count
check also remains open. These failures do not replace the dual-runtime replay.

Sources: `src/passes/ssa_nomerge_raw_liveness.mbt`, the raw rewrite and branch
copy cleanup in `src/passes/pass_manager.mbt`, and
`src/passes/ssa_nomerge_dew_nested_join_wbtest.mbt`. Local replay logs are under
Dewdrop `.tmp/starshine-pass-repairs/`: `full-replay-regression-wave13/`,
`ssa-nested-join-fixed/`, `ssa-nested-loop-regression-fixed/`, and
`ssa-wave11-native-isolated.json` / `ssa-wave12-native-isolated.json`.
