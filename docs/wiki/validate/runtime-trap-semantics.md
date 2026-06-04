---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-runtime-trap-current-refresh.md
  - ../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md
  - ../../../src/lib/types.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/ir/hot_flags.mbt
  - ../../../src/ir/effects.mbt
  - ../../../src/cmd/fuzz_harness.mbt
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/lib/effect-trap-scanner.ts
related:
  - ./stack-polymorphism-and-bottom.md
  - ./module-validation-phases.md
  - ../wast/control-flow-authoring.md
  - ../wast/static-assertion-harness.md
  - ../tooling/pass-fuzz-compare.md
  - ../tooling/fuzz-runner.md
  - ../tooling/o4z-debug-startup-trap.md
---

# Runtime Trap Semantics

## Overview

A WebAssembly **trap** is what happens when a valid module reaches a runtime failure condition. It is not the same thing as a validation error, a link error, or a WebAssembly exception value thrown by exception-handling instructions. This page owns the cross-cutting trap vocabulary for Starshine docs, pass signoff, runtime smoke tests, and debug-artifact investigations.

Use this page when a page or report says `RuntimeError: unreachable`, `assert_trap`, `traps-never-happen`, `mayTrap`, `equal trap`, `unreachable`, integer divide-by-zero, memory/table/GC bounds failure, null reference trap, or trap-preserving rewrite.

The current source refresh is [`../raw/wasm/2026-06-04-runtime-trap-current-refresh.md`](../raw/wasm/2026-06-04-runtime-trap-current-refresh.md). It rechecked current WebAssembly Core 3.0 execution/runtime/validation pages, the WebAssembly JavaScript API, MDN host-facing references, and Starshine's validator, HOT/effect, fuzz, and compare-pass code paths.

## Beginner Model

Think of a WebAssembly module in four separate phases:

| Phase | Example failure | What it means |
| --- | --- | --- |
| Decode/parse | malformed section length or opcode bytes | The bytes or text cannot be decoded into a module. |
| Validate | `i32.add` with no two `i32` operands in reachable code | The module shape is statically invalid and should not be instantiated. |
| Link/instantiate | missing host import, incompatible imported memory/table/global/tag | The module may be valid by itself, but cannot be connected to its host environment. |
| Execute | `unreachable`, out-of-bounds load, null `ref.as_non_null`, integer divide by zero | A valid and instantiated module started running and then trapped. |

`unreachable` is the simplest execution trap: if control reaches it, execution traps immediately. That runtime fact is separate from validation's stack-polymorphic rule for later unreachable code.

```wat
(module
  (func (export "boom")
    unreachable
    i32.add)) ;; validation can tolerate missing add operands after unreachable;
             ;; execution traps before i32.add is reached.
```

In a JavaScript host, a wasm trap is surfaced through `WebAssembly.RuntimeError`. A message like `RuntimeError: unreachable` is therefore a host-visible wrapper for a wasm trap, not by itself evidence of a Node-only bug.

## Trap Vocabulary For Starshine

| Term | Use it for | Do not confuse with |
| --- | --- | --- |
| **Trap** | Runtime failure from executing a wasm instruction or instantiation-time runtime condition. | Static validation rejection. |
| **`unreachable`** | A concrete instruction that always traps if executed and makes the following validation continuation unreachable. | A generic word for code the optimizer cannot reach. |
| **`WebAssembly.RuntimeError`** | JavaScript host error class for wasm traps. | Arbitrary JavaScript exceptions thrown by host glue. |
| **Exception / throw** | WebAssembly EH `throw`, `throw_ref`, `try_table`, and catch payload control. | Trap. A `throw_ref` on null can trap, but a non-null throw is exception control. |
| **`traps-never-happen`** | Optimization assumption/mode saying trap paths may be treated as impossible. | A validation guarantee or default Starshine semantics. |
| **`mayTrap` / `EFFECT_MASK_TRAP`** | Conservative IR/pass fact that moving or deleting an operation may change observable runtime failure. | Proof that the operation definitely traps. |

## Official Model Versus Starshine Model

| Surface | Official source model | Starshine/repo surface |
| --- | --- | --- |
| Runtime trap result | Core execution returns `trap` for runtime trap conditions; `unreachable` maps directly to trap. | `Instruction::Unreachable` / `Instruction::unreachable_()` in [`src/lib/types.mbt`](../../../src/lib/types.mbt); WAST control-flow docs route its validation behavior through [`stack-polymorphism-and-bottom.md`](stack-polymorphism-and-bottom.md). |
| Validation reachability | Validation can mark a control frame unreachable and synthesize bottom operands for later static checking. | `TcState.reachable`, `BotValType`, and `pop1(...)` in [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt); constant expressions add a stricter reachable-result check in [`validate_const_expr(...)`](../../../src/validate/validate.mbt). |
| JavaScript host surface | WebAssembly JavaScript APIs report traps through `WebAssembly.RuntimeError`; message text is host presentation. | Debug-artifact pages should cite this page before treating a `RuntimeError` string as a Starshine/Node-specific root cause. |
| Pass effect model | The spec defines observable traps; optimizers must preserve them unless they opt into a semantics-changing assumption. | `HOT_FLAG_MAY_TRAP` in [`src/ir/hot_flags.mbt`](../../../src/ir/hot_flags.mbt) and `EFFECT_MASK_TRAP` in [`src/ir/effects.mbt`](../../../src/ir/effects.mbt) keep trap-sensitive operations behind movement/deletion checks. |
| Runtime smoke comparison | Equal trap observation can be evidence for a tested call path, not whole-program proof. | [`src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt) classifies two `Trap(_)` results as `EqualTrap`; [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts) has a stricter string-detail equality for its Node export lane. |

## Common Trap Producers

These families are high-risk for pass and fixture work:

- `unreachable`: always traps if executed.
- Integer division/remainder: can trap on zero divisor and signed overflow cases.
- Non-saturating float-to-int truncations: can trap on NaN/out-of-range; saturating `trunc_sat` forms deliberately do not trap for those cases.
- Memory and table access: can trap on out-of-bounds addresses or invalid runtime element use even after static index validation succeeds.
- Bulk memory/table and GC array data/element operations: can trap on ranges, dropped segment state, or element/data bounds.
- Reference and GC operations: `ref.as_non_null`, casts, `i31.get*`, struct/array reads/writes, descriptor reads, and shared-GC atomics can trap on null, type, bounds, or synchronization-sensitive conditions.
- Calls: indirect/reference calls can trap on null/type/table failures; any call can also transfer to trap/throwing code in the callee.
- Exception-family edge case: `throw_ref` on a null exception reference traps, while a non-null `throw_ref` throws that exception through EH control.

Prefer the focused WAST and validator pages for each instruction family's stack and index rules; use this page only for the cross-cutting trap/effect vocabulary.

## Compare-Pass And Runtime Smoke Guidance

`bun fuzz compare-pass --runtime-execution node` adds optional runtime smoke evidence by instantiating Starshine and Binaryen outputs with deterministic basic import stubs and invoking a bounded set of same-named exports. That lane is intentionally narrow:

1. Equal returned values are useful evidence for the specific invoked exports and argument vector.
2. Equal traps are useful evidence that both versions failed under that invocation.
3. Equal traps are **not** sufficient to call a transform semantically safe if the programs could trap at different times, after different effects, or for different reasons.
4. A trap/value difference is a semantic mismatch unless the pass contract explicitly permits changing trap behavior under a named assumption such as `traps-never-happen`.
5. `inputEffectTrapFacts` from [`scripts/lib/effect-trap-scanner.ts`](../../../scripts/lib/effect-trap-scanner.ts) are triage metadata. They do not replace reduced replay or pass-specific semantic reasoning.

When reporting compare-pass results, combine runtime smoke with canonical normalized output comparison, validation, effect facts, reduced repros, and pass-specific source contracts. The focused workflow lives in [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md).

## Static WAST Harness Boundary

The official WAST script language includes runtime assertions such as `assert_return`, `assert_trap`, `assert_exception`, and `assert_exhaustion`. Starshine's current WAST spec harness is deliberately static: it parses those commands for script compatibility but skips them instead of instantiating modules and executing actions. Use [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md) for the exact static-harness pass/skip/fail policy.

Implication: a checked-in WAST `assert_trap` fixture is not runtime semantic evidence in Starshine's static harness today unless another runtime lane executes it.

## Rewrite And Debugging Checklist

When a pass, generator, or investigation touches trap-sensitive behavior:

1. **Separate validation from execution.** A valid module can still trap, and invalid code never reaches runtime.
2. **Name the trap producer.** Prefer "out-of-bounds load trap" or "null `ref.as_non_null` trap" over vague "runtime error" wording.
3. **Preserve trap order unless a contract says otherwise.** Moving a trapping load before a store/call can change visible behavior even if both modules eventually trap.
4. **Preserve operand evaluation.** Replacing a trapping operation with `unreachable` may be wrong if the original first evaluated effectful operands.
5. **Treat host messages as hints.** `RuntimeError: unreachable` is useful, but the root cause is the executed wasm instruction path.
6. **Be explicit about assumptions.** If `traps-never-happen` is enabled, say so in the page, command, or mismatch classification.
7. **Cross-link the owner page.** Memory, table, reference, GC, numeric, exception, and control-flow pages own their own detailed stack/index examples.

## Code And Doc Map

| Surface | Location | Why it matters |
| --- | --- | --- |
| Core `unreachable` instruction | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Defines the core instruction variant and constructor used by WAST lowering, generators, passes, and tests. |
| Stack-polymorphic validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`stack-polymorphism-and-bottom.md`](stack-polymorphism-and-bottom.md) | Explains why missing operands after unreachable can validate without implying runtime safety. |
| Constant-expression strictness | [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`constant-expressions.md`](constant-expressions.md) | Initializers/offsets must still produce a concrete reachable value in Starshine. |
| HOT/effect trap facts | [`src/ir/hot_flags.mbt`](../../../src/ir/hot_flags.mbt), [`src/ir/effects.mbt`](../../../src/ir/effects.mbt) | Passes use these conservative facts to avoid moving/deleting trap-sensitive operations unsafely. |
| Runtime comparison structs | [`src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt) | Records `Trap(...)`, `EqualTrap`, and trap/value mismatch classifications for command-level runtime matrices. |
| Compare-pass runtime lane | [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts), [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md) | Optional Node export invocation smoke lane and result persistence. |
| Effect/trap scanner | [`scripts/lib/effect-trap-scanner.ts`](../../../scripts/lib/effect-trap-scanner.ts) | Conservative input metadata for calls, mutations, exceptions, atomics, unreachable, and may-trap facts. |
| Debug-artifact trap example | [`../tooling/o4z-debug-startup-trap.md`](../tooling/o4z-debug-startup-trap.md) | Example of classifying `RuntimeError: unreachable` as a wasm trap symptom before assigning a Starshine owner. |

## Sources

- Current source refresh: [`../raw/wasm/2026-06-04-runtime-trap-current-refresh.md`](../raw/wasm/2026-06-04-runtime-trap-current-refresh.md)
- Earlier focused source note: [`../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md`](../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md)
- Official WebAssembly sources checked: <https://webassembly.github.io/spec/core/exec/runtime.html#syntax-trap>, <https://webassembly.github.io/spec/core/exec/instructions.html>, <https://webassembly.github.io/spec/core/valid/instructions.html>, <https://www.w3.org/TR/wasm-js-api-2/>
- Host-facing references checked: <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/JavaScript_interface/RuntimeError>, <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Control_flow/unreachable>
