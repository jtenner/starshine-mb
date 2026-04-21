# Binaryen `avoid-reinterprets` research

Date: 2026-04-21
Status: source-backed upstream-only removed-registry dossier

## Why this pass was selected

The original no-DWARF parity queue and the first tracker-expansion wave are already dossier-covered.
So this thread needed either:

- a clearly justified major-gap fallback inside an already-deep folder, or
- a new source-backed upstream-only pass expansion.

I chose `avoid-reinterprets` for four concrete reasons:

1. `src/passes/optimize.mbt` still names `avoid-reinterprets` in the local **removed** registry.
2. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still lists it in Batch 1 of removed-until-hot-implementation passes.
3. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` does **not** include it in the current canonical no-DWARF `-O` / `-Os` path, so it is a legitimate upstream-only expansion target rather than a missed parity-queue item.
4. `agent-todo.md` currently has **no dedicated `avoid-reinterprets` slice**.

That combination makes it a good explicit tracker expansion: it is locally tracked, officially implemented upstream, still undocumented in the living wiki, and easy to misread from the name alone.

## Main sources reviewed

### Local repo sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

### Official Binaryen sources

- `src/passes/AvoidReinterprets.cpp` on `version_129`
- `src/passes/pass.cpp` on `version_129`
- `src/ir/local-graph.h` on `version_129`
- `src/ir/properties.h` on `version_129`
- `test/lit/passes/avoid-reinterprets.wast` on `version_129`
- `test/lit/passes/avoid-reinterprets64.wast` on `version_129`
- `src/passes/AvoidReinterprets.cpp` on current `main`

## Executive summary

`avoid-reinterprets` is a **narrow load/reinterpret rewrite pass**.
It does not do generic type canonicalization, generic load CSE, or generic local simplification.

Its real contract in reviewed Binaryen `version_129` is:

- find full-width loads whose results later feed `reinterpret` users,
- prove the reinterpreting value still comes from exactly one load through a single-set local chain,
- duplicate the load in the reinterpreted type,
- store that duplicate result in a fresh helper local,
- and replace the reinterpreting user with either:
  - a flipped direct load, or
  - a `local.get` of the helper local.

That means the beginner-friendly one-sentence summary is:

> `avoid-reinterprets` trades `reinterpret` operations for extra same-address full-width loads, usually through a small helper-local block.

The source comment explains why this exists at all:

- it is usually **not** a general win,
- but it can help when reinterprets are especially costly,
- with `wasm2js` given as the motivating example.

## Scheduler and local-status facts

### Upstream

`src/passes/pass.cpp` registers the public pass name as:

- `avoid-reinterprets`

with the description:

- `replace reinterprets with bitwise ops`? **No.**
- reviewed source actually describes it more specifically in `AvoidReinterprets.cpp`: avoid reinterprets by using more loads.

The implementation file is the better contract oracle than the short registry description.

### Local repo

- `src/passes/optimize.mbt` still tracks `avoid-reinterprets` as **removed**.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still places it in the first removed-until-hot-implementation batch.
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` does not include it in the current canonical top-level optimize path.
- `agent-todo.md` has no dedicated slice for it.

So the durable tracker conclusion is:

- real public Binaryen pass: yes
- currently active Starshine pass: no
- current local registry status: removed
- current canonical no-DWARF path member: no
- good tracker-expansion dossier target: yes

## Upstream implementation structure

Almost the entire semantic contract lives in one compact file:

- `src/passes/AvoidReinterprets.cpp`

The pass class is:

- `AvoidReinterprets : WalkerPass<PostWalker<AvoidReinterprets>>`

It also declares:

- `bool isFunctionParallel() override { return true; }`

So this is a function-parallel AST pass, not a whole-module planner.

## The actual algorithm

The pass runs in **two logical stages plus one final rewrite walker**.
That structure is easy to miss if you only skim the file.

### Phase 1: collect loads whose values are reinterpreted

The first walk looks only at `Unary` nodes that are one of:

- `ReinterpretInt32`
- `ReinterpretInt64`
- `ReinterpretFloat32`
- `ReinterpretFloat64`

For each such node, it looks through `Properties::getFallthrough(...)` on the operand.
If the operand falls through to a `local.get`, the pass tries to resolve that get back to a unique originating load using `getSingleLoad(...)`.

If that succeeds, the pass marks that source load as:

- `reinterpreted = true`

inside the per-load `Info` table.

Important limitation:

- the analysis only marks loads found through a single-set local chain ending at a `local.get`.
- it is **not** general reaching-def analysis over arbitrary expressions.

### Phase 2: decide which marked loads are actually legal to duplicate

After the first walk, `optimize(...)` filters the candidate map.
A marked load is only retained if `canReplaceWithReinterpret(load)` succeeds.

That helper requires:

- `load->type != Type::unreachable`
- `load->bytes == load->type.getByteSize()`

So the pass only duplicates **full-width, reachable** loads.

Implications:

- partial integer loads are out
- sign-extending narrow loads are out
- any unreachable load is out
- the pass is fundamentally about “same bits, different full-width view”

For each surviving load, the pass allocates two fresh locals:

- a pointer temp with the memory's `addressType`
- a temp for the reinterpreted load result, with type `load->type.reinterpret()`

That address-type detail matters because the dedicated memory64 lit file proves the pointer temp must become `i64` there.

### Phase 3: final post-walk rewrite

The inner `FinalOptimizer` does the actual mutation.
It handles two different user shapes.

#### Shape A: direct reinterpret of a load

If the pass sees:

- `reinterpret(load(...))`

it can flip that load's result type directly, without helper locals, using `makeReinterpretedLoad(...)`.

This is the simplest family.

#### Shape B: reinterpret of a local.get that still resolves to one load

If the pass sees:

- `reinterpret(local.get X)`

and `getSingleLoad(...)` again proves that `X` still uniquely resolves back to one tracked load,
it replaces the reinterpret with:

- `local.get <reinterpretedLocal>`

The original tracked load is rewritten separately in `visitLoad(...)`.

#### Rewriting the original load site

For each tracked original load, `visitLoad(...)` wraps it in a block that does three things in order:

1. save the original pointer in `ptrLocal`
2. compute a duplicate load of the reinterpreted result type and save it in `reinterpretedLocal`
3. perform the original load using the saved pointer

That means the pass preserves both views:

- the original typed load result
- and the helper-local result of the alternate typed load

This is the key behavior a future port must preserve.
The pass does **not** retarget the original local's type.
It duplicates the load.

## What `getSingleLoad(...)` really proves

This helper is the heart of the safety story.
It is easy to summarize too vaguely, so here is the exact reviewed contract.

Starting from a `local.get`, it repeatedly asks `LocalGraph` for the reaching sets.
It only keeps going if:

- there is **exactly one** reaching set
- that set is not `nullptr`
- and the defining value falls through to either another `local.get` or a `Load`

If the fallthrough value is another `local.get`, the helper follows it.
If it reaches a `Load`, it returns that load.
If anything else happens, it bails out.

Bailout cases include:

- multiple reaching sets
- `nullptr` set, which covers parameter or entry/zero-init style origin
- non-load defining values
- a cycle of gets in unreachable code

This means the pass is deliberately conservative.
It only optimizes when the reinterpreting value still has a single-load origin through a simple copy chain.

## The role of `Properties::getFallthrough(...)`

This helper is also part of the real contract.
The pass does not just inspect the immediate child expression.
It looks through fallthrough wrappers.

That is why copy chains like:

- `local.set y (local.get x)`

can still trace back to the original load.

But the dedicated `nofallthrough` test proves the opposite boundary too:

- a named block with side content that does not qualify as fallthrough must block the optimization

So the pass is not “look through all wrappers.”
It is:

- “look through the wrappers Binaryen formally classifies as fallthrough.”

## Important positive rewrite shapes

### 1. Direct reinterpret of a direct full-width load

Example input idea:

```wat
(drop (f32.reinterpret_i32 (i32.load (i32.const 1024))))
```

Binaryen rewrites this to the same address load in the other result type:

```wat
(drop (f32.load (i32.const 1024)))
```

Likewise for the opposite direction and for 64-bit float/int pairs.

### 2. Load into a local, later reinterpreted through a get

Example input idea:

```wat
(local.set $x (i32.load (i32.const 1024)))
(drop (f32.reinterpret_i32 (local.get $x)))
```

Binaryen rewrites the load site into a small block that:

- stores the pointer once,
- stores a duplicated `f32.load` into a helper local,
- performs the original `i32.load`,
- and later replaces the reinterpreting user with `local.get helper`.

### 3. Copy chains are allowed if they stay unique

The lit `copy` function proves the pass still works through:

- `x = load`
- `y = x`
- `reinterpret(y)`

because `getSingleLoad(...)` follows `local.get` chains as long as each step has exactly one reaching set.

### 4. Multiple reinterpret users can share one helper local

The lit `both` function proves that if several reinterpret users trace back to the same tracked load,
Binaryen computes one duplicated alternate-type load at the source and reuses the helper local.

### 5. Original non-reinterpreted uses can coexist with reinterpret users

The lit `half` function proves the pass preserves mixed use:

- ordinary `local.get $x` continues to use the original load result
- reinterpreting users switch to the helper local

This is why the pass duplicates the load rather than retargeting the original local.

## Important negative and bailout shapes

### 1. Partial loads do not change

The lit `partial1` and `partial2` cases prove that these stay untouched:

- `i32.load16_u`
- `i32.load8_u`

when wrapped in a reinterpret.

Why:

- `bytes != type.getByteSize()`
- so `canReplaceWithReinterpret(...)` fails.

This is a major teaching boundary.
The pass is **not** a general “change any load to any other type with same bits” transform.

### 2. Unreachable loads do not change

The same helper rejects loads whose result type is `unreachable`.
The source comment explains why the pass is simply not interested in that case.

### 3. Parameters or entry values do not qualify

If `LocalGraph` reports a `nullptr` reaching set, `getSingleLoad(...)` bails.
The helper comment in `local-graph.h` explains that `nullptr` can stand for a parameter.
So reinterpreting a param-like value is not in scope.

### 4. Merged local origins do not qualify

If a `local.get` can be reached from more than one set, `getSingleLoad(...)` returns null.
So this pass does not attempt merge reasoning.

### 5. Non-fallthrough wrappers block the optimization

The `nofallthrough` lit function shows a named block with an extra `nop` and a named label must keep the original reinterpret form.

### 6. Cycles of gets in unreachable code are rejected

The helper explicitly tracks seen gets and bails out if it encounters a cycle.
The source comment labels that as an unreachable-code situation.

## A subtle but important sign rule

`makeReinterpretedLoad(...)` always creates the alternate load with:

- `signed = false`

The source comment explains why this is okay:

- if the original load were an integer, the alternate one is a float anyhow, so signedness is irrelevant
- if the original were a float, the pass does not know which integer signedness would be meaningful, so it does not try

This is another proof that the pass only makes sense for **full-width reinterpret pairs**.
For partial loads, signedness would matter semantically, and the pass avoids them entirely.

## Memory64 surface

The dedicated `avoid-reinterprets64.wast` file is not a separate semantic algorithm.
It proves one specific portability obligation:

- the pointer helper local must use the memory's `addressType`

In memory32 cases that is `i32`.
In memory64 cases that is `i64`.

The pass obtains that type from:

- `auto mem = getModule()->getMemory(load->memory);`
- `auto addressType = mem->addressType;`

That is a real part of the port contract, not a test-only presentation detail.

## Interaction with nearby passes

This pass sits outside the current default no-DWARF path, but its neighbors are still conceptually important.

### It is not `alignment-lowering`

`alignment-lowering` rewrites one misaligned access into several smaller aligned accesses.

`avoid-reinterprets` rewrites one load-plus-reinterpret pattern into:

- one alternate-type load, or
- one original load plus one alternate-type load with helper locals.

### It is not `optimize-added-constants`

No address arithmetic is reassociated here.
The pointer expression is preserved and, when needed, stored once in a temp.

### It is not `local-cse`

The pass may duplicate a load on purpose.
That is the opposite of common-subexpression elimination.

### It naturally benefits from later cleanup

After rewriting, later passes could potentially simplify:

- dead original locals
- dead helper locals
- trivial blocks

But `avoid-reinterprets` itself does not perform those cleanups.

## Current-main drift check

I compared:

- `version_129` `src/passes/AvoidReinterprets.cpp`
- current upstream `main` `src/passes/AvoidReinterprets.cpp`

They are identical in the review run for this dossier.

That means the implementation summary here still matches current upstream on the main pass file itself.

## What a future Starshine port must preserve

A faithful port should preserve all of these:

- scope limited to reinterpret users of full-width loads
- exact `reinterpret` opcode family recognition
- single-load proof through unique reaching-set local chains
- fallthrough-wrapper sensitivity via the equivalent of `Properties::getFallthrough(...)`
- explicit bailout on params, merges, non-load defs, cycles, partial loads, and unreachable loads
- helper-local duplication strategy for non-direct reinterpret users
- address-type-aware pointer temps for memory32 and memory64
- reuse of one helper local for multiple reinterpret users of the same source load
- preservation of mixed original and reinterpreting uses

## Easy-to-misunderstand facts

### Misunderstanding 1: “This eliminates reinterprets by changing local types.”

No.
Reviewed Binaryen usually keeps the original local/type flow and adds a duplicated alternate-type load plus helper local.

### Misunderstanding 2: “This is just load CSE or local propagation.”

No.
It depends on `LocalGraph`, but the goal is not reuse.
The goal is to replace reinterpret users with alternate-type loads.

### Misunderstanding 3: “It works for any load width.”

No.
Only full-width loads are eligible.

### Misunderstanding 4: “It just peeks through any wrapper.”

No.
It only follows wrapper shapes that Binaryen classifies as fallthrough.

## Open questions and uncertainty

I do not currently see major open semantic uncertainty in the core `version_129` implementation.
The reviewed implementation file and dedicated lit files line up cleanly.

The main caution is pedagogical, not factual:

- the pass name sounds broader than it is,
- and the registry placement could mislead people into imagining it is a default optimizer building block.

It is better taught as:

- a specialized wasm2js-motivated load/reinterpret rewrite pass
- that happens to use local SSA-like provenance checks
- and that deliberately duplicates loads when profitable for that target.

## Resulting wiki work

This research note is being filed back into living docs as a new dedicated folder:

- `docs/wiki/binaryen/passes/avoid-reinterprets/`

with:

- landing page
- Binaryen strategy page
- implementation/test map
- WAT shape catalog
- focused helper/bailout page

## Sources

### Local repo

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

### Official Binaryen

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AvoidReinterprets.cpp>
