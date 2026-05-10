---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/binaryen/2026-04-21-simplify-locals-primary-sources.md
  - ../../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md
  - ../../../raw/research/0241-2026-04-21-simplify-locals-primary-sources-and-structure-followup.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./raw-lane-and-writeback.md
---

# `simplify-locals` structure-result lifting and carrier cleanup

## Why this page exists

The main `simplify-locals` dossier already had:

- a broad upstream strategy page
- a broad Starshine strategy page
- a WAT-shape catalog
- a code-oriented implementation map

What it still lacked was one compact bridge page for the most teachable family in the pass:

- locals that are not just dead temps
- they are *carriers* for structured values that really belong on a block, `if`, or loop result path instead

This page is that bridge.
It answers one question for beginner through advanced readers:

- when does `simplify-locals` stop treating a local as storage and start treating it as an exposed control-flow result?

## The shared mental model

For both Binaryen and Starshine, the structure-result family starts from the same observation:

- some `local.set` / `local.get` pairs are not arbitrary temporaries
- they are shuttling the value that the surrounding control node could produce directly

That leads to four high-value shape families:

1. named-block exits that all write the same local
2. `if` / `else` arms that compute the same later local value
3. one-armed `if` rewrites that speculatively expose the carried value
4. narrow loop-tail lifting when the loop can become a result-producing control node

Starshine then adds one practical local maintenance family around the same area:

5. wrapper-forwarder and debug-artifact carrier cleanup that makes the lifted rewrites survive local exact-path realities

## Upstream Binaryen source locations that matter most

The official `version_129` source file is still the anchor:

- `src/passes/SimplifyLocals.cpp`

The most useful reviewed locations from the 2026-04-21 source capture are:

- `visitBlock(...)` calling `optimizeBlockReturn(...)`
- `doNoteIfTrue(...)` calling `optimizeIfReturn(...)` for one-armed `if`
- `doNoteIfFalse(...)` calling `optimizeIfElseReturn(...)` for `if` / `else`
- `visitLoop(...)` calling `optimizeLoopReturn(...)`
- the explicit comment above `optimizeIfReturn(...)` calling the one-armed rewrite *speculative*
- `runLateOptimizations(...)` explaining why equivalent-copy cleanup runs after structure work instead of before it

Those source locations are captured in the raw primary-source manifest:

- [`../../../raw/binaryen/2026-04-21-simplify-locals-primary-sources.md`](../../../raw/binaryen/2026-04-21-simplify-locals-primary-sources.md)

## Shape family 1: named block exits become block results

### Core upstream idea

Binaryen records block exits in `blockBreaks` and later lets `optimizeBlockReturn(...)` ask a narrow question:

- do all relevant exits for this named block ultimately shuttle the same local?

If yes, the pass can replace the hidden local-carrier protocol with an explicit block result.

### Canonical before/after sketch

Before:

```wat
(block $out
  ...
  (local.set $x a)
  (br $out)
  ...
  (local.set $x b)
)
(local.get $x)
```

After shape:

```wat
(local.set $x
  (block $out (result T)
    ...
    a-or-b-through-exits
  )
)
```

### Important Binaryen guards

- unsupported target users such as `BrOn*` and `Switch` still poison the block for this optimization
- more-than-one nonlinear path to here clears the cheap linear sink state afterward
- the block must still be a good candidate after exit collection, not merely after surface pattern matching

### Starshine code locations

The local lifted cluster is:

- `simplify_locals_collect_block_return_candidates`
- `simplify_locals_collect_block_branch_exits`
- `simplify_locals_try_apply_block_return_candidate`
- `simplify_locals_try_rewrite_block_return`

All live in:

- [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)

### Local regression anchors

Reduced semantic cases:

- `"simplify-locals lifts matching block exits into a block result"`
- `"simplify-locals lifts block returns past live intervening local sets"`

Debug-artifact and encoded-output lanes nearby:

- `"raw simplify-locals effectful suffix rewrites debug artifact Func 71 block-result carrier"`
- `"simplify-locals full pipeline keeps debug artifact Func 71 block-result carrier tee"`

## Shape family 2: `if` / `else` arms become an `if` result

### Core upstream idea

Binaryen's `doNoteIfFalse(...)` hands both arm states to `optimizeIfElseReturn(...)`.
The question is:

- do the two arms really compute one later value of the same local?

If yes, that value should be an explicit `if (result ...)` instead of an implicit local shuttle.

### Canonical before/after sketch

Before:

```wat
(if
  cond
  (then (local.set $x a))
  (else (local.set $x b))
)
(local.get $x)
```

After shape:

```wat
(local.set $x
  (if (result T)
    cond
    (then a)
    (else b)
  )
)
```

### Important Binaryen guards

- the `if` must still be a void carrier shape worth converting
- one side may also win when the other is unreachable, but that is still a controlled special case, not a blanket rule
- later equivalent-copy cleanup is intentionally delayed until after this structure phase

### Starshine code locations

The local lifted helpers are:

- `simplify_locals_try_rewrite_if_return`
- `simplify_locals_try_structure_rewrite_region`
- `simplify_locals_run_structure_rewrites`

### Local regression anchors

- `"simplify-locals lifts if-else local writes into an if result"`
- `"simplify-locals keeps later reads alive when lifting if results"`
- `"simplify-locals lifts reachable if-else arms even when the other arm is unreachable"`

## Shape family 3: one-armed `if` lifting is real, but speculative and defaultability-gated

### Core upstream idea

Binaryen's `doNoteIfTrue(...)` calls `optimizeIfReturn(...)` for one-armed `if`.
The source explicitly labels this family speculative.
That wording matters.

The pass is willing to rewrite:

- a one-armed `if` that writes a local
- the common case followed by a later read of that local
- the Binaryen-shaped speculative case where the write is dead but the arm still has structured side effects that should not be deleted before lifting

into a value-producing `if` that also synthesizes an else-side carrier.

### Canonical before/after sketch

Before:

```wat
(if
  cond
  (then (local.set $x value))
)
(local.get $x)
```

After shape:

```wat
(local.set $x
  (if (result T)
    cond
    (then value)
    (else (local.get $x))
  )
)
```

### The crucial guard

This is only safe for **defaultable** locals.

That is the most important beginner correction in this family.
If the local is nondefaultable, the synthesized else-side get would rely on fixup machinery that can introduce a real trap, so Binaryen skips the rewrite.

### Starshine code locations

The matching local helpers are:

- `simplify_locals_try_rewrite_nested_one_armed_if_child`
- `simplify_locals_try_rewrite_nested_one_armed_if_children`
- `simplify_locals_build_one_armed_if_then_body`
- `simplify_locals_one_armed_if_tail_sets`
- `simplify_locals_local_type_is_defaultable`

### Local regression anchors

- `"simplify-locals lifts one-armed if writes for defaultable locals"`
- `"simplify-locals lifts dead one-armed if writes instead of dropping structured side effects"`
- `"simplify-locals preserves then-arm nop when lifting one-armed if writes"`
- `"simplify-locals keeps live then-arm roots when lifting one-armed if writes"`
- `"simplify-locals lifts nested one-armed if writes inside consumed result ifs"`
- `"simplify-locals skips one-armed if lifting for non-defaultable locals"`

## Shape family 4: loop result lifting is narrow, not general loop value optimization

### Core upstream idea

`visitLoop(...)` calls `optimizeLoopReturn(...)`, but only on a deliberately narrow family.

The key question is not “can this loop somehow produce a value?”
It is more like:

- is there a trailing loop-local carrier that can be moved to a loop result without violating the pass's narrow shape and cycle assumptions?

### Canonical before/after sketch

Before:

```wat
(loop
  ...
  (local.set $x value)
)
(local.get $x)
```

After shape:

```wat
(local.set $x
  (loop (result T)
    ...
    value
  )
)
```

### Important Binaryen guards

- the loop must currently be void
- the body may need to become or remain a block with a trailing `nop` slot
- multi-use or nontrivial tee pressure can still block the rewrite on early cycles

### Starshine code locations

The local lifted entry is:

- `simplify_locals_try_rewrite_loop_return`

with control-support helpers nearby:

- `simplify_locals_node_is_nonfallthrough_exit`
- `simplify_locals_control_has_typed_branch_payload`
- `simplify_locals_branch_payload_count`

### Local regression anchors

- `"simplify-locals lifts loop tail writes across the loop fallthrough"`

## Shape family 5: Starshine also owns practical carrier cleanup around wrapper forms

Binaryen teaches the structure-result family in AST terms.
Starshine has to keep that family alive across its HOT-IR plus raw-lane split.
That creates one extra local teaching surface worth keeping explicit.

### The local extra family

Some real artifact carriers are not just simple block/if/loop textbook shapes.
They also involve wrapper-forwarder cleanup, exact-path retention issues, and raw skipped-function stack-carrier cleanup.

That is why Starshine has dedicated helpers including:

- `simplify_locals_try_rewrite_split_local_set_wrapper_forwarder`
- `run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_fixpoint`

and dedicated raw-lane tests in `pass_manager_wbtest.mbt` for the nearby debug-artifact families. The raw control-carrier helper is deliberately narrow: it handles a typed-control value immediately followed by a `local.set`, optional `nop`s, and a same-local leading read in the next expression, producing either an inline carrier or a `local.tee` when later reads still need the local.

### Why this is not a contradiction

This does **not** mean Starshine has a different core pass.
It means the repo has an extra maintenance burden:

- preserve the same transformed-value meaning
- while surviving HOT lift, exact lowering, raw-skip heuristics, and encoded-output roundtrips

### Local regression anchors

- `"simplify-locals rewrites split-wrapper debug artifact Func 50"`
- `"simplify-locals full pipeline rewrites debug artifact Func 71 returning condition copy carrier"`
- `"simplify-locals full pipeline rewrites debug artifact Func 71 split value wrappers"`
- `"simplify-locals full pipeline hoists debug artifact Func 71 nop-separated call args"`

## What runs before and after these rewrites matters

### Before

The structure family depends on the same earlier machinery as the simpler sink-and-tee wins:

- get counting
- pending sinkable tracking
- effect ordering
- branch-target awareness

### After

The structure family is intentionally followed by late equivalent-copy cleanup and then dead cleanup.
That ordering is part of the real contract.
It prevents the pass from deleting a copy too early and accidentally hiding a structure-return opportunity.

On the local side, that same story explains why the folder still needs both:

- the lifted structure helpers in `simplify_locals.mbt`
- the raw-lane and exact-cleanup notes in [`./raw-lane-and-writeback.md`](./raw-lane-and-writeback.md)

## Maintenance rule

If a future `simplify-locals` bug report mentions any of these phrases:

- block-result carrier
- if-result carrier
- one-armed `if`
- loop tail write
- wrapper forwarder
- copied local after structure lift

start with this page, then jump to:

- [`./wat-shapes.md`](./wat-shapes.md) for the source-backed before/after family
- [`./implementation-map.md`](./implementation-map.md) for the owning MoonBit helper cluster
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) for the HOT/raw/writeback split

That path is now the shortest route from shape-level confusion to exact local ownership.
