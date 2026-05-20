---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-20
sources:
  - https://webassembly.github.io/spec/core/valid/instructions.html#valid-instr
  - https://webassembly.github.io/spec/core/exec/instructions.html#exec-instr
  - https://webassembly.github.io/spec/core/syntax/instructions.html#syntax-instr-control
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/validate/gen_valid.mbt
related:
  - ../../wast/exception-tag-authoring.md
  - ../../fuzzing/generator-coverage-ledger.md
  - ../../fuzzing/wast-arbitrary-parity-plan.md
---

# Exception `throw_ref` Nullability Refresh - 2026-05-20

This manifest refreshes the exception/tag guide after a wiki health pass found one stale wording path: the living WAST page described `throw_ref` as expecting Starshine's local non-null `exnref`, while the current Starshine validator and the official WebAssembly model accept a nullable exception reference operand and leave the null case to runtime trapping.

## Official WebAssembly sources checked

- WebAssembly 3.0 control-instruction syntax keeps `throw_ref`, `try_table`, `catch_ref`, and `catch_all_ref` in the exception-handling instruction family. URL: <https://webassembly.github.io/spec/core/syntax/instructions.html#syntax-instr-control>.
- WebAssembly 3.0 instruction validation types `throw_ref` with an `exnref` operand and stack-polymorphic continuation; the same validation page types `catch_ref` and `catch_all_ref` catch clauses with an exception-reference value added to the branch payload. URL: <https://webassembly.github.io/spec/core/valid/instructions.html#valid-instr>.
- WebAssembly 3.0 execution rules preserve a semantic split that validation cannot express alone: `throw_ref` observes/evaluates its reference operand, throws the referenced exception when non-null, and traps on a null exception reference. URL: <https://webassembly.github.io/spec/core/exec/instructions.html#exec-instr>.

## Starshine sources checked

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `ValType::ref_null_exn()` as nullable abstract `exn` and uses `RefType::new(false, HeapType::abs(AbsHeapType::exn()))` at catch-ref branch payload sites for the non-null captured exception object.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) typechecks `ThrowRef` by popping `ValType::ref_null_exn()` and marking the continuation unreachable. In the same file, `CatchRef` expects tag payload types plus non-null `(ref exn)`, while `CatchAllRef` expects just non-null `(ref exn)` at the target label.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) lowers modern `throw_ref` and the four `try_table` catch forms, with focused fixtures that inspect lowered `CatchRef` / `CatchAllRef` carriers and validate the exnref-flow examples.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) includes nullable `exnref` in the reference-type pool and uses exception-generation gates before emitting `throw_ref` / try-table matrix families.

## Durable conclusions

1. Use **nullable `exnref`** when documenting `throw_ref` validation. A non-null operand is valid by subtype matching, but it is not required by the instruction's validator-facing type.
2. Keep **non-null captured exnref** wording for `catch_ref` and `catch_all_ref` branch payloads. Starshine's typechecker constructs non-null `(ref exn)` for those label payloads, and that value can still match a label whose declared result is the broader nullable `exnref`.
3. Pass and fixture docs must preserve the runtime distinction: `throw_ref` on null traps, while `throw_ref` on a non-null exception reference throws that exception. Optimizations that move or remove `throw_ref`-adjacent code must preserve operand evaluation and null-trap/exception behavior, not merely validation reachability.
4. The 2026-05-19 WAST exception-source manifest remains useful for broad tag/try-table lowering. This refresh supersedes only the stale local wording that implied `throw_ref` demanded a local non-null `exnref` operand.
