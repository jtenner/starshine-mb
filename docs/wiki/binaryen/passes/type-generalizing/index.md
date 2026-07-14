---
kind: entity
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp
  - ../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md
  - ../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md
  - ../../../raw/research/0497-2026-05-06-type-generalizing-current-main-recheck.md
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./type-requirements-cfg-and-unsupported-families.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../type-refining/index.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
  - ../signature-refining/index.md
supersedes:
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
---

# `type-generalizing`

## Role

- Starshine currently preserves `type-generalizing` as a **boundary-only local registry name**.
- The upstream Binaryen name is `experimental-type-generalizing`.
- Binaryen registers that name with `registerTestPass(...)`, not as a normal public optimizer pass.
- The Binaryen registration description says the pass is **not yet sound**.
- Starshine has no `src/passes/type_generalizing.mbt` owner file, active dispatcher case, preset slot, or backlog slice today.

This folder is therefore a **source-correct strategy and future-port dossier**, not documentation for an implemented Starshine pass.

## 2026-04-27 correction

The 2026-04-24 folder wrongly reduced this pass to local-set/local-tee evidence and missed its CFG, `call_ref`, GC, nested-`dce`, and refinalization surfaces. The later correction restored those surfaces but introduced a second error: it claimed that the pass uses `ContentOracle`.

The 2026-07-11 `version_130` and current-main source recheck resolves both errors. `TypeGeneralizing.cpp` is a hidden experimental function pass with:

- nested `dce` before analysis;
- a function CFG and backward monotone dataflow over local and value-stack type requirements;
- direct typed-IR transfer rules for calls, globals, tables, refs, structs, and arrays;
- explicit `call_ref`, `struct.get`, `struct.set`, and many array/ref transfer rules;
- local declaration generalization plus `local.get` / `local.tee` result retagging;
- `ReFinalize` when local get/tee expression types changed;
- many explicit unsupported or TODO families, which explains the hidden not-yet-sound registration.

It does **not** include or use `ContentOracle`: the pass reads static signatures, declared global/table types, and declared heap-type supertype/field/element information directly. Treat Binaryen's current-main [`TypeGeneralizing.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp) as the current source anchor. The older captures remain audit history, but their `ContentOracle` claims are superseded.

## Beginner summary

A safe beginner model is:

1. Binaryen asks, for each function, “how general can each reference local be while all uses still type-check?”
2. It runs a backward CFG analysis from uses to definitions, tracking required local types and required stack value types.
3. Instructions such as calls, globals, tables, `select`, `drop`, `ref.*`, `struct.*`, and `array.*` add constraints.
4. The pass rewrites non-param local declarations to the most general safe reference type it found.
5. It retags affected `local.get` and `local.tee` expressions and refinalizes when needed.

It is not a stable public shrink pass and not a tiny peephole. It is an experimental type-requirement solver.

## Inputs and outputs

Input:

- one Binaryen function body at a time;
- Binaryen's CFG for that function;
- local declarations and expression result types;
- typed instruction semantics plus declared function, global, table, and heap-type information.

Output:

- same module and same function structure;
- potentially more-general non-param local declarations;
- retagged `local.get` and `local.tee` expression result types for changed locals;
- refinalized function types if local expression types changed.

The pass does **not** remove locals, rewrite function signatures, merge type declarations, or insert casts as its primary output.

## Correctness constraints and hazards

- Function params keep their original required types at entry.
- Non-reference locals and unsupported locals keep their original types.
- Function exits constrain return values to the declared result type.
- A local's declaration may only be generalized when every use can accept the generalized type.
- `call_ref` must preserve signature requirements, including supertypes and bottom-target behavior.
- `struct.*` and `array.*` constraints must respect field/element, descriptor, nullability, and side-effect requirements.
- Unsupported TODO families must not be silently treated as valid positives.
- Running DCE before analysis is part of the observed upstream strategy because unreachable blocks are not fully materialized/analyzed.
- Post-rewrite validation/refinalization is part of the contract, not optional cleanup.

## Validation guidance

For Binaryen research:

- read `TypeGeneralizing.cpp` first for the real algorithm;
- read `pass.cpp` for hidden/test registration and the not-yet-sound warning;
- read `type-generalizing.wast` for supported and unsupported shape expectations;
- recheck current `main` before making port decisions because this is explicitly experimental.

For Starshine today:

- ensure `type-generalizing` remains boundary-only in `src/passes/optimize.mbt`;
- ensure explicit pass requests still fail before dispatch;
- ensure presets do not include it;
- do not document a local implementation until an owner file and tests land.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Source-correct upstream strategy: nested DCE, CFG, backward type requirements from typed IR/declarations, local rewrite, and refinalization.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - Official source and lit-test map, including the superseded 2026-04-24 claims.
- [`./type-requirements-cfg-and-unsupported-families.md`](./type-requirements-cfg-and-unsupported-families.md) - Focused guide to the hard part: requirements, joins, call_ref/GC constraints, and not-yet-supported families.
- [`./wat-shapes.md`](./wat-shapes.md) - Beginner-to-advanced shape catalog with before/after sketches and caveats.
- [`./starshine-strategy.md`](./starshine-strategy.md) - Current local boundary-only strategy and exact Starshine code surfaces.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) - Future implementation-readiness bridge and validation ladder.

## Sources

- Binaryen current-main owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp>
- [`../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md`](../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md)
- [`../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md`](../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md)
- Superseded mechanics: the consumed 2026-04-24 source capture, [`../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md`](../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md), and [`../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md`](../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
