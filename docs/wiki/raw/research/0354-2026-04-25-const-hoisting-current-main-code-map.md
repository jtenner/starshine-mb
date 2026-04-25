---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../binaryen/2026-04-25-const-hoisting-current-main-recheck.md
  - ../../binaryen/passes/const-hoisting/index.md
  - ../../binaryen/passes/const-hoisting/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/ir/hot_core.mbt
  - ../../../../src/ir/hot_builders.mbt
  - ../../../../src/ir/hot_mutate.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
  - ../../../../src/binary/encode.mbt
related:
  - ../../binaryen/passes/const-hoisting/binaryen-strategy.md
  - ../../binaryen/passes/const-hoisting/wat-shapes.md
---

# `const-hoisting` current-main and Starshine code-map follow-up

## Question

The `const-hoisting` folder already had overview, Binaryen strategy, implementation/test-map, WAT-shape, and Starshine status pages. The remaining useful wiki-health question was narrower:

- did current Binaryen `main` drift from the `version_129` contract enough to change the teaching pages?
- can the Starshine page point to more exact local code surfaces than only the removed registry and neighboring dossier links?

## Answer

No teaching-relevant Binaryen drift was found on the focused current-`main` check captured in [`../binaryen/2026-04-25-const-hoisting-current-main-recheck.md`](../binaryen/2026-04-25-const-hoisting-current-main-recheck.md).

The durable improvement is a sharper local port map:

- `src/passes/optimize.mbt:144-150` still tracks `const-hoisting` as removed.
- `src/passes/optimize.mbt:455-473` still rejects removed pass requests explicitly.
- `src/ir/hot_core.mbt:55-64` defines the HOT opcode family containing `HotOp::Const`.
- `src/ir/hot_core.mbt:215-222` defines scalar numeric `HotConstPayload` cases for `i32`, `i64`, `f32`, and `f64`, plus non-Binaryen-`const-hoisting` payloads such as `ref.null` and `string.const`.
- `src/ir/hot_lift.mbt:1271-1285` lifts scalar numeric constants into HOT `Const` nodes with side-table payloads.
- `src/ir/hot_builders.mbt:295-318` builds typed `local.get` / `local.set` nodes.
- `src/ir/hot_mutate.mbt:196-200` appends a fresh body local and bumps the HOT revision.
- `src/ir/hot_lower.mbt:916-924` lowers HOT `Const`, `LocalGet`, and `LocalSet` nodes back to library instructions.
- `src/binary/encode.mbt:478-501`, `src/binary/encode.mbt:551-553`, and `src/binary/encode.mbt:2414-2435` expose the signed-LEB and opcode/payload encoding surfaces a faithful byte-profitability port should either reuse or mirror exactly.

## Durable conclusions

- The upstream `const-hoisting` contract remains a small function-local literal-size pass, not a generic constant propagation or CSE pass.
- A future Starshine port should likely be HOT-local because the required building blocks already exist around scalar constants, local builders, fresh local appends, and binary-size helpers.
- Starshine still has no owner file, tests, backlog slice, or active registry status for the transform itself.
- `v128.const` is still an upstream no-op boundary, and Starshine's current HOT scalar constant payload surface reinforces that a faithful first port should preserve the scalar-only contract instead of widening scope accidentally.

## Follow-up

- If implementation begins, add a dedicated `agent-todo.md` slice before coding.
- The first implementation tests should cover signed-LEB thresholds, float thresholds, float bit-identity buckets, deterministic prelude ordering, unsupported `v128`, and isolated `--pass const-hoisting` Binaryen parity.
