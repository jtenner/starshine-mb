---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/ir/hot_lower_live_repro_test.mbt
related:
  - ./index.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ./validation-and-fuzzing.md
---

# `code-pushing` Artifact Frontiers

## Why This Page Exists

- The numbered research doc already contains a long chronological reduction log.
- That is useful provenance, but it is not the fastest way to answer "what is the
  real blocker right now?" or "what did each hunk family teach us?"
- This page is the durable frontier ledger for the pass.

## How To Read The Labels

- Hunk labels such as `48978`, `71748`, `105621`, and `126757` are normalized WAT
  diff starting lines from saved direct-compare outputs.
- Printed names such as `func $127` or `func $238` come from the normalized WAT
  side of the compare.
- Validator labels such as `Func 1977` come from native Wasm validation of the
  Starshine output.
- None of those numbers are eternal truth. They are useful frontier nicknames.
  As earlier families disappear, later hunk numbers shift.

## Frontier 1: The Old `func $127` Dropped-Carrier Family

Status:

- Closed as the first live blocker.

What it looked like:

- The relevant root wanted to end up after a later `if`, but HOT lift had stranded
  the real producer inside a dropped result carrier.
- Simple same-region motion was already working on smaller sibling cases, which
  proved the remaining blocker was not just an ordinary `local.set`-past-`if`
  move.

What the reducers taught:

- Plain tee-fed or alias-set sibling motion was already green in-tree.
- The real missing surface was extraction from a dropped carrier, not a broader
  same-region barrier rule.
- Binaryen's final shape could be matched in Starshine by:
  - extracting an alias `local.set(local.get ...)`
  - or keeping a call in place via `local.tee temp (call ...)` and then emitting
    a later alias set

What landed:

- alias extraction
- narrow single-result `i32` call-fed extraction
- safe explicit-exit prefix handling for that extraction
- one nested wrapper variant

Result:

- The old `48978` / `func $127` family is no longer the primary frontier.

## Frontier 2: The Old `func $238` Terminal-Owner Family

Status:

- Narrower than it used to be, but not fully closed.

What it looked like:

- An earlier explicit-exit `LocalSet(Block(...), LocalGet)` carrier sat before a
  later `if`.
- Smaller local-only reducers around the later `if` already passed, proving the
  blocker was still inside the earlier carrier logic.

What the reducers taught:

- The exact terminal-inner-owner carrier is safe.
- The closer call-prefixed terminal-inner-owner slice is also safe.
- That means the broader `func $238` family is not just "call prefix before final
  payload `br`." It needs more surrounding structure than that smaller reducer.

Current interpretation:

- Once the invalid `Func 1977` family is gone, this is still the next expected
  semantic frontier in the earlier artifact chronology.
- In current notes it is usually described by `71748` or the older `72005`
  label, depending on which compare checkpoint is being referenced.

## Frontier 3: The Later Alias-Local-Synthesis Families

Status:

- Still open, but currently secondary to the invalid-output blocker.

What they looked like:

- Later direct compares around `105621` and `126757` showed Binaryen creating
  additional alias locals before a shared `if`, increasing local count and then
  forwarding those aliases afterwards.

Why they matter:

- Those shapes no longer look like a pure guard-widening problem.
- They look more like local synthesis or a neighboring cleanup phase than another
  trivial extension of the existing root-motion rules.

Current interpretation:

- If those really are the intended parity frontier, exact matching there may
  require either:
  - bounded local synthesis inside `code-pushing`
  - or accepting that a neighboring pass owns part of the final shape

## Frontier 4: The Current Hard Blocker, `Func 1977`

Status:

- Current top blocker.

Observed failure:

- Native `--code-pushing` output on the debug artifact currently fails final
  validation with `stack underflow` in `Func 1977`.

What the reductions proved:

- Plain root-result sibling-`if` shifts validate in isolation.
- Earlier zero-result branch prefixes validate in isolation.
- Smaller parent-escape extractions validate in isolation.
- Real-carrier scaffolds can still validate in isolation after several narrower
  reorder steps.
- The failure appears only when the outer rewrite path goes far enough to turn a
  parent escape block into a result-producing block after carried payload
  extraction and inner carried-`if` demotion.

The current mechanism hypothesis is no longer vague:

- the payload is extracted upward through a parent escape block
- the inner carried `if (result ...)` is demoted to `if (Void)`
- a surrounding branch is then retargeted to a block that now expects a result
  payload
- that jump skips the payload site and leaves branch arity at `0` where the outer
  block now expects `1`
- HOT verification sees the same mechanism as `InvalidBranchArity(_, _, 0, 1)`
- the native module later reports the same class as `stack underflow`

What this means for next work:

- The next reducer must preserve the outer result-block rewrite, not just the
  inner carrier reorder.
- Widening more local-only extraction or terminal-owner rules before fixing this
  family is likely to waste time.

## What Has Been Explicitly Ruled Out

- "The remaining bug is plain same-region sibling motion."
  This is false. Smaller sibling-only reducers already pass.
- "The remaining bug is just an earlier zero-result branch prefix."
  This is false. That family validates in several reduced forms.
- "The remaining bug is just dropped-carrier extraction."
  This is false. Several extraction families are now landed and fuzz-clean.
- "The remaining bug is any parent-exit carrier rewrite."
  This is false. Smaller parent-exit fixtures can still lower and validate.
- "The remaining bug is the exact call-prefixed terminal-inner-owner carrier."
  This is false. That slice now passes in-tree.

## Practical Rule For Frontier Work

- When a new artifact hunk appears, do not start by widening the pass globally.
- First decide which of these buckets it belongs to:
  - ordinary segment motion
  - one-arm `if` sinking
  - explicit-exit-prefix handling
  - dropped-carrier extraction
  - parent-result / branch-arity safety
  - alias-local synthesis
- If the answer is "parent-result / branch-arity safety," insist on a HOT verify
  or HOT lower repro before accepting any new rule.
