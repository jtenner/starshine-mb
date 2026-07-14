---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h
  - ../../../src/ir/README.md
  - ../../../src/ir/hot_core.mbt
  - ../../../src/ir/hot_lift.mbt
  - ../../../src/ir/hot_lower.mbt
  - ../ir2/architecture-rules.md
related:
  - release-horizon-and-oracles.md
  - passes/flatten/index.md
  - passes/remove-unused-names/control-names-implicit-blocks-and-delegates.md
  - passes/reorder-globals/index.md
  - ../ir2/architecture-rules.md
---

# Binaryen IR And Starshine Representation Boundaries

## Overview

A WebAssembly pass is not automatically portable merely because it has the same name in Binaryen and Starshine. The two projects optimize equivalent **WebAssembly semantics**, but their internal representations answer different questions.

Use this page when a source-level Binaryen algorithm seems to conflict with Starshine code shape, particularly around labels, identities, flattening, or temporary locals.

```text
Wasm bytes / WAT
  -> Starshine boundary @lib.Module / @lib.Expr
  -> validate
  -> lift one function to HotFunc
  -> analyze + mutate HotFunc
  -> verify + lower to boundary instructions
  -> validate + encode / print

Wasm bytes / WAT
  -> Binaryen parser
  -> Binaryen named expression IR
  -> Binaryen pass pipeline
  -> writer / validator
```

These flows are analogous, not representation-identical. The upstream Flat-IR contract and local IR ownership sources below establish this boundary.

## The four concepts not to conflate

| Concept | What it is | What it is **not** |
| --- | --- | --- |
| Wasm boundary form | Encoded bytes or parsed `@lib.Module` / `@lib.Expr` instructions, with binary index/depth operands and module validation. | Starshine's owned optimizer body. |
| Binaryen IR | Upstream's structured expression representation and its documented naming rules. Control labels are unique names, and branches target those names. | Raw Wasm instruction bytes or Starshine HOT storage. |
| Binaryen Flat IR | A deliberately stricter upstream shape from `src/ir/flat.h`, created for flatness-sensitive passes such as [`flatten`](passes/flatten/index.md). | A general name for Binaryen IR, or proof that a Starshine function is flat. |
| Starshine `HotFunc` | Starshine's single owned optimizer representation for one function body: dense nodes/children/roots plus locals, types, labels, exact payload side tables, tombstones, and a revision counter. | A persistent SSA graph, a raw parser AST, or an interchangeable copy of Binaryen IR. |

For the full Starshine ownership and cache contract, read [`../ir2/architecture-rules.md`](../ir2/architecture-rules.md). This page only explains the upstream/local boundary that matters when reading a Binaryen pass.

## A concrete branch-label example

In Wasm text, a branch targets a label that is eventually encoded as a **relative label depth**:

```wat
(block $answer (result i32)
  (br $answer (i32.const 7)))
```

Binaryen documents a different internal convenience: the control label is a unique name, and branches resolve that name. This is why Binaryen's [`remove-unused-names`](passes/remove-unused-names/control-names-implicit-blocks-and-delegates.md) can collect label uses by name and why deleting a dead label can make a block implicit later.

Starshine must preserve the Wasm result while changing representations:

1. the boundary instruction carries a depth-oriented branch target;
2. [`hot_lift.mbt`](../../../src/ir/hot_lift.mbt) resolves the structured context into a stable HOT `LabelId` and label metadata;
3. a HOT pass can reason about the stable label identity while editing the body;
4. [`hot_lower.mbt`](../../../src/ir/hot_lower.mbt) maps the live `LabelId` back to the correct relative `LabelIdx` for the active boundary label stack.

**Porting rule:** do not copy a Binaryen name-map algorithm into Starshine as if names were emitted Wasm operands. Preserve the source algorithm's *target-identity invariant*, then implement it through Starshine's label and lowering APIs.

## Identity and ordering are representation-dependent

The same caution applies to module declarations. Binaryen can reorder globals by symbolic `Name` and refresh module maps; the upstream [`reorder-globals`](passes/reorder-globals/index.md) dossier explains why its expression uses do not need individual patches. Starshine's boundary/module model has index-bearing operands, so a local reorder needs the appropriate local remap proof.

This does **not** make either representation safer by default. It means a faithful port asks a more precise question:

> Which source-level identity relation did Binaryen preserve, and which Starshine table, index, label, or payload must preserve the corresponding relation after lowering?

Apply the same test to functions, types, tables, globals, data segments, and element segments. A smaller local rewrite is only a parity win when it demonstrably preserves the required relation and has the required validation/oracle evidence.

## Flat IR is a pass precondition, not a universal optimization goal

Binaryen's Flat IR is useful for some later dataflow-oriented passes, but it is deliberately restrictive. Its [`flatten`](passes/flatten/flat-ir-contract-and-preludes.md) contract forces complicated nested values and value-carrying control into ordered prelude statements and temporary locals.

That has two consequences:

- seeing additional locals or explicit `local.get` / `local.set` traffic in Binaryen output may be required by a Flat IR phase, not evidence of an inefficient implementation;
- Starshine must not add an equivalent flattening phase merely to make its output resemble Binaryen. It needs a source-backed consumer, a representation design, and pass-specific correctness, validity, size, and timing evidence.

Conversely, an active Starshine HOT pass may use region edits or side tables without ever producing Binaryen Flat IR. That is normal unless its own contract says otherwise.

## Exact payloads and analysis overlays

`HotFunc` is intentionally broad enough to carry generic instruction families while retaining exact boundary payloads in side tables. This lets lift/lower preserve an opcode that a particular pass does not understand deeply. It does **not** license a rewrite over that opcode.

A safe pass therefore separates three levels:

1. **Preservation:** lift and lower preserve an exact payload without changing it.
2. **Classification:** an effect/type/control helper proves only the facts needed for a candidate rewrite.
3. **Transformation:** a pass changes the node only after satisfying its own semantic, trap, control-flow, and feature-family preconditions.

Likewise, CFG, dominance, effects, liveness, and local SSA are derived, revision-keyed overlays. After a HOT mutation, an old overlay is stale even if its ids still look plausible. The local invariant is `lift -> verify -> analyze -> mutate -> verify -> lower -> validate`; see [`../ir2/architecture-rules.md`](../ir2/architecture-rules.md).

## Porting checklist

Before calling a Binaryen pass port “parity,” record all of the following in the pass dossier:

1. **Source representation:** Which Binaryen owner, helper, and fixture establish the upstream behavior?
2. **Identity translation:** Are upstream names, expression pointers, or symbolic references represented locally by indexes, `LabelId`s, `NodeId`s, or side tables?
3. **Control and values:** Does the transformation depend on branch payloads, result types, stack order, traps, exceptions, or unreachable polymorphism?
4. **IR restriction:** Does it require Binaryen Flat IR, a closed-world module, a whole-module type graph, or another precondition absent from ordinary HOT passes?
5. **Repair work:** Which local remaps, revision invalidations, type updates, label-depth lowering, or exact-payload repairs are required?
6. **Evidence:** Which focused tests, module validation, direct Binaryen comparison, generated-profile fuzzing, size checks, and pass-local timing results prove the claim?

A raw WAT diff can help discovery, but it cannot replace this checklist. The project policy requires validated semantic parity and a demonstrated Starshine benefit for intentional output-shape differences.

## Source and navigation map

- [Binaryen current Flat-IR contract](https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h)
- Binaryen release/oracle policy: [`release-horizon-and-oracles.md`](release-horizon-and-oracles.md)
- Flat-IR contract and ordered preludes: [`passes/flatten/flat-ir-contract-and-preludes.md`](passes/flatten/flat-ir-contract-and-preludes.md)
- Binaryen named control labels: [`passes/remove-unused-names/control-names-implicit-blocks-and-delegates.md`](passes/remove-unused-names/control-names-implicit-blocks-and-delegates.md)
- Binaryen symbolic global ordering: [`passes/reorder-globals/index.md`](passes/reorder-globals/index.md)
- Starshine IR2 ownership, mutation, and analysis lifecycle: [`../ir2/architecture-rules.md`](../ir2/architecture-rules.md)
- Local source of truth: [`../../../src/ir/README.md`](../../../src/ir/README.md), [`../../../src/ir/hot_core.mbt`](../../../src/ir/hot_core.mbt), [`../../../src/ir/hot_lift.mbt`](../../../src/ir/hot_lift.mbt), and [`../../../src/ir/hot_lower.mbt`](../../../src/ir/hot_lower.mbt).
