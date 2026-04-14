---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/perf_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./effect-ordering-and-barriers.md
  - ./raw-lane-and-writeback.md
  - ./parity.md
---

# `simplify-locals` WAT Shapes

## Scope

- This page records the exact WAT-shaped families the repo wants `simplify-locals` to transform, preserve, or explicitly decline.
- It is not a transcript of every historical reducer.
- The rule for this page is:
  - keep exact pattern families that explain why the pass exists
  - keep the negative cases that explain why the pass must stay conservative
  - keep the raw-lane-recognized no-op families when they are durable enough to matter to maintenance

## Reading Rule

- Each family below has four parts:
  - the input shape
  - the intended output shape
  - why the transform is correct
  - the repo-specific caveat that prevents over-generalization

## 1. Single-Use Linear Sink

### Input

```wat
(local.set $tmp
  (i32.const 7)
)
...
(local.get $tmp)
```

### Intended Output

```wat
...
(i32.const 7)
```

### Why

- The local exists only to shuttle one value into one later use.
- If no intervening code reads or writes `$tmp` or invalidates the producer, the local is not semantically meaningful.

### Caveat

- This is the basic family, but the repo does not treat every later `local.get` as consumable.
- The sink still depends on:
  - use count
  - effect ordering
  - local conflicts
  - control barriers
  - whether the consuming position evaluates in the same order Binaryen expects

## 2. Multi-Use Sink Through `local.tee`

### Input

```wat
(local.set $tmp
  (call $produce)
)
...
(local.get $tmp)
...
(local.get $tmp)
```

### Intended Output

```wat
...
(local.tee $tmp
  (call $produce)
)
...
(local.get $tmp)
```

### Why

- The first read can consume the producer directly.
- Later reads still need a local carrier.
- `local.tee` is the correct "consume now, keep later" shape.

### Caveat

- The repo keeps a hard guard against synthesizing `local.tee` for multivalue producers.
- That negative case is explicitly covered because Binaryen-like tee synthesis on multivalue locals led to bad lowered debris in Starshine.

## 3. Overwritten Pending Set Becomes `drop`

### Input

```wat
(local.set $tmp
  (call $side)
)
(local.set $tmp
  (i32.const 0)
)
```

### Intended Output

```wat
(drop
  (call $side)
)
(local.set $tmp
  (i32.const 0)
)
```

### Why

- The first write never becomes observable through `$tmp`.
- Its side effects still matter.
- Rewriting it to `drop(value)` preserves side effects without pretending the local write still matters.

### Caveat

- Pure dead writes may collapse further to `nop`.
- Effectful ones must keep evaluation.

## 4. `drop(local.tee(...))` Collapses Back To `local.set(...)`

### Input

```wat
(drop
  (local.tee $tmp
    value
  )
)
```

### Intended Output

```wat
(local.set $tmp
  value
)
```

### Why

- The tee exists only because an earlier rewrite created a consume-now/keep-later form.
- If the consuming side is immediately dropped, the tee has become gratuitous.

### Caveat

- This is a cleanup family, not a reason to synthesize tees more broadly.

## 5. Pure Later Call-Argument Inline

### Input

```wat
(i32.const 9)
(local.set $tmp)
(call $lhs
  ...
)
(local.get $tmp)
(call $rhs)
```

### Intended Output

```wat
(call $lhs
  ...
)
(i32.const 9)
(call $rhs)
```

### Why

- The producer is pure.
- An earlier sibling argument being a call does not matter if the later argument is still evaluated after it and the pure value can be moved to that position safely.

### Caveat

- This family is intentionally narrower than "any local can move into any later call argument."
- The negative sibling-ordering family below is the reason.

## 6. Sibling-Argument Ordering Must Block Effectful Moves

### Input

```wat
(local.set $flag
  (if (result i32)
    ...
  )
)
(call $f
  (local.get $x)
  (local.get $flag)
)
```

### Rejected Output

```wat
(call $f
  (local.get $x)
  (local.tee $flag
    (if (result i32)
      ...
    )
  )
)
```

### Why It Is Rejected

- The `if` may write a local or otherwise affect an earlier sibling argument's meaning.
- In the reduced `moonbit.malloc` family, this reorder was real wrong code, not merely a shape disagreement.

### Maintenance Rule

- If the replacement is effectful, Starshine only inlines it when the consuming `local.get` lies on the next root's *leading* evaluation path.

## 7. Sink Across Unrelated Local Traffic

### Input

```wat
(local.set $a
  (call $side)
)
(local.get $b)
(drop)
(local.get $a)
```

### Intended Output

```wat
(local.get $b)
(drop)
(call $side)
```

### Why

- Unrelated local traffic should not automatically kill a pending value.
- The repo had to learn this explicitly because clearing sinkables on all local-only traffic was too conservative.

### Caveat

- The unrelated local must really be unrelated.
- Any read or write of the producer local or a producer-source local still blocks the move.

## 8. Trap-Commuting Read-Only Tee

### Input

```wat
(local.set $tmp
  (i32.load ...)
)
...
(i32.load ...)
...
(local.get $tmp)
```

### Intended Output

```wat
...
(local.tee $tmp
  (i32.load ...)
)
```

### Why

- A read-only trapping producer can commute past later read-only traps in the narrow case where the pass's effect ordering says neither side changes the other's meaning.

### Caveat

- This is one of the easiest families to overgeneralize.
- The repo keeps the corresponding memory-write barrier as a separate negative case because a later write must still kill the move.

## 9. Do Not Sink Trapping Reads Across Memory Writes

### Input

```wat
(local.set $tmp
  (i32.load ...)
)
(i32.store ...)
(local.get $tmp)
```

### Required Outcome

- Keep the local traffic.
- Do not sink the load through the store.

### Why

- The store changes observable memory state.
- The earlier load and later store cannot be freely reordered.

## 10. Loop-Carried Initializer Must Stay Outside The Loop

### Input

```wat
(i32.const 0)
(local.set $i)
(loop
  ...
  (local.get $i)
  ...
  (local.set $i
    (i32.add
      (local.get $i)
      (i32.const 1)
    )
  )
  ...
)
```

### Rejected Output

```wat
(loop
  ...
  (local.tee $i
    (i32.const 0)
  )
  ...
)
```

### Why It Is Rejected

- The producer was a pre-loop initializer, not a per-iteration value.
- Moving it into the loop header rewrites one-time setup into repeated reinitialization.
- The reduced `StringView.make_init_no_rc` artifact bug proved this is a real correctness boundary.

## 11. Block Return Lifting

### Input

```wat
(block
  ...
  (local.set $tmp value)
  ...
  (br $label
    (local.get $tmp)
  )
)
(local.get $tmp)
```

### Intended Output

```wat
(block (result i32)
  ...
  value
)
```

### Why

- The local is only serving as a synthetic block result carrier.
- Binaryen prefers the control node to return the value directly.

### Caveat

- The repo explicitly tracks:
  - branch exit ownership
  - typed-branch payload hazards
  - whether later live roots touch the local

## 12. One-Armed `if` Lift For Defaultable Locals

### Input

```wat
(if
  cond
  (then
    ...
    (local.set $tmp value)
  )
)
(local.get $tmp)
```

### Intended Output

```wat
(if (result i32)
  cond
  (then
    ...
    nop
    value
  )
  (else
    (local.get $tmp)
  )
)
```

### Why

- The then-arm is really producing the value of the surrounding expression.
- Binaryen preserves a `nop` sentinel where the old tail set lived in several reduced families.

### Caveats

- The local type must be defaultable.
- Live prefix roots in the then-arm must stay in place.
- The repo explicitly rejects a broad "erase everything but the value" version of this rewrite.

## 13. Nested One-Armed `if` Inside A Consumed Result

### Input

```wat
(if (result i32)
  cond0
  (then
    ...
    (if
      cond1
      (then
        (local.set $tmp value)
      )
    )
    (local.get $tmp)
  )
  (else ...)
)
```

### Intended Output

- Lift the inner one-armed `if` too, not only root-level `if`s.

### Why

- Binaryen does not limit the idea to top-level control roots when the consumed-result structure still makes the dataflow obvious.

## 14. Loop Fallthrough Tail Lifting

### Input

```wat
(loop
  ...
  (local.set $tmp value)
)
(local.get $tmp)
```

### Intended Output

```wat
(loop (result i32)
  ...
  value
)
```

### Why

- The loop fallthrough is being used as a synthetic return path through a local.

### Caveat

- Only the fallthrough value is lifted.
- Backedge behavior and carried locals still need to stay valid.

## 15. Tee-Backed Copied Local Must Survive Later Branch Or Call Use

### Input

```wat
(local.set $copy
  (local.get $src)
)
...
(if
  ...
  (then
    ...
    (call $use
      (local.get $copy)
    )
  )
)
```

### Intended Output

- Keep the tee-backed copied local alive when the later direct call or branch use still needs that carrier.

### Why

- Binaryen sometimes wants the copied local, not the source local, to remain the representative at the later direct-use site.

## 16. Same-Arm Alias Should Collapse Back To Source Local

### Input

```wat
(local.set $copy
  (local.get $src)
)
...
(i32.load
  (local.get $copy)
)
```

### Intended Output

```wat
(i32.load
  (local.get $src)
)
```

### Why

- Same-arm non-call aliases do not need the copied local once the equivalence is known.

### Caveat

- This is exactly the family that forced the repo to narrow tee-defined-local protection to direct call children instead of every later use.

## 17. Exact Writeback: Dead Copied `local.tee`

### Input

```wat
(local.tee $tmp
  (local.get $src)
)
(drop)
```

### Intended Output

- Remove the dead copied tee when no surviving exact `local.get` still reads `$tmp`.

### Why

- Lower can leave copied tees that are no longer semantically needed.
- Binaryen parity tolerated this cleanup when kept narrow.

### Caveat

- This is *not* permission to strip surrounding lowered `nop`s.

## 18. Exact Writeback: Dead Adjacent `local.set` / `local.get`

### Input

```wat
(local.set $tmp value)
(local.get $tmp)
```

### Intended Output

```wat
value
```

### Why

- After lower, some one-use temps survive only as an adjacent set/get shuttle.
- The repo now removes those without introducing new tees.

### Caveat

- The local must have no later exact reads.
- Multivalue-lowered families are explicitly kept out of this cleanup.

## 19. Explicitly Rejected: Broad Lowered-`nop` Stripping

### Rejected Idea

- Strip lowered `nop` roots after exact writeback to make the output "cleaner."

### Why Rejected

- The `gen-valid` differential lane diverged almost immediately.
- Binaryen preserves many lowered `nop`s intentionally or at least stably enough that removing them changes parity.

### Rule

- Never revive broad lowered-`nop` cleanup without a reduced, oracle-backed proof for the exact family.

## 20. Raw-Lane Rewrite Family: Structured Pure Copy Tail

### Input Family

- Large exact instruction bodies where a single-use temp survives only because a pure prefix sits between producer and use.

### Intended Outcome

- Remove the temp directly on the raw lane without hot lift.

### Why

- The family is common in validator-heavy and builder-heavy artifact helpers.
- A narrow exact-instruction proof was cheaper than lifting the whole function.

## 21. Raw-Lane Rewrite Family: Validator Skip Copy And Loop Temps

### Input Families

- `local.get -> local.set -> nested statement group -> local.get`
- `call -> local.set -> local.get/local.set barrier -> local.get -> i32.lt_s`
- copied locals across one cleanup `if`
- `call -> local.set -> structured value body whose leading condition path starts with a pure prefix and then local.get`

### Intended Outcome

- Apply the narrow temp cleanup even when the function still takes `skip-raw reason=validator-structured-call-heavy`.

### Why

- Several artifact frontiers reduced only after the repo accepted that some parity-safe temp cleanup must run even on validator raw-skip results.
- The latest retired family is the old `Func 71` condition-temp drift, where Binaryen sinks a call-indirect temp into the structured condition even though the validator helper still stays on the raw-skip lane.
- The next unreduced `Func 71` family is narrower:
  - reduced validator regressions already cover the simple `local.set -> local.get -> if` tee shape with later if-body reads
  - the old `$928 -> $549` store shuttle is now retired too
  - the reduced validator-heavy returning call-tail constant-copy subgroup is now retired too: a nested returning `if` arm with `i32.const -> local.set` shuttles feeding a later `call` now collapses to direct constants even on `skip-raw reason=validator-structured-call-heavy`
  - a second reduced validator-heavy returning fanout subgroup is now retired in-memory too: an effectful prefix followed by a returning `if (result i32)` arm whose escaping `call` is fed by a dense const-copy web now collapses once the helper can see the full escaping tail
  - a newer reduced Binaryen probe now also covers the denser fanout shape itself: `i32.const/local.get -> local.set` repeated across several locals and then consumed by one final `call`
  - Binaryen's reduced output for that family is explicit: delete the whole fanout, keep only `nop` sentinels, and feed the final `call` with direct constants or direct source `local.get`
  - a later reduced follow-up now also covers the tighter terminal-value family inside that same artifact bucket: `i32.const/local.get -> local.set -> safe middle -> local.get`, where the copied local is the final escaping value instead of the input to another zero-stack statement
  - Binaryen's reduced output there is slightly more specific than the repo first assumed: keep the safe middle statements, turn the removed `local.set` into a `nop` sentinel, preserve any existing middle `nop`s, and end the tail with the original constant or source `local.get`
  - a later reduced branch-terminated follow-up now also covers `nop, local.get -> local.set, middle local.set, copied local.get -> local.set, br`; Binaryen keeps the leading `nop`, emits one extra sentinel `nop` for the removed copied-local set, preserves the middle set, rewrites the final set to read the original source local directly, and keeps the trailing `br`
  - Starshine now matches those reduced families in-tree and the direct traced native `Func 71` dump shows the direct constant/source form in `body_raw`
  - but the latest clean artifact replay still shows the real `$930/$931/$932/$933/$934` subgroup after the large validator-skip body is replayed, and the first remaining mismatch is now the exact `$62 -> $930 -> $38` branch carrier
  - so the current first open artifact drift is no longer "we need a fanout reducer"; it is "the real validator-skip statement shape in `Func 71` still keeps this one branch carrier alive"
  - a blind post-pass adjacent-tee sweep was tested against the real artifact and rejected because it removed the explicit carrier without matching Binaryen's shape

## 22. Raw No-Op Families

### Shapes

- huge straight-line call builders
- dense structured call-heavy helpers
- stringview trim loops
- decode-shaped helpers
- branchy decode fanout
- validator-heavy call walkers

### Intended Outcome

- Do not hot-lift them when tracing shows they are already Binaryen-equal no-ops.

### Why

- These families are mostly performance decisions, not core semantic transforms.
- They matter because artifact parity work was otherwise drowned by no-op hot-lift cost.

## Maintenance Rule

- Add a new shape here only if at least one of these is true:
  - the family has a focused regression in `src/passes/simplify_locals_test.mbt`
  - the family has a synthetic perf or wbtest guard
  - the family was a real artifact frontier or hotspot and the conclusion is durable
