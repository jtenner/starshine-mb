# Binaryen `type-ssa` research

- Date: 2026-04-21
- Researcher: OpenAI Codex
- Scope: official Binaryen `version_129` `type-ssa` pass, why it deserves its own wiki dossier, how it is actually implemented, what shapes it rewrites, and how it relates to the existing `type-merging` dossier.

## Why this note exists

The pass tracker no longer has an obvious remaining `none` target.
So this note is an explicit tracker expansion.

I chose `type-ssa` because:

- it is **not** on this thread's exclusion list,
- it is a real upstream public pass name in Binaryen `version_129`,
- the local wiki already depends on it indirectly because the `type-merging` dossier explicitly contrasts itself with `type-ssa`,
- but the tracker and pass folder map did **not** yet give `type-ssa` its own canonical page.

`agent-todo.md` currently has **no dedicated `type-ssa` slice**.
That is expected: this is upstream-only research and not a current Starshine implementation task.

## Main conclusion

Binaryen `version_129` `type-ssa` is **not** a general SSA converter and not a whole-program type-inference engine.
It is a small GC-focused function pass that tracks **freshly created exact reference types** through local and global SSA-like flows, then retags later uses and signature-facing edges when the exact created type is a subtype of the currently visible type.

A better beginner summary is:

- remember when a value was definitely created as an exact non-null struct/array/ref type,
- thread that information through block / `if` / `try` values and through `local.set` / `global.set`,
- then sharpen later `local.get`, `global.get`, call arguments, and return values,
- and finally refinalize the function if anything changed.

## Why `type-ssa` matters next to `type-merging`

The existing `type-merging` dossier already says `type-ssa` can create distinctions that help earlier optimization, while `type-merging` later removes distinctions that are no longer worth preserving.
That relationship is real and source-backed.
So `type-ssa` deserved its own dossier instead of staying an unnamed contrast point.

## Official sources reviewed

### Core implementation and registration

- `src/passes/TypeSSA.cpp`
- `src/passes/pass.cpp`

### Official tests

- `test/lit/passes/type-ssa.wast`

### Supporting helper surface

- `src/wasm-type.h` for exact/non-null reference typing vocabulary
- `src/ir/ReFinalize.cpp` because the pass explicitly refinalizes changed GC functions

### Current-main freshness spot check

I also spot-checked current `main` for:

- `src/passes/TypeSSA.cpp`
- `test/lit/passes/type-ssa.wast`

On the reviewed surfaces, current `main` still matched the tagged `version_129` behavior relevant to this dossier.

## Public-pass identity

`pass.cpp` registers `type-ssa` as its own public pass name.
The pass is therefore not just an internal helper for `type-merging`.
It is a real user-visible Binaryen pass.

It is also **upstream-only** for this repo right now:

- it is not part of the local no-DWARF default optimize path page,
- it is not part of the saved generated-artifact `-O4z` skipped-slot queue,
- and it is not currently named in the local Starshine pass registry.

That makes this a justified upstream-only tracker expansion, similar in spirit to the earlier `ssa` dossier.

## What the implementation actually does

## 1. It tracks “created exact types”

The core pass state is a map from expressions to more precise types, named `createdTypes` in the upstream source.

The helper `getTargetType(...)` only accepts a narrow reference-type surface:

- the type must be a reference,
- it must not be `anyref`, `eqref`, `i31ref`, or `none`,
- if it is not already exact, Binaryen turns it into an **exact, non-null** version of the same heap type.

That is the first major teaching point.
This pass is not trying to infer arbitrary better types from arbitrary dataflow.
It starts from values that were **just created** with a specific heap type.

## 2. It seeds created types from a tiny constructor-like surface

The pass records created exact types for:

- `struct.new`
- `array.new`
- `array.new_fixed`
- `ref.as_non_null`
- `ref.cast`

This is the main source of precision.
Those instructions are where Binaryen can say, “this value is definitely this exact heap type right now.”

## 3. It propagates those facts through expression values

The helper `getValue(Expression*)` tries to determine the value expression produced by a parent node.
The reviewed `version_129` source handles:

- plain expressions by default,
- `block` via the last child,
- `if` only when both arms carry the **same** created type,
- `try` via its `do` body or catch bodies when they agree,
- but not `loop`.

This means the pass is conservative about control-flow joins.
If it cannot prove a common created type, it keeps the broader original type.

## 4. It propagates through locals and globals

When a `local.set` or `global.set` stores a value with a remembered created type, the pass records the same created type for the write site.
Later:

- `local.get` can be retagged to that more precise heap type,
- `global.get` can be retagged similarly.

The pass preserves the original get's nullability when it retags the use.
So the main improvement is usually heap-type precision and exactness, not blindly forcing non-null everywhere.

## 5. It sharpens signature-facing edges

The pass also rewrites values flowing into typed boundaries.
In the reviewed `version_129` source it visits:

- direct `call` operands,
- `return` values.

For each argument or returned value, if the remembered created type is a subtype of the expected parameter or result type, Binaryen rewrites the expression type to the narrower created type.

So `type-ssa` does not just improve local gets.
It also pushes exact created types outward to places where later optimization and later type passes can use them.

## 6. It refinalizes changed GC functions

At the end of each changed function, if GC is enabled, the pass runs `ReFinalize`.
That is part of the correctness contract.
Retagging children can require parent expressions to be recomputed.

## What the pass is not

## Not general SSA construction

Despite the name, this is not the same kind of pass as full `ssa` / `ssa-nomerge`.
It does not create merge locals, prepend entry sets, or rename all locals into SSA form.

## Not `type-refining`

It does not scan whole-program field writes or compute LUBs over structural traffic.
Its precision comes from exact created values and SSA-like forwarding, not from whole closed-world field analysis.

## Not `type-generalizing`

It does not consume a `ContentOracle` and it does not reason about possible-content sets.
It is much smaller and more local than the existing `type-generalizing` dossier claims for its own family.

## Not `type-merging`

It does not merge heap-type declarations.
It increases the precision of uses.
`type-merging` later removes distinctions when they are no longer profitable or observable.

## Important positive rewrite families

## Fresh allocation -> local.set -> local.get

Canonical shape:

```wat
(local.set $x
  (struct.new $A ...))
(drop
  (local.get $x))
```

`type-ssa` can retag the `local.get` as an exact `$A`-typed reference.

## Matching `if` branch values

If both arms produce values with the same created type, the enclosing `if` value can carry that same precision.
That then enables later `local.set`, `call`, or `return` rewrites.

## Matching `try` results

The same idea works for `try` results when the `do` and catch flows agree on the created type.

## Return-value sharpening

If a function returns a broad supertype but the actual returned value is a freshly created exact subtype, `type-ssa` can retag the returned expression to that subtype before refinalization.

## Important preserved / bailout families

## Loop values

The reviewed helper intentionally returns `nullptr` for `loop` values.
So loops are outside the main created-value propagation surface.

## Mixed-arm `if` or `try`

If branches do not agree on the same created type, the pass preserves the broader type.

## Non-created values

If a value was not seeded by one of the small constructor/cast-like visitors or propagated from one of those seeded values, the pass does nothing.

## Broad abstract refs

`anyref`, `eqref`, `i31ref`, and `none` are deliberately excluded from the “created exact type” helper.
That keeps the pass focused on concrete heap-type precision.

## Best teaching sentence

The most accurate short teaching sentence I found is:

> `type-ssa` is a small GC pass that preserves exact created heap types across SSA-like local/global flows and then retags later uses, call operands, and returns when that precision is still subtype-safe.

## Implications for future Starshine work

If Starshine ever wants parity or neighboring documentation here, the key things to preserve are:

1. public upstream identity as `type-ssa`,
2. tiny created-type seed surface,
3. conservative `block` / `if` / `try` value joining,
4. local/global forwarding,
5. call-argument and return-value retagging,
6. loop exclusion,
7. GC-only refinalization after changes.

## Planned wiki fileback

Create a new upstream-only dossier under:

- `docs/wiki/binaryen/passes/type-ssa/`

with:

- `index.md`
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `created-exact-types-control-values-and-signature-rewrites.md`
- `wat-shapes.md`

and update:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source URLs

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeSSA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-ssa.wast>
