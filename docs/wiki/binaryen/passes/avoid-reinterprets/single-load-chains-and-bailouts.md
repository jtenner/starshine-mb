---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md
  - ../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Single-load chains, fallthrough, and bailout boundaries in `avoid-reinterprets`

## Why this page exists

The hard part of `avoid-reinterprets` is not the final rewrite syntax.
The hard part is proving when a reinterpreting value still comes from exactly one source load.
The 2026-04-24 Starshine follow-up in [`./starshine-strategy.md`](./starshine-strategy.md) keeps this proof obligation explicit because the current local HOT analyses are not yet documented as a drop-in equivalent of Binaryen's `LocalGraph` behavior.
The 2026-04-26 port-readiness page, [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md), turns that caution into an implementation rule: ship direct `reinterpret(load)` flips before attempting this local-chain proof.

That proof depends on three things working together:

- `LocalGraph`
- `Properties::getFallthrough(...)`
- and the pass's own full-width + reachability filter

## The core question the pass asks

When Binaryen sees:

```wat
(f32.reinterpret_i32 (local.get $x))
```

it is really asking:

> can I still prove that `$x` came from one full-width `i32.load`, and not from a merge, param, partial load, or blocked wrapper?

If the answer is yes, the pass can replace the reinterpreting user.
If not, it leaves the original shape alone.

## What counts as a “single-load chain”

A valid chain looks like this conceptually:

```wat
(local.set $x (i32.load ...))
(local.set $y (local.get $x))
(drop (f32.reinterpret_i32 (local.get $y)))
```

The pass starts from `local.get $y` and repeatedly does this:

1. ask `LocalGraph` for all reaching sets
2. require exactly one set
3. reject `nullptr`
4. look through fallthrough wrappers on the set value
5. if that value is another `local.get`, keep chasing
6. if that value is a `Load`, stop successfully
7. otherwise bail out

That is the entire proof.

## Why merges fail

A merge means `LocalGraph::getSets(...)` reports more than one reaching set.
Then Binaryen cannot say which exact load the reinterpret is viewing, so the optimization stops.

So this pass is deliberately **not** a merge-sensitive phi/value-numbering optimizer.

## Why params and entry values fail

`LocalGraph` may report `nullptr` for parameter or entry-like values.
The helper immediately rejects that case.

That means the pass never tries to replace:

- reinterpret of a parameter,
- reinterpret of a local that might still be the entry/default value,
- or reinterpret of any value whose load origin is not proven by a real set node.

## Why copy chains can still work

Copy chains remain okay precisely because the helper follows `local.get` to `local.get` as long as every step stays unique.

That is why the `copy` lit case succeeds.

## Why wrapper transparency is narrow

The helper does **not** inspect raw values directly.
It uses `Properties::getFallthrough(...)`.

That gives a narrow notion of transparency:

- wrappers with a formal fallthrough value are okay
- wrappers that do not fall through in that sense are barriers

This prevents the pass from making unsound assumptions about arbitrary wrapper syntax.

## The `nofallthrough` lesson

The dedicated `nofallthrough` lit case exists to prove a subtle but important boundary.

A sketch of the relevant shape is:

```wat
(drop
  (f32.reinterpret_i32
    (block $named (result i32)
      (nop)
      (local.get $x))))
```

The test comment explains the key point:

- in general, Binaryen cannot just remove or ignore code here
- and a named block prevents the pass from treating this as a simple fallthrough chain

So even though a human can visually spot the `local.get`, the pass intentionally refuses the optimization.

## Full-width filtering happens after provenance succeeds

Even if the local chain proof succeeds, the pass still rejects the load unless it is:

- reachable
- and full-width for its type

So these are still bailouts:

- `i32.load16_u`
- `i32.load8_u`
- unreachable loads

This explains why the provenance page and the shape page must both exist: provenance alone is not enough.

## Pointer-temp typing is part of the proof boundary

For successful indirect rewrites, the pass stores the pointer in a helper local.
That helper local is typed using the memory's `addressType`.

This is not optional polish.
The memory64 lit file proves it is part of the real contract.

So a future port must preserve:

- `i32` pointer temps for memory32
- `i64` pointer temps for memory64

## Multiple reinterpret users do not weaken the proof

If many reinterpret users resolve back to the same source load, Binaryen still treats that as one successful source-load proof.
The pass then shares the same reinterpreted helper local.

So the proof question is not:

- “does this load have one user?”

It is:

- “can this reinterpreting user still be traced to one source load?”

## What a future port must **not** overgeneralize

Do not silently widen this pass into any of these stronger claims:

- “all local copies of a load are safe”
- “all wrappers around a local.get are transparent”
- “merged values can still be optimized if they look similar”
- “partial loads can be retargeted with the same logic”

Those may be tempting future extensions,
but they are not the reviewed Binaryen `version_129` contract.
They are also not current Starshine behavior: Starshine still tracks the pass only as a removed registry name, as mapped in [`./starshine-strategy.md`](./starshine-strategy.md).

## Sources

- [`../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md)
- [`../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md`](../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`](../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md)
- [`../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md`](../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md`](../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast>
