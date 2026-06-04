# WebAssembly Runtime Trap Current Refresh

- Capture date: 2026-06-04
- Source family: WebAssembly Core 3.0 execution/runtime semantics plus WebAssembly JavaScript host-surface semantics, checked to turn the earlier `RuntimeError: unreachable` note into reusable wiki guidance.
- Supersedes/extends: [`2026-06-02-runtimeerror-unreachable-trap-sources.md`](2026-06-02-runtimeerror-unreachable-trap-sources.md) for general wiki routing. The older note remains useful provenance for the `o4z` startup investigation.

## Primary sources checked

- WebAssembly Core Specification, `Execution / Runtime Structure` — WebAssembly 3.0 (2026-06-03): <https://webassembly.github.io/spec/core/exec/runtime.html#syntax-trap>
- WebAssembly Core Specification, `Execution / Instructions` — WebAssembly 3.0 (2026-06-03): <https://webassembly.github.io/spec/core/exec/instructions.html>
- WebAssembly Core Specification, `Validation / Instructions` — WebAssembly 3.0 (2026-06-03): <https://webassembly.github.io/spec/core/valid/instructions.html>
- WebAssembly JavaScript Interface, W3C Working Draft: <https://www.w3.org/TR/wasm-js-api-2/>
- MDN, `WebAssembly.RuntimeError`: <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/JavaScript_interface/RuntimeError>
- MDN, `unreachable`: <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Control_flow/unreachable>

## Repository evidence checked

- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) — `Instruction::Unreachable` and `Instruction::unreachable_()` core representation.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) and [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt) — stack-polymorphic unreachable-code validation and constant-expression reachability rejection.
- [`../../../../src/ir/hot_flags.mbt`](../../../../src/ir/hot_flags.mbt) and [`../../../../src/ir/effects.mbt`](../../../../src/ir/effects.mbt) — conservative HOT/effect flagging for trap-sensitive operations.
- [`../../../../src/cmd/fuzz_harness.mbt`](../../../../src/cmd/fuzz_harness.mbt) and [`../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../scripts/lib/pass-fuzz-compare-task.ts) — runtime export-invocation comparison surfaces.
- [`../../../../scripts/lib/effect-trap-scanner.ts`](../../../../scripts/lib/effect-trap-scanner.ts) — optional compare-pass input fact scanner for calls, mutations, exceptions, atomics, unreachable, and may-trap facts.

## Durable takeaways

- A WebAssembly **trap** is a runtime result, distinct from validation failure, link failure, or a WebAssembly exception value thrown through exception-handling instructions.
- `unreachable` remains the simplest trap producer: current Core execution semantics maps it directly to `trap`.
- Validation reachability and runtime trapping must stay separate. Code after `unreachable` can be stack-polymorphic during validation, but executing `unreachable` still traps before later instructions run.
- In a JavaScript host, WebAssembly trap conditions surface as `WebAssembly.RuntimeError`-class failures. Exact message strings such as `unreachable` are presentation details and can differ by engine or trap producer.
- Equal trapping in a runtime comparison is useful smoke evidence, but it is not proof that two programs trap at the same instruction, after the same side effects, or for the same reason. Use it as supporting evidence beside canonical comparison, effect facts, reduced replays, and pass-specific semantics.
- Starshine docs should use **trap** for wasm runtime failure, **throw/exception** for WebAssembly EH control, **validation error** for static rejection, and **host exception** for JavaScript/Node errors outside wasm trap mapping.

## Open cautions

- Starshine does not have a general runtime executor in the static WAST harness; runtime-only WAST assertions such as `assert_trap` are currently parsed/skipped there.
- The compare-pass Node runtime lane invokes only a deterministic small export subset with basic import stubs. It can show equal results/equal traps for those exports, not whole-program equivalence.
- The effect/trap scanner is a conservative byte scan for triage and summary metadata, not a semantic proof engine.
