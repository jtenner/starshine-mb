---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0219-2026-04-21-souperify-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../flatten/index.md
  - ../dataflow-optimization/index.md
---

# Flat DataFlow traces, path conditions, and single-use boundaries

## Why this page exists

The easiest part of `souperify` to misread is not the printer.
It is the extraction boundary:

- where the pass starts,
- what graph it really builds,
- why it stops growing a trace,
- and what exactly changes in `souperify-single-use`.

That boundary is the real contract a future port or neighboring doc must preserve.

## Step 1: flatness is mandatory

Before any DataFlow work, the pass calls `Flat::verifyFlatness(func)`.
That means a candidate function must already satisfy the flat-IR rules.

Beginner version:

- nested computations have already been spilled to locals,
- control flow is already value-less,
- and tees are already gone.

So if a reader sees `souperify` after `flatten`, that is not just a convention.
It is a correctness precondition.

## Step 2: Binaryen builds DataFlow nodes, not Souper nodes directly from AST shape

The DataFlow graph is the pass's real working IR.
The key node kinds are:

- `Expr` for supported computations,
- `Phi` for merged local values,
- `Block` and `Cond` for branch-source metadata,
- `Zext` for restoring wasm-width integers after Souper-style `i1` comparisons,
- `Var` when extraction must stop cleanly,
- `Bad` when a value is unsupported.

That is why the pass can print `phi`, `block`, `blockpc`, and `pc` even though those are not native Binaryen AST nodes.

## Step 3: `UseFinder` decides where value slices really flow

`UseFinder` is the main bridge from local traffic to extraction decisions.

It starts from the origin expression of a set value and asks:

- which gets does this set influence?
- do those gets feed another set?
- is that second set only a boring copy?
- or does some use escape into a return, drop, call argument, or other non-set parent?

The important subtlety is that copy-only chains are looked through.
That is why the pass can reason about a logical value even after flattening or locals cleanup inserted extra moves.

## Step 4: traces are bounded and may replace children with `Var`

`Trace::add(...)` grows the backwards dependency slice.
It stops expanding a child and replaces it with a fresh `Var` when any of these happens:

- depth hits the limit,
- total node count hits the limit,
- the child is in `excludeAsChildren`.

That is the key boundedness rule.
The pass does not fail when a slice is too large.
It summarizes the hard part as an unknown input instead.

## Step 5: path conditions are added after the main work slice

The trace first gathers the actual work nodes.
Only after that does it:

- compute external uses,
- queue or add extra conditions,
- and walk upward through control parents to add path conditions.

This order matters because path-condition computation is descriptive metadata, not the core work being inferred.

## `if` is the only real path-condition source today

The reviewed `addPathTo(...)` implementation only accepts `If` parents.
That produces:

- condition expressions added as ordinary trace nodes,
- `pc` lines for direct path conditions,
- `blockpc` lines for branch-indexed block conditions.

The file header explicitly leaves wider path-condition support as a TODO.
So beginners should not expect loop, switch-like, or generic branch pcs here.

## External uses are not the same thing as multi-use truncation

These are two different ideas.

### `hasExternalUses`

The plain pass can print a trace node and still annotate it with:

- `(hasExternalUses)`

That means the node participates in the inferred root, but it also escapes elsewhere outside the trace's internal work slice.

### `souperify-single-use`

The sibling is stricter.
It uses `UseFinder` earlier to decide that a reused node should not be expanded as a **child** at all.
That child is replaced by a fresh `Var`, so the final printed trace should not need `hasExternalUses` annotations.

So the sibling split is:

- plain `souperify`: embed reusable children and annotate escapes,
- `souperify-single-use`: cut reusable children off earlier and summarize them as unknown inputs.

## Why roots and children behave differently in single-use mode

This is the most important sibling detail.

Single-use mode does **not** mean the root itself must have one use.
A reused node can still be chosen as a root to infer.
The restriction is only about whether that node may appear as an expanded dependency inside a larger trace.

That keeps the pass useful:

- it can still ask Souper about a reused subexpression directly,
- while avoiding oversized or overly shared child trees inside larger traces.

## Loop boundaries are intentional, not an omission

The DataFlow graph explicitly avoids real loop phis.
It uses fresh `Var`s at loop entry and only restores a precise old value when no actual loop phi would be necessary.

So if a trace seems to “go blurry” around a loop-carried value, that is the intended `version_129` policy.
It prevents the pass from pretending a cross-iteration dependency is just another branch merge.

## Printed forms to expect

When extraction succeeds, the printed trace may contain:

- ordinary instruction nodes like `add` or `and`
- `block`
- `phi`
- `blockpc`
- `pc`
- `zext`
- `var`

That mix is normal.
It reflects the combination of:

- computation,
- merged local flow,
- branch metadata,
- and bounded unknown inputs.

## Best beginner rule of thumb

If you want to predict what `souperify` will print, ask these questions in order:

1. is the function already flat?
2. is the root a supported unary / binary / `select` computation?
3. do its inputs stay inside the depth and total limits?
4. do any child dependencies cross a single-use boundary?
5. do any branch merges require phis?
6. does the trace live under an `if` arm that can provide a path condition?
7. does a loop force part of the slice back to unknown `Var`s?

That mental checklist matches the real extraction boundary much better than just looking at the input WAT and guessing.
