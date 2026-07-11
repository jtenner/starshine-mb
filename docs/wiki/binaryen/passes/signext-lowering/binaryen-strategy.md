---
kind: strategy
status: supported
last_reviewed: 2026-07-10
sources:
  - ../../../raw/binaryen/2026-07-10-signext-lowering-current-main-refresh.md
  - ../../../raw/binaryen/2026-05-06-signext-lowering-current-main-line-anchor-refresh.md
  - ../../../raw/research/0510-2026-05-06-signext-lowering-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-05-05-signext-lowering-current-main-recheck.md
  - ../../../raw/research/0466-2026-05-05-signext-lowering-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-signext-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0396-2026-04-26-signext-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-signext-lowering-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-25-signext-lowering-primary-sources.md
  - ../../../raw/research/0359-2026-04-25-signext-lowering-implementation-test-map.md
  - ../../../raw/research/0349-2026-04-25-signext-lowering-source-dossier.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy for `signext-lowering`

Binaryen implements `signext-lowering` as a small feature-lowering pass, not as a broad optimizer. The reviewed `version_129` implementation lives in `src/passes/SignExtLowering.cpp`; registration and factory plumbing live in `src/passes/pass.cpp` and `src/passes/passes.h`; the dedicated instruction-shape proof is `test/lit/passes/signext-lowering.wast`. The source history is retained in the older manifests, while the current contract—including the entry `hasSignExt()` gate—is in [`../../../raw/binaryen/2026-07-10-signext-lowering-current-main-refresh.md`](../../../raw/binaryen/2026-07-10-signext-lowering-current-main-refresh.md).

## Primary-source line map

| Source | Current main source | What it shows |
| --- | --- | --- |
| `src/passes/SignExtLowering.cpp` | [`main`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignExtLowering.cpp) | The `hasSignExt()` entry gate, function-parallel postwalk, five opcode cases, child reuse, root replacement, and `FeatureSet::SignExt` clearing. |
| `src/passes/pass.cpp` | [`main`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp) | Public `signext-lowering` registration and help text. |
| `test/lit/passes/signext-lowering.wast` | [`main`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signext-lowering.wast) | The enabled five-opcode output proof surface. |

## Execution shape

Binaryen's pass shape is:

- return without rewriting when `getModule()->features.hasSignExt()` is false;
- otherwise run a function-parallel postwalk over unary expressions;
- replace matching unary roots in place;
- disable the module's sign-extension feature flag after all functions are processed.

The pass only needs local expression context because each sign-extension opcode lowers independently. It does not need control-flow analysis, use-def analysis, local liveness, type graph state, or module reachability.

## Rewrite table

| Opcode | Shift count | Lowered expression |
| --- | ---: | --- |
| `i32.extend8_s x` | `24` | `i32.shr_s (i32.shl x 24) 24` |
| `i32.extend16_s x` | `16` | `i32.shr_s (i32.shl x 16) 16` |
| `i64.extend8_s x` | `56` | `i64.shr_s (i64.shl x 56) 56` |
| `i64.extend16_s x` | `48` | `i64.shr_s (i64.shl x 48) 48` |
| `i64.extend32_s x` | `32` | `i64.shr_s (i64.shl x 32) 32` |

The constant is `storage_width - source_width`. The arithmetic right shift is essential: it propagates the sign bit back down after the left shift moves that sign bit to the top of the storage lane.

## Why the child is safe

The original child expression is moved under the new `shl`; it is not cloned. Therefore a child with side effects, traps, or nondeterminism still executes once.

Example shape:

```wat
(i32.extend8_s
  (i32.load8_u (local.get $p)))
```

lowers to:

```wat
(i32.shr_s
  (i32.shl
    (i32.load8_u (local.get $p))
    (i32.const 24))
  (i32.const 24))
```

The load still happens once. The pass does not need an effect analysis because it does not reorder the child around another potentially effectful expression.

## Feature-state side effect

After rewriting expressions, Binaryen removes the sign-extension feature from the module feature set.

This matters because a pass that only replaces instructions but leaves target-feature metadata claiming sign-extension support has not matched Binaryen's full observable contract. In Binaryen the feature bit affects validation, printing, binary emission, and downstream target assumptions.

## Dedicated test proof

The dedicated lit file checks all five opcodes. Its expected output directly proves:

- every sign-extension opcode is gone from the checked function body;
- each replacement uses the correct shift count;
- i32 opcodes lower to i32 shifts and i64 opcodes lower to i64 shifts.

The owner source proves the `FeatureSet::SignExt` clearing side effect. This follow-up did not find a direct target-feature custom-section or printed feature-annotation assertion in the dedicated lit fixture, so cite the source for feature clearing and the lit file for instruction output shape.

The test is intentionally narrow. It does not cover:

- sign-extension redundancy elimination;
- sign-extension pattern recognition;
- load-sign selection;
- local or global propagation;
- code-size profitability.

Those belong to neighboring Binaryen passes such as `optimize-instructions` and `pick-load-signs`.

## Current-main freshness

The 2026-07-10 current-main refresh found the same five-opcode shift-pair and feature-disable strategy, and made the entry feature gate explicit: `SignExt` absent means no transform walk. This is source-level evidence, not a claim about generated binary bytes or a particular `target_features` custom-section layout.

## Non-goals

`signext-lowering` is not:

- a generic integer simplifier;
- a pass that lowers `i64.extend_i32_s`;
- a pass that picks signed loads;
- a pass that introduces sign-extension opcodes from shift pairs;
- a pass that reasons about whether a sign-extension is redundant.

Those distinctions are important for Starshine planning because the repository already has sign-extension-aware code in neighboring optimization passes, but none of that code is a feature-lowering pass today.
