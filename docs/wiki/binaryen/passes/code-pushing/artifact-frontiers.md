---
kind: concept
status: working
last_reviewed: 2026-04-12
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md
  - ../../../raw/research/0079-2026-04-12-code-pushing-one-off-alias-tail-prefix.md
  - ../../../raw/research/0080-2026-04-12-code-pushing-crossed-condition-set-alias.md
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
- Comparing Binaryen no-pass-vs-pass output against Starshine no-pass-vs-pass
  output on the current tree now shows that stable old move on both sides, so
  `48978` should no longer be treated as the first live debug-artifact target.

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

## Frontier 4: The Current Safety Fence, `Func 1948` And `Func 1977`

Status:

- No longer a live writeback-validation blocker.
- Still the main in-tree safety fence for the explicit-exit-carrier-fed subset
  of the old invalid one-off tail family.

Observed failure:

- Native `--code-pushing` output on the debug artifact still validates.
- The current kept tree now reaches that state earlier in the pass:
  repeated alias-if ladders are admitted again, and plain one-off alias tails
  without an earlier explicit-exit carrier are admitted again too, but the
  explicit-exit-carrier-fed one-off tail family stays fenced before lowering.
- Traced serial replay on the current tree changes:
  - `Func 148`
  - `Func 1948`
- `Func 1977` is no longer a `skip-invalid-lower` case at all.
  It now stays unchanged earlier in `code-pushing` unless a future replay proves
  the remaining explicit-exit-carrier-fed subset can lower safely too.

What the reductions proved:

- Plain root-result sibling-`if` shifts validate in isolation.
- Earlier zero-result branch prefixes validate in isolation.
- Smaller parent-escape extractions validate in isolation.
- Real-carrier scaffolds can still validate in isolation after several narrower
  reorder steps.
- One more subtle point is now reduced in-tree too: a lowered terminal-owner
  parent-escape carrier can still be writeback-valid even when the lowered Wasm
  matches the coarse suspicious escape-carrier heuristic. That is why the kept
  `code-pushing` fallback now rechecks suspicious lowers against full-module
  writeback validation instead of treating the heuristic itself as final truth.
- One narrower explicit-exit blind spot is now gone too: a mixed
  `LocalSet(Block(...))` carrier with an outer owner exit, a terminal path, and
  a hidden parent-escape branch inside the carried branch payload no longer
  counts as a safe prefix after the summary walk was taught to recurse into
  branch payload children.
- Another explicit-exit blind spot is gone too: a nested branch that exists only
  inside an earlier block body region now fences later non-void-region motion,
  because explicit-exit detection no longer treats control-region bodies as
  invisible just because they are not direct node children.
- The new live reducer split is now clearer too:
  repeated alias-if ladders are not inherently invalid.
  Plain one-off alias tails are not inherently invalid either.
  Crossed-gap carrier aliases with unrelated condition-set locals are not
  inherently invalid either.
  The pass can keep rewriting all three when no risky explicit-exit carrier or
  same-source crossed condition-set alias is involved, and the real remaining
  danger is the explicit-exit-carrier-fed terminal one-off alias-if tail.
- One more reduced live-carried family is now closed too:
  the old call-prefixed parent-exit corruption at the top of `Func 148` is no
  longer the first live blocker. `hot_lower` now rebases a sunk parent-exit
  branch when it moves under an `if` arm, and it keeps the original result-`if`
  plus trailing-`br` form when only one arm already has a nonfallthrough tail.
  The reduced pass regression for that family is green, and the debug-artifact
  compare no longer first fails on the old dropped-live-value shape.
- The historical invalid failure appeared when the outer rewrite path went far
  enough to turn a parent escape block into a result-producing block after
  carried payload extraction and inner carried-`if` demotion.

The current mechanism hypothesis is no longer vague:

- the payload is extracted upward through a parent escape block
- the inner carried `if (result ...)` is demoted to `if (Void)`
- a surrounding branch is then retargeted to a block that now expects a result
  payload
- that jump skips the payload site and leaves branch arity at `0` where the outer
  block now expects `1`

Current first live diff after that fix:

- Direct compare at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3313274`
  still first diverges inside printed `func $127`, but the first visible line is
  now `44254`, not the old top-of-function carrier corruption.
- The remaining visible drift is later local / tuple temp materialization:
  Binaryen gives `local $474` / `$475` `i32`, while Starshine still materializes
  those slots as `i64` and shifts the later tuple temp numbering around the same
  parse helper chain.
- HOT verification sees the same mechanism as `InvalidBranchArity(_, _, 0, 1)`
- the native module later reports the same class as `stack underflow`

What this means for next work:

- This family is now fenced only at the explicit-exit-carrier-fed one-off tail
  form, not across the repeated-ladder form that `Func 1948` needs or the plain
  one-off tails that lack that risky prefix.
- That is a correctness improvement, not a parity completion.
- The remaining semantic blocker is no longer a live invalid-output cliff.
  It is the reopened valid `44251` frontier plus the still-deliberate
  explicit-exit-carrier-fed `Func 1977` fence.

## Frontier 5: The Reopened Terminal-Owner Direct Frontier

Status:

- The old ownership diagnosis is now closed.
- The current kept fence treats this as a Starshine-only over-admission, not as
  remaining upstream `code-pushing` surface.

Observed failure:

- Direct compare now validates all the way through and shows the first
  normalized WAT delta at `44251` in printed `func $127`.
- The next cluster starts at `44284`, `44644`, `44881`, and `44894` in that
  same early function before the larger later clusters.
- That raw frontier is not stable under Binaryen's own no-pass boundary:
  `--binaryen-nop-until-stable 5` does not converge on this artifact, and a
  fixed `--binaryen-nop-roundtrips 5` replay moves the first hunks to
  `27790`, `27841`, `28246`, and later `45771` / `46157` instead.
- The latest kept replay at
  `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3345552` is still
  first red at `44251` / `44254` even after the large runtime win, which is one
  more reason not to reopen the historical `48978` family as the main target.

Observed shape:

- This is no longer the newer top-level alias move at `48978`.
- A direct Binaryen-side reread changes the interpretation materially:
  Binaryen `version_129` `CodePushing.cpp` still only moves flat block-list SFA
  `local.set` roots and one-arm `if` sinks. It does not model Starshine-style
  explicit-exit carrier summaries or alias-local synthesis.
- The direct artifact slice from
  [`0076`](../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md)
  shows more than that general strategy note: Binaryen `--code-pushing` leaves
  the printed `func $127` / `parse__config__json` function unchanged.
- So the earlier `44251` / `44254` family was not "Binaryen rewrites this and
  Starshine is still missing part of the transform." It was "Starshine rewrites
  a function that Binaryen leaves alone, and the resulting diff is then blurred
  by Binaryen's own writeback-local materialization noise."

What this means for next work:

- Do not widen `code-pushing` toward this family again unless Binaryen starts
  changing the same function on a refreshed artifact replay.
- Keep the HOT-only manual reorder proof as a lowering fact, but keep the pass
  fence in place on the crossed-condition-set terminal-owner family.
- The next reducer should now ask a later question: after `Func 148` stops
  changing, what semantic delta still survives beyond the Binaryen boundary
  noise?
- Runtime work should measure those few changed functions together with this
  reopened semantic frontier, because the safe tree still changes only
  `Func 148` plus `Func 1948`, and `Func 1948` remains the clear hot member
  after the old unchanged `Func 3665` scan was removed.

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
